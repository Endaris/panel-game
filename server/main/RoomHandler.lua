local class = require("common.lib.class")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local Room = require("server.Room")

---@class RoomHandler
---@field roomNumberIndex integer the next available room number
---@field rooms Room[] mapping of room number to room
---@field playerToRoom table<ServerPlayer, Room>
---@field spectatorToRoom table<ServerPlayer, Room>
local RoomHandler = class(
function(self)
  self.roomNumberIndex = 1
  self.rooms = {}
  self.playerToRoom = {}
  self.spectatorToRoom = {}
end)

---@param gameMode GameMode
---@param leaderboard Leaderboard?
---@param ... ServerPlayer
---@return Room room
function RoomHandler:createRoom(gameMode, leaderboard, ...)
  local players = {...}

  local newRoom = Room(self.roomNumberIndex, players, gameMode, leaderboard)
  self.roomNumberIndex = self.roomNumberIndex + 1
  self.rooms[newRoom.roomNumber] = newRoom
  for _, player in ipairs(players) do
    self.playerToRoom[player] = newRoom
  end

  return newRoom
end

---@param player ServerPlayer
---@param reason string? external reason for why the player is leaving the room; if none given it's assumed the player is leaving on their own volition
---@return boolean? # true if the message caused a change in the room setup, nil/false otherwise
function RoomHandler:handleLeaveRoom(player, reason)
  local room = self:getRoom(player)

  if room then
    if player.state == "spectating" then
      self.spectatorToRoom[player] = nil
      local removed = room:remove_spectator(player)
      return removed
    elseif (player.state == "playing" or player.state == "character select" or player.state == "paused") then
      self:closeRoom(room, reason)
      return true
    end
  end
end

---@param room Room
function RoomHandler:closeRoom(room, reason)
  for _, player in ipairs(room.players) do
    self.playerToRoom[player] = nil
    ---@diagnostic disable-next-line: invisible
    player.connection:enableNoDelay(false)
  end

  for _, player in ipairs(room.spectators) do
    self.spectatorToRoom[player] = nil
  end

  if self.rooms[room.roomNumber] then
    self.rooms[room.roomNumber] = nil
  end

  room:close(reason)
end

---@param player ServerPlayer
---@return Room? # the room the player is in
function RoomHandler:getRoom(player)
  if self.playerToRoom[player] then
    return self.playerToRoom[player]
  elseif self.spectatorToRoom[player] then
    return self.spectatorToRoom[player]
  end
end

---@param player ServerPlayer
---@param message { outcome: integer, [any]: any }
function RoomHandler:handleGameOverOutcome(player, message)
  local room = self.playerToRoom[player]
  if not room then
    return false
  else
    room:handleGameOverOutcome(message, player)
    return true
  end
end

function RoomHandler:handleTaunt(player, message)
  local room = self.playerToRoom[player]
  if not room then
    return false
  else
    room:handleTaunt(message, player)
    return true
  end
end

function RoomHandler:handleAbort(player, message)
  local room = self.playerToRoom[player]
  if not room then
    return false
  else
    return room:handleGameAbort(player)
  end
end

---@param player ServerPlayer
---@param message { paused: boolean }
---@return boolean success
function RoomHandler:handlePauseToggle(player, message)
  local room = self.rooms[message.roomNumber]
  if not room then
    return false
  else
    return room:togglePause(player, message.paused)
  end
end

---@param player ServerPlayer
---@param message table
---@return boolean # if the spectate request was fulfilled and lobby changed
function RoomHandler:handleSpectateRequest(player, message)
  local requestedRoom = self.rooms[message.spectate_request.roomNumber]

  if requestedRoom then
    local roomState = requestedRoom:state()
    if (roomState == "character select" or roomState == "playing" or roomState == "paused") then
      logger.debug("adding " .. player.name .. " to room nr " .. message.spectate_request.roomNumber)
      self.spectatorToRoom[player] = requestedRoom
      requestedRoom:add_spectator(player)
      return true
    else
      logger.warn("tried to join room in invalid state " .. roomState)
    end
  else
    -- TODO: tell the client the join request failed, couldn't find the room.
    logger.warn("couldn't find room")
  end
  return false
end

function RoomHandler:isRoomHandlerMessage(message)
  if message.taunt then
    return true
  elseif message.game_over then
    return true
  elseif message.matchAbort then
    return true
  elseif message.type == "pauseToggle" then
    return true
  elseif message.leave_room then
    return true
  elseif message.spectate_request then
    return true
  else
    return false
  end
end

---@param player ServerPlayer
---@param message table
---@return boolean? success
---@return boolean? lobbyChanged
function RoomHandler:handleRoomMessage(player, message)
  if message.leave_room then
    if (player.state == "playing" or player.state == "character select" or player.state == "paused" or player.state == "spectating") then
      local lobbyChanged = self:handleLeaveRoom(player, player.name .. " left")
      return true, lobbyChanged
    end
  elseif player.state == "playing" and message.taunt then
    return self:handleTaunt(player, message), false
  elseif player.state == "playing" and message.game_over then
    -- lobby changes for this one only if the game over report ends the game; but game end is already handled through the standard indirection
    local success = self:handleGameOverOutcome(player, message)
    return success, false
  elseif (player.state == "playing" or player.state == "paused") and message.matchAbort then
    local success = self:handleAbort(player, message)
    -- lobby changes for this one only if the abort ends the game; but game end is already handled through the standard indirection
    return success, false
  elseif (player.state == "playing" or player.state == "paused") and message.type == "pauseToggle" then
    local success = self:handlePauseToggle(player, message)
    -- handling successfully is equivalent to lobby changing in this case (room state change)
    return success, success
  elseif player.state == "lobby" and message.spectate_request then
    local lobbyChanged = self:handleSpectateRequest(player, message)
    -- handling successfully is equivalent to lobby changing in this case
    return lobbyChanged, lobbyChanged
  end
  return false
end

return RoomHandler