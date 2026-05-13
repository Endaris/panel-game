-- socket is bundled with love so the client requires love's socket
-- and the server requires the socket from common/lib
---@diagnostic disable-next-line: different-requires
local socket = require("common.lib.socket")
local logger = require("common.lib.logger")
local class = require("common.lib.class")
local ServerProtocol = require("common.network.ServerProtocol")
json = require("common.lib.dkjson")
require("common.lib.mathExtensions")
require("common.lib.util")
require("common.lib.timezones")
require("common.lib.csprng")
require("server.stridx")
require("server.server_globals")
local Connection = require("server.main.Connection")
local Leaderboard = require("server.Leaderboard")
local Playerbase = require("server.PlayerBase")
local Room = require("server.Room")
local ClientMessages = require("server.ClientMessages")
local utf8 = require("common.lib.utf8Additions")
local tableUtils = require("common.lib.tableUtils")
local Player = require("server.Player")
local util = require("common.lib.util")
local FileIO = require("server.FileIO")
local GameModes = require("common.data.GameModes")
local MainHandler = require("server.main.MainHandler")
local LoginHandler = require("server.main.LoginHandler")

local pairs = pairs
local ipairs = ipairs
local time = os.time

---@alias privateUserId string

-- Represents the full server object.
-- Currently we are transitioning variables into this, but to start we will use this to define API
---@class Server
---@field socket TcpSocket the master socket for accepting incoming client connections
---@field database ServerDB the database object
---@field connectionNumberIndex integer GLOBAL counter of the next available connection index
---@field roomNumberIndex integer the next available room number
---@field rooms Room[] mapping of room number to room
---@field proposals table<PublicPlayerID, table<PublicPlayerID, table<GameModeID, boolean>>> mapping of player name to a mapping of the players they have challenged for each game mode
---@field connections Connection[] mapping of connection number to connection
---@field nameToConnectionIndex table<string, integer> mapping of player names to their unique connectionNumberIndex
---@field socketToConnectionIndex table<TcpSocket, integer> mapping of sockets to their unique connectionNumberIndex
---@field connectionToPlayer table<Connection, ServerPlayer> Mapping of connections to the player they send for
---@field publicIdToPlayer table<PublicPlayerID, ServerPlayer> Mapping of publicId to the logged in ServerPlayer
---@field playerToRoom table<ServerPlayer, Room>
---@field spectatorToRoom table<ServerPlayer, Room>
---@field nameToPlayer table<string, ServerPlayer>
---@field lastProcessTime integer
---@field lastFlushTime integer timestamp for when logs were last flushed to file
---@field lobbyChanged boolean if new lobby data should be sent out on the next loop
---@field playerbase table
---@field leaderboard Leaderboard
---@field persistence Persistence
---@field _shuttingDown boolean
local Server = class(
---@param self Server
---@param databaseParam ServerDB
  function(self, databaseParam, persistence)
    self.connectionNumberIndex = 1
    self.roomNumberIndex = 1
    self.rooms = {}
    self.proposals = {}
    self.connections = {}
    self.nameToConnectionIndex = {}
    self.socketToConnectionIndex = {}
    self.connectionToPlayer = {}
    self.publicIdToPlayer = {}
    self.playerToRoom = {}
    self.spectatorToRoom = {}
    self.nameToPlayer = {}
    assert(databaseParam ~= nil)
    self.database = databaseParam
    self.persistence = persistence
    self.lastProcessTime = time()
    self.lastFlushTime = self.lastProcessTime
    self.lobbyChanged = false
    self._shuttingDown = false
    local loginHandler = LoginHandler(self.database, self.persistence, {self.leaderboard})
    self.mainHandler = MainHandler(self.database, self.persistence, loginHandler)

    FileIO.read_csprng_seed_file()
    initialize_mt_generator(csprng_seed)
    seed_from_mt(extract_mt())
    -- local server_start_time = os.time()
    -- print("current local time: "..server_start_time)
    -- print("current UTC time: "..to_UTC(server_start_time))
    -- local now = os.date("*t")
    -- local formatted_local_time = string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)
    -- print("formatted local time: "..formatted_local_time)
    -- now = os.date("*t",to_UTC(server_start_time))
    -- local formatted_UTC_time = string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)
    -- print("formatted UTC time: "..formatted_UTC_time)
    logger.debug("COMPRESS_REPLAYS_ENABLED: " .. (COMPRESS_REPLAYS_ENABLED and "true" or "false"))
    logger.debug("initialized!")
  end
)

function Server:start()
  logger.info("Starting up server with port: " .. (SERVER_PORT or 49569))
  local s = socket.bind("*", SERVER_PORT or 49569)
  if s then
    self.socket = s
  else
    error("Failed to create server socket. Check if there are any other instances blocking the port")
  end
  self.socket:settimeout(0)

  logger.debug(os.time())
end

function Server:stop()
  self._shuttingDown = true
  self.socket:close()
  self.socket = nil
end

---@param filePath string
---@param playerData table<privateUserId, string>?
function Server:initializePlayerData(filePath, playerData)
  if not self.playerbase then
    self.persistence.setPlayerIdsPath(filePath)
    if not playerData then
      playerData = self.persistence.getPlayerData()
    else
      -- do nothing, assume that's already parsed data
    end

    -- we don't want to design the API for persistence around the fact that we always need the entire playerData to write to disk
    -- so hand it a reference so the design can be more atomic
    self.persistence.setPlayerDataRef(playerData)

    self.playerbase = Playerbase(playerData, self.persistence)
    logger.debug("playerbase: " .. json.encode(self.playerbase.players))
  else
    logger.warn("Tried to load player data when the server already had player data loaded!\n" .. debug.traceback())
  end
end

---@param gameMode GameMode
---@param filePath string
---@param data table?
function Server:initializeLeaderboard(gameMode, filePath, data)
  if not self.leaderboard then
    self.persistence.setLeaderboardPath(filePath)
    self.leaderboard = Leaderboard(gameMode, self.persistence)
    if not data then
      data = self.persistence.getLeaderboardData()
    else
      -- do nothing, assume that's already parsed data
    end
    if data then
      self.leaderboard:importData(data)
    end

    logger.debug("leaderboard json:")
    logger.debug(json.encode(self.leaderboard.players))
    self.persistence.persistLeaderboard(self.leaderboard)
    logger.debug("leaderboard report: " .. json.encode(self.leaderboard:get_report(self)))
  else
    logger.warn("Tried to load leaderboard data when the server already had its leaderboard loaded!\n" .. debug.traceback())
  end
end

function Server:importDatabase()
  local usedNames = {}
  local cleanedPlayerData = {}
  for key, value in pairs(self.playerbase.players) do
    local name = value
    while usedNames[name] ~= nil do
      name = name .. math.random(1, 9999)
    end
    cleanedPlayerData[key] = value
    usedNames[name] = true
  end

  self.database:beginTransaction() -- this stops the database from attempting to commit every statement individually 
  logger.info("Importing leaderboard.csv to database")
  for k, v in pairs(cleanedPlayerData) do
    local rating = 0
    if self.leaderboard.players[k] then
      rating = self.leaderboard.players[k].rating
    end
    self.database:insertNewPlayer(k, v)
    self.database:insertPlayerELOChange(k, rating, 0)
  end

  local gameMatches = FileIO.readCsvFile("GameResults.csv")
  if gameMatches then -- only do it if there was a gameResults file to begin with
    logger.info("Importing GameResults.csv to database")
    for _, result in ipairs(gameMatches) do
      local parsedPlayer1ID = tostring(result[1])
      local parsedPlayer2ID = tostring(result[2])
      local parsedOutcome = tonumber(result[3])
      local parsedRanked = tonumber(result[4])
      if parsedPlayer1ID and parsedPlayer2ID and parsedOutcome and parsedRanked then
        local player1Won = parsedOutcome == 1
        local ranked = parsedRanked == 1
        local gameID = self.database:insertGame(ranked)
        assert(gameID)
        if player1Won then
          self.database:insertPlayerGameResult(parsedPlayer1ID, gameID, nil,  1)
          self.database:insertPlayerGameResult(parsedPlayer2ID, gameID, nil,  2)
        else
          self.database:insertPlayerGameResult(parsedPlayer2ID, gameID, nil,  1)
          self.database:insertPlayerGameResult(parsedPlayer1ID, gameID, nil,  2)
        end
      else
        logger.warn("Skipping malformed GameResults.csv row: " .. json.encode(result))
      end
    end
  end
  self.database:commitTransaction() -- bulk commit every statement from the start of beginTransaction
end

function Server:update()
  self.mainHandler:run()

  -- Only check once a second to avoid over checking
  -- (we are relying on time() returning a number rounded to the second)
  local currentTime = time()
  if currentTime ~= self.lastProcessTime then
    self:flushLogs(currentTime)
    self.lastProcessTime = currentTime
  end
end

-- Flush the log so we can see new info periodically. The default caches for huge amounts of time.
function Server:flushLogs(currentTime)
  if currentTime - self.lastFlushTime > 60 then
    pcall(
      function()
        io.stdout:flush()
      end
    )
    self.lastFlushTime = currentTime
  end
end

return Server
