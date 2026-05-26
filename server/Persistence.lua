local PADatabase = require("server.PADatabase")
local FileIO = require("server.FileIO")
local logger = require("common.lib.logger")
local PlayerBase = require("server.PlayerBase")

---@class Persistence
local Persistence = {}

---@enum PersistenceMode
Persistence.modes = { FILE = "FILE", DATABASE = "DATABASE" }

local playerIdsToNamesPath
local playerBase

---@param mode PersistenceMode
---@param dbPath string
---@param filePath string?
function Persistence.initialize(mode, dbPath, filePath)
  if PADatabase.db or playerBase then
    error("Persistence is already initialized")
  end

  PADatabase:initialize(dbPath)

  if mode == Persistence.modes.FILE then
    if not filePath then
      error("Did not supply file path for persistence mode FILE")
    else
      Persistence.initializePlayerbaseFromFile(filePath)
      local isPlayerTableEmpty = PADatabase:getPlayerRecordCount() == 0
      if isPlayerTableEmpty then
        Persistence.importPlayerbaseToDatabase()
      end
    end
  elseif mode == Persistence.modes.DATABASE then
    Persistence.initializePlayerbaseFromDatabase()
  else
    error("Invalid persistence mode " .. tostring(mode))
  end
end

---@param path string
function Persistence.initializePlayerbaseFromFile(path)
  if playerBase then
    error("Playerbase is already initialized")
  end

  if not playerIdsToNamesPath then
    playerIdsToNamesPath = path
  elseif path == playerIdsToNamesPath then
    -- not really supposed to happen but we can ignore this just fine
  else    
    error("Cannot change the path for the player id file after start up")
  end

  local data
  if FileIO.fileExists(playerIdsToNamesPath) then
    data = FileIO.readJson(playerIdsToNamesPath)
    if not data then
      error("Failed to read player data from " .. path)
    end
  else
    data = {}
  end
  ---@cast data table<privateUserId, string>

  playerBase = PlayerBase.initialize(data, Persistence)
end

function Persistence.importPlayerbaseToDatabase()
  local usedNames = {}
  local cleanedPlayerData = {}
  for key, value in pairs(playerBase.privateIdToName) do
    local name = value
    while usedNames[name] ~= nil do
      name = name .. math.random(1, 9999)
    end
    cleanedPlayerData[key] = value
    usedNames[name] = true
  end

  PADatabase:beginTransaction() -- this stops the database from attempting to commit every statement individually 
  logger.info("Importing leaderboard.csv to database")
  for k, v in pairs(cleanedPlayerData) do
    -- local rating = 0
    -- if self.leaderboard.players[k] then
    --   rating = self.leaderboard.players[k].rating
    -- end
    PADatabase:insertNewPlayer(k, v)
    -- self.database:insertPlayerELOChange(k, rating, 0)
  end

  -- local gameMatches = FileIO.readCsvFile("GameResults.csv")
  -- if gameMatches then -- only do it if there was a gameResults file to begin with
  --   logger.info("Importing GameResults.csv to database")
  --   for _, result in ipairs(gameMatches) do
  --     local parsedPlayer1ID = tostring(result[1])
  --     local parsedPlayer2ID = tostring(result[2])
  --     local parsedOutcome = tonumber(result[3])
  --     local parsedRanked = tonumber(result[4])
  --     if parsedPlayer1ID and parsedPlayer2ID and parsedOutcome and parsedRanked then
  --       local player1Won = parsedOutcome == 1
  --       local ranked = parsedRanked == 1
  --       local gameID = self.database:insertGame(ranked)
  --       assert(gameID)
  --       if player1Won then
  --         self.database:insertPlayerGameResult(parsedPlayer1ID, gameID, nil,  1)
  --         self.database:insertPlayerGameResult(parsedPlayer2ID, gameID, nil,  2)
  --       else
  --         self.database:insertPlayerGameResult(parsedPlayer2ID, gameID, nil,  1)
  --         self.database:insertPlayerGameResult(parsedPlayer1ID, gameID, nil,  2)
  --       end
  --     else
  --       logger.warn("Skipping malformed GameResults.csv row: " .. json.encode(result))
  --     end
  --   end
  -- end
  PADatabase:commitTransaction() -- bulk commit every statement from the start of beginTransaction
end

function Persistence.initializePlayerbaseFromDatabase()
  if playerBase then
    error("Playerbase is already initialized")
  end

  local dbPlayers = PADatabase:getPlayerData()
  if not dbPlayers then
    error("Failed to fetch player data from database")
  else
    playerBase = PlayerBase.initializeFromDbData(dbPlayers, Persistence)
  end
end

---@return Server.Playerbase playerbase
function Persistence.getPlayerBase()
  if not playerBase then
    error("Tried to fetch playerbase before it was initialized")
  end
  return playerBase
end

---@return ServerDB
function Persistence.getDatabase()
  if not PADatabase.db then
    error("Tried to fetch DB before it was initialized")
  end
  return PADatabase
end

---@param game ServerGame
function Persistence.persistGame(game)
  local gameID = PADatabase:insertGame(game.ranked)
  if not gameID then
    logger.error("Failed to persist game to database.")
  else
    game:setId(gameID)
  end

  local resultValue = 0.5
  for i, player in ipairs(game.players) do
    local level = not player:usesModifiedLevelData() and player.level or nil
    if game.id then
      PADatabase:insertPlayerGameResult(player.userId, game.id, level, game:getPlacement(player))
    end
    if player.publicPlayerID == game.winnerId then
      if i == 1 then
        resultValue = 1
      elseif i == 2 then
        resultValue = 0
      end
    end
  end

  local rankedValue = game.ranked and 1 or 0
  FileIO.logGameResult(game.players[1].userId, game.players[2].userId, resultValue, rankedValue)

  FileIO.saveReplay(game)
end

---@param leaderboard Server.Leaderboard
function Persistence.getLeaderboardData(leaderboard)
  if leaderboard.persistenceMode == Persistence.modes.FILE then
    -- TODO: annotate return type so the DB version can match it?
    return FileIO.readCsvFile(leaderboard.filePath)
  elseif leaderboard.persistence == Persistence.modes.DATABASE then
    -- TODO: create leaderboard table(s) in DB and read from it
  end
end

---@param leaderboard Server.Leaderboard
---@param userId privateUserId
---@param placementData table
function Persistence.persistPlacementGames(leaderboard, userId, placementData)
  FileIO.write_user_placement_match_file(userId, placementData)
end

---@param leaderboard Server.Leaderboard
---@param userId privateUserId
function Persistence.persistPlacementFinalization(leaderboard, userId)
  FileIO.move_user_placement_file_to_complete(userId)
end

---@param leaderboard Server.Leaderboard
---@param userId privateUserId
function Persistence.getPlacementData(leaderboard, userId)
  local read_success, matches = FileIO.read_user_placement_match_file(userId)
  if read_success then
    logger.debug("loaded placement matches from file")
    if matches then
      return matches
    else
      return {}
    end
  else
    return {}
  end
end

function Persistence.persistPlayerData()
  if not playerBase then
    error("Need to initialize PlayerData before it can be persisted")
  end
  FileIO.writeAsJson(playerBase.privateIdToName, playerIdsToNamesPath)
end

---@param userId privateUserId
---@param name string
---@return boolean
function Persistence.persistNewPlayer(userId, name)
  Persistence.persistPlayerData()
  return PADatabase:insertNewPlayer(userId, name)
end

---@param userId privateUserId
---@param name string
function Persistence.persistPlayerNameChange(userId, name)
  PADatabase:updatePlayerUsername(userId, name)
  Persistence.persistPlayerData()
end

---@param privateUserId privateUserId
function Persistence.getPlayerInfo(privateUserId)
  return PADatabase:getPlayerFromPrivateID(privateUserId)
end

---@param leaderboard Server.Leaderboard
function Persistence.persistLeaderboard(leaderboard)
  local leaderboardTable, publicLeaderboardTable = leaderboard:toSheetData()
  if leaderboard.persistenceMode == Persistence.modes.FILE then
    FileIO.writeAsCSV(FileIO.combinePath(".", leaderboard.filePath), leaderboardTable)
  elseif leaderboard.persistenceMode == Persistence.modes.DATABASE then
    -- TODO: DB persistence for leaderboards
  end

  -- always write the public one to file for accessibility
  FileIO.writePublicLeaderboardFile(leaderboard.filePath, publicLeaderboardTable)
end

---@param ip string
---@param reason string
---@param completionTime integer
---@return DB_Ban?
function Persistence.persistNewIpBan(ip, reason, completionTime)
  return PADatabase:insertBan(ip, reason, completionTime)
end

---@param publicId PublicPlayerID
---@param ipAddress string
function Persistence.persistIpIdPair(publicId, ipAddress)
  PADatabase:insertIPID(ipAddress, publicId)
end

---@param publicId PublicPlayerID
---@return table<integer, string>
function Persistence.getUnseenMessagesForPublicId(publicId)
  return PADatabase:getPlayerMessages(publicId)
end

---@param messageId integer
function Persistence.markMessageAsSeen(messageId)
  PADatabase:playerMessageSeen(messageId)
end

---@param banId integer
function Persistence.markBanAsSeen(banId)
  PADatabase:playerBanSeen(banId)
end

-- Checks if a logging in player is banned based off their IP.
---@param ip string
---@return DB_Ban?
function Persistence.getBanByIP(ip)
  return PADatabase:getBanByIP(ip)
end

---@param userId privateUserId
---@return DB_Ban?
function Persistence.getBanByID(userId)
  local publicId = playerBase.privateIdToPublicId[userId]

  if publicId then
    return PADatabase:getBanByPublicID(publicId)
  end
end

return Persistence