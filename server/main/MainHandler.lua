local socket = require("common.lib.socket")
local logger = require("common.lib.logger")
local class = require("common.lib.class")
local ServerProtocol = require("common.network.ServerProtocol")
local Connection = require("server.main.Connection")
local Player = require("server.Player")
local tableUtils = require("common.lib.tableUtils")
local GameModes = require("common.data.GameModes")
local Proposals = require("server.main.Proposals")
local ClientMessages = require("server.ClientMessages")
local utf8 = require("common.lib.utf8Additions")
local FileIO = require("server.FileIO")
local RoomHandler = require("server.main.RoomHandler")
local util = require("common.lib.util")
local LeaderboardHandler = require("server.main.LeaderboardHandler")
local Persistence = require("server.Persistence")
local LoginHandler = require("server.main.LoginHandler")

local pairs = pairs
local ipairs = ipairs

---Handles the general server functionality around accepting and managing connections, messages, rooms and games
---@class Server.MainHandler
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
---@field lobbyChanged boolean if new lobby data should be sent out on the next loop
---@field roomHandler RoomHandler
---@field loginHandler LoginHandler
local MainHandler = class(
---@param self MainHandler
function(self)
  ---@class MainHandler
  self = self
  self.connectionNumberIndex = 1
  self.roomNumberIndex = 1
  self.rooms = {}
  self.proposals = Proposals()
  self.connections = {}
  self.nameToConnectionIndex = {}
  self.socketToConnectionIndex = {}
  self.connectionToPlayer = {}
  self.publicIdToPlayer = {}
  self.playerToRoom = {}
  self.spectatorToRoom = {}
  self.nameToPlayer = {}
  self.lobbyChanged = false
  self.roomHandler = RoomHandler()
  self.loginHandler = LoginHandler(Persistence)
  self.loginHandler:setNameToConnectionReference(self.nameToConnectionIndex)
  self.leaderboardHandler = LeaderboardHandler()
end)

function MainHandler:start()
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

function MainHandler:run()
  self:acceptNewConnections()

  self:updateConnections()
  self:processMessages()

  if self.lobbyChanged then
    self:broadcastLobby()
    self.lobbyChanged = false
  end
end

function MainHandler:acceptNewConnections()
  local newConnectionSocket = self.socket:accept()
  if newConnectionSocket then
    newConnectionSocket:settimeout(0)
    logger.debug("Accepted connection " .. self.connectionNumberIndex)
    local connection = Connection(newConnectionSocket, self.connectionNumberIndex)
    self.socketToConnectionIndex[newConnectionSocket] = self.connectionNumberIndex
    self:addConnection(connection)
  end
end

function MainHandler:addConnection(connection)
  self.connections[self.connectionNumberIndex] = connection
  self.connectionNumberIndex = self.connectionNumberIndex + 1
end

-- Process any data on all active connections
function MainHandler:updateConnections()
  -- Make a list of all the sockets to listen to
  local socketsToRead = {self.socket}
  -- Make a list of all the sockets we want to send messages to
  -- the server socket cannot "send" in the traditional sense, only accept incoming connections (which is in the read domain) so it is not added here
  local socketsToSend = {}
  for _, v in pairs(self.connections) do
    if v.outgoingMessageQueue:len() > 0 then
      -- socket.select(_, socketsToSend) only checks if at least one socket in the table is generally ready to send even if there is no data to be sent
      -- predictably that is immediately true for most client sockets most of the time
      -- so only check for sockets we actually have something to send for because sockets ready for sending will make the select return instantly
      --  causing us to loop very busily even though there is possibly nothing to do
      socketsToSend[#socketsToSend+1] = v.socket
    end
    -- whereas for read, we can check for all of them because they will only make select return if there is actually something to read
    socketsToRead[#socketsToRead + 1] = v.socket
  end

  -- Wait for up to 1 second to see if there is any socket to read / write on
  -- the waiting time is only until at least one socket has data to read or a socket we want to send data on is ready so it's not actually stalling unless there is no data anyway
  socketsToRead, socketsToSend = socket.select(socketsToRead, socketsToSend, 1)

  for _, connection in pairs(self.connections) do
    local canRead = not not socketsToRead[connection.socket]
    local canSend = not not socketsToSend[connection.socket]
    local success = connection:update(self.lastProcessTime, canRead, canSend)
    if not success then
      local player = self.connectionToPlayer[connection]
      local reason = "disconnect"
      if player then
        reason = player.name .. "'s connection failed"
      end
      self:closeConnection(connection, reason)
    end
  end
end

---@param connection Connection
---@param reason string? why the player is getting disconnected
function MainHandler:closeConnection(connection, reason)
  local player = self.connectionToPlayer[connection]
  logger.info("Closing connection " .. connection.index .. " to " .. (player and player.name or "noname"))

  self.socketToConnectionIndex[connection.socket] = nil
  self.connections[connection.index] = nil
  self.connectionToPlayer[connection] = nil
  connection.loggedIn = false
  connection:close()
  if player then
    self.proposals:clearPlayer(player)
    self.roomHandler:handleLeaveRoom(player, reason)
    self.publicIdToPlayer[player.publicPlayerID] = nil
    self.nameToPlayer[player.name] = nil
    self.nameToConnectionIndex[player.name] = nil
    self:setLobbyChanged()
  end
end

local function error_printer(msg, layer)
	logger.error((debug.traceback("Error: " .. tostring(msg), 1+(layer or 1)):gsub("\n[^\n]+$", "")))
end

local function handleError(msg)
  msg = tostring(msg)

	error_printer(msg, 2)

  local trace = debug.traceback()
  ---@type any
  local sanitizedMsgTable = {}
	for char in msg:gmatch(utf8.charpattern) do
		table.insert(sanitizedMsgTable, char)
	end
	local sanitizedmsg = table.concat(sanitizedMsgTable)

	local err = {}

	table.insert(err, "Error\n")
	table.insert(err, sanitizedmsg)

	if #sanitizedmsg ~= #msg then
		table.insert(err, "Invalid UTF-8 string in error message.")
	end

	table.insert(err, "\n")

	for l in trace:gmatch("(.-)\n") do
		if not l:match("boot.lua") then
			l = l:gsub("stack traceback:", "Traceback\n")
			table.insert(err, l)
		end
	end

	local p = table.concat(err, "\n")

	p = p:gsub("\t", "")
	p = p:gsub("%[string \"(.-)\"%]", "%1")

  logger.error(p)
end

function MainHandler:processMessages()
  for index, connection in pairs(self.connections) do
    if connection.incomingInputQueue.last ~= -1 then
      local q = connection.incomingInputQueue
      local player = self.connectionToPlayer[connection]
      if player then
        local room = self.playerToRoom[player]
        if room then
          for i = q.first, q.last do
            self.playerToRoom[player]:broadcastInput(q[i], player)
          end
        end
      end
      q:shallowClear()
    end

    if connection.incomingMessageQueue.last ~= -1 then
      local q = connection.incomingMessageQueue
      local player = self.connectionToPlayer[connection]
      for i = q.first, q.last do
        local status, continue = xpcall(function() return self:processMessage(q[i], connection) end, handleError)
        if status then
          if not continue then
            break
          end
        else
          if player then
            logger.error("Incoming message from " .. (player.name or connection.index) .. " in state " .. (player.state or "unknown") .. " caused an error." .. "\nJ-Message:\n" .. q[i])
            if self.playerToRoom[player] then
              logger.error("Room state during error:\n" .. self.playerToRoom[player]:toString())
            end
          else
            logger.error("Incoming message from " .. connection.index .. " caused an error." .. "\nJ-Message:\n" .. q[i])
          end
        end
      end
      q:clear()
    end
  end
end

---@param connection Connection
---@return boolean? # if messages from this connection should continue to get processed
function MainHandler:processMessage(message, connection)
  message = json.decode(message)
  message = ClientMessages.sanitizeMessage(message)

  if message.unknown then
    self:closeConnection(connection, "Client deviated from Network Protocol")
    return false
  elseif message.error_report then -- Error report is checked for first so that a full login is not required
    self:handleErrorReport(message.error_report)
    -- After sending the error report, the client will throw the error, so end the connection.
    local player = self.connectionToPlayer[connection]
    if player then
      self:closeConnection(connection, player.name .. " crashed")
    else
      self:closeConnection(connection, "player only connected to send crash report")
    end
    return false
  elseif not connection.loggedIn then
    if message.login_request then
      local IP_logging_in, port = connection.socket:getpeername()
      if self:handleLogin(connection, message.user_id, message.name, IP_logging_in, port, message.engine_version, message) then
        return true
      else
        return false
      end
    else
      self:closeConnection(connection, "login while logged in")
      return false
    end
  else
    local player = self.connectionToPlayer[connection]
    if message.logout then
      self:closeConnection(connection, player.name .. " logged out")
      return false
    elseif player.state == "lobby" and message.challengeUpdate then
      local receiver = self.publicIdToPlayer[message.challengeUpdate.receiverId]
      if message.challengeUpdate.senderId == player.publicPlayerID and receiver then
        self:processChallengeUpdate(player, receiver, message.challengeUpdate.gameModeId, message.challengeUpdate.challengeActive)
        return true
      end
    elseif message.leaderboard_request then
      connection:sendJson(ServerProtocol.sendLeaderboard(self.leaderboardHandler:getLeaderboardReport(GameModes.IDs.TWO_PLAYER_VS)))
      return true
    elseif player.state == "lobby" and message.roomRequest then
      self:createRoom(message.gameMode, player)
      return true
    elseif message.playerSettings then
      -- Note this also starts the game if everything is ready from both player's character select settings
      player:updateSettings(message.playerSettings)
      return true
    elseif self.roomHandler:isRoomHandlerMessage(message) then
      local success, lobbyChanged = self.roomHandler:handleRoomMessage(player, message)
      if lobbyChanged then
        self:setLobbyChanged()
      end
      return success
    end
  end
  return false
end

function MainHandler:handleErrorReport(errorReport)
  logger.warn("Received an error report.")
  if not FileIO.write_error_report(errorReport) then
    logger.error("The error report was either too large or had an I/O failure when attempting to write the file.")
  end
end

---@param connection Connection
---@param userId privateUserId?
---@param name string
---@param ipAddress string
---@param port integer
---@param engineVersion string
---@param loginMessage ServerIncomingLoginMessage
function MainHandler:handleLogin(connection, userId, name, ipAddress, port, engineVersion, loginMessage)
  logger.debug("New login attempt:  " .. ipAddress .. ":" .. port)

  local playerBan = self.loginHandler:getOutstandingBan(ipAddress, userId)
  if playerBan then
    local secondsRemaining = (playerBan.completionTime - os.time())

    banDuration = "Ban Remaining: " .. util.toDayHourMinuteSecondString(secondsRemaining)

    Persistence.markBanAsSeen(playerBan.banID)
    logger.warn("Login denied because of ban: " .. playerBan.reason)
    connection:sendJson(ServerProtocol.denyLogin(playerBan.reason, banDuration))
  else
    local loginApproved, denyReason = self.loginHandler:canLogin(userId, name, ipAddress, engineVersion)

    if not loginApproved then
      connection:sendJson(ServerProtocol.denyLogin(denyReason))
      return false, denyReason
    else
      if userId == "need a new user id" then
        userId = self.loginHandler:createNewUser(name)
        if not userId then
          connection:sendJson(ServerProtocol.denyLogin("Failed to create new user, please try again"))
          return
        else
          logger.info("New user: " .. userId .. " " .. name .. " was created")
        end
      end

      ---@cast userId -nil
      local player = Player(userId, connection, name, self.playerbase.privateIdToPublicId[userId])
      local message = self.loginHandler:login(player, ipAddress, loginMessage)

      self.nameToConnectionIndex[name] = connection.index
      self.connectionToPlayer[connection] = player
      self.publicIdToPlayer[player.publicPlayerID] = player
      self.nameToPlayer[name] = player
      player:setState("lobby")
      self:setLobbyChanged()
      connection:sendJson(ServerProtocol.approveLogin(player.publicPlayerID, message.server_notice, message.new_user_id, message.new_name, message.old_name))

      logger.warn(connection.index .. " Login from " .. name .. " with ip: " .. ipAddress .. " publicPlayerID: " .. player.publicPlayerID)
    end
  end
end

---@param sender ServerPlayer
---@param receiver ServerPlayer
---@param gameModeId GameModeID
---@param challengeActive boolean
function MainHandler:processChallengeUpdate(sender, receiver, gameModeId, challengeActive)
  if sender and sender.state == "lobby" and receiver and receiver.state == "lobby" then
    logger.debug(string.format("%s challenges %s to a game of %s", sender.name, receiver.name, gameModeId))
    self.proposals:updateChallenge(sender, receiver, gameModeId, challengeActive)
    if self.proposals:isRoomNeeded(sender, receiver, gameModeId) then
      local room = self:createRoom(gameModeId, sender, receiver)
      for i, player in ipairs(room.players) do
        self.proposals:clearPlayer(player)
      end
      self:setLobbyChanged()
    else
      receiver:sendJson(ServerProtocol.sendChallengeUpdate(sender, receiver, gameModeId, challengeActive))
    end
  else
    -- this message won't be handled because one of the parties is no longer in lobby
    -- related things would be handled in the state change / logout
  end
end

---@param gameModeId GameModeID
---@param ... ServerPlayer
function MainHandler:createRoom(gameModeId, ...)
  local gameMode = GameModes.getPreset(gameModeId)
  local leaderboard = self.leaderboardHandler:getLeaderboard(gameModeId)
  local newRoom = self.roomHandler:createRoom(gameMode, leaderboard, ...)

  for _, player in ipairs(newRoom.players) do
    self.proposals:clearPlayer(player)
    if #newRoom.players > 1 then
      -- no delay is enabled only to reduce the chances of hitting rollback and rollback only exists in multiplayer
      ---@diagnostic disable-next-line: invisible
      player.connection:enableNoDelay(true)
    end
  end

  newRoom:connectSignal("matchStart", self, self.setLobbyChanged)
  newRoom:connectSignal("matchEnd", self, self.processGameEnd)
  newRoom:connectSignal("pauseToggled", self, self.setLobbyChanged)

  self:setLobbyChanged()
end

---@param game ServerGame
function MainHandler:processGameEnd(game)
  logger.debug("Processing game end")
  self:setLobbyChanged()

  -- this is a sufficient criteria only by incidence as it remains the only 2 player online game mode so far
  -- there needs to be a better mechanism to validate whether a game should be persisted / persisted for a leaderboard
  -- as the current persistGame somewhat assumes both (explicit player number and that the game was played to determine a winner/placement)
  if game and game.complete and game.replay.metadata.gameModeName == "VS" then
    Persistence.persistGame(game)
  end
end

function MainHandler:setLobbyChanged()
  self.lobbyChanged = true
end

function MainHandler:broadcastLobby()
  local lobbyStateV2 = self:getLobbyStateV2()
  local messageV2 = ServerProtocol.lobbyStateV2(lobbyStateV2.players, lobbyStateV2.rooms)
  for _, connection in pairs(self.connections) do
    local player = self.connectionToPlayer[connection]
    if player and player.state == "lobby" then
      connection:sendJson(messageV2)
    end
  end
end

---@alias LobbyPlayerV2 { publicId: PublicPlayerID, name: string, state: string, ratings: table<GameModeID, number?>, roomNumber: roomNumber? }
---@alias LobbyRoomV2 { roomNumber: roomNumber, state: string, gameModeId: GameModeID, players: PublicPlayerID[], spectators: PublicPlayerID[], wins: integer[], gameStartTime: integer? }
---@alias LobbyStateV2 { players: table<PublicPlayerID, LobbyPlayerV2>, rooms: table<roomNumber, LobbyRoomV2> }

---@return LobbyStateV2
function MainHandler:getLobbyStateV2()
  local players = {}
  local rooms = {}

  for publicId, player in pairs(self.publicIdToPlayer) do
    players[publicId] = {
      publicId = publicId,
      name = player.name,
      state = player.state,
      ratings = { },
    }

    if self.leaderboard and self.leaderboard.players[player.userId] and self.leaderboard.players[player.userId].placement_done then
      players[publicId].ratings.TWO_PLAYER_VS = math.round(self.leaderboard.players[player.userId].rating)
    end
  end

  for _, room in pairs(self.rooms) do
    local lobbyRoom = {
      roomNumber = room.roomNumber,
      state = room:state(),
      gameModeId = GameModes.nameToGameModeId[room.gameMode.name],
      players = {},
      spectators = {},
      wins = {},
    }

    if room.game then
      lobbyRoom.gameStartTime = os.date("*t", to_UTC(room.game.creationTime))
    end

    for i, player in ipairs(room.players) do
      players[player.publicPlayerID].roomNumber = room.roomNumber
      lobbyRoom.players[i] = player.publicPlayerID
      lobbyRoom.wins[i] = room.win_counts[i]
    end

    for i, spectator in ipairs(room.spectators) do
      players[spectator.publicPlayerID].roomNumber = room.roomNumber
      lobbyRoom.spectators[i] = spectator.publicPlayerID
    end

    rooms[lobbyRoom.roomNumber] = lobbyRoom
  end

  return { players = players, rooms = rooms }
end

return MainHandler