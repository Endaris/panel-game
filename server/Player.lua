--local logger = require("common.lib.logger")
local database = require("server.PADatabase")
local class = require("common.lib.class")
local ServerProtocol = require("common.network.ServerProtocol")
local LevelPresets = require("common.data.LevelPresets")
local Signal = require("common.lib.signal")
local logger = require("common.lib.logger")

---@class ServerPlayer : Signal
---@field package connection Connection
---@field userId privateUserId
---@field publicPlayerID integer
---@field character string id of the specific character that was picked
---@field character_is_random string? id of the character (bundle) that was selected; will match character if not a bundle
---@field stage string id of the specific stage that was picked
---@field stage_is_random string? id of the stage (bundle) that was selected; will match stage if not a bundle
---@field panels_dir string id of the specific panel set that was selected
---@field wants_ranked_match boolean
---@field inputMethod ("controller" | "touch")
---@field level integer display property for the level
---@field levelData LevelData
---@field wantsReady boolean
---@field loaded boolean
---@field ready boolean
---@field cursor string?
---@field save_replays_publicly ("not at all" | "anonymously" | "with my name")
---@field name string
---@field player_number integer?
---@field opponent ServerPlayer to be removed
---@overload fun(privatePlayerID: privateUserId): ServerPlayer
local Player = class(
---@param self ServerPlayer
---@param privatePlayerID privateUserId
---@param connection Connection
function(self, privatePlayerID, connection)
  self.userId = privatePlayerID
  self.connection = connection

  assert(database ~= nil)
  local playerData = database:getPlayerFromPrivateID(privatePlayerID)
  if playerData then
    self.publicPlayerID = playerData.publicPlayerID
  end

  -- Player Settings
  self.character = nil
  self.character_is_random = nil
  self.cursor = nil
  self.inputMethod = "controller"
  self.level = nil
  self.panels_dir = nil
  self.wantsReady = nil
  self.loaded = nil
  self.ready = nil
  self.stage = nil
  self.stage_is_random = nil
  self.wants_ranked_match = false
  self.levelData = nil

  Signal.turnIntoEmitter(self)
  self:createSignal("settingsUpdated")
end)

function Player:getSettings()
  return ServerProtocol.toSettings(
    self.ready,
    self.level,
    self.inputMethod,
    self.stage,
    self.stage_is_random,
    self.character,
    self.character_is_random,
    self.panels_dir,
    self.wants_ranked_match,
    self.wantsReady,
    self.loaded,
    self.publicPlayerID,
    self.levelData or LevelPresets.getModern(self.level)
  )
end

function Player:updateSettings(settings)
  if settings.character ~= nil then
    self.character = settings.character
  end

  if settings.character_is_random ~= nil then
    self.character_is_random = settings.character_is_random
  end
  -- self.cursor = playerSettings.cursor -- nil when from login
  if settings.inputMethod ~= nil then
    self.inputMethod = (settings.inputMethod or "controller")
  end

  if settings.level ~= nil then
    self.level = settings.level
  end

  if settings.panels_dir ~= nil then
    self.panels_dir = settings.panels_dir
  end

  if settings.ready ~= nil then
    self.ready = settings.ready -- nil when from login
  end

  if settings.stage ~= nil then
    self.stage = settings.stage
  end

  if settings.stage_is_random ~= nil then
    self.stage_is_random = settings.stage_is_random
  end

  if settings.wants_ranked_match ~= nil then
    self.wants_ranked_match = settings.wants_ranked_match
  end

  if settings.wants_ready ~= nil then
    self.wantsReady = settings.wants_ready
  end

  if settings.loaded ~= nil then
    self.loaded = settings.loaded
  end

  if settings.levelData ~= nil then
    self.levelData = settings.levelData
  end

  self:emitSignal("settingsUpdated", self)
end

---@param room Room?
function Player:setRoom(room)
  if not room then
    if self.room then
      logger.info("Clearing room " .. self.room.roomNumber .. " for connection " .. self.connection.index)
      -- if there is no socket the room got closed because the player hard DCd so shouldn't update state in that case
      if self.connection.socket then
        self.opponent = nil
        self.state = "lobby"
        self.player_number = nil
        self:sendJson(ServerProtocol.leaveRoom())
      end
    end
  else
    if self.room then
      logger.info("Switching connection " .. self.connection.index .. " from room " .. self.room.roomNumber .. " to room " .. room.roomNumber)
    else
      logger.info("Setting room to " .. room.roomNumber .. " for connection " .. self.connection.index)
    end
  end

  self.room = room
end

function Player:sendJson(message)
  self.connection:sendJson(message)
end

function Player:send(message)
  self.connection:send(message)
end

---@return boolean
function Player:isReady()
  return self.wantsReady and self.loaded and self.ready
end

function Player:setup_game()
  if self.state ~= "spectating" then
    self.state = "playing"
  end
end

function Player:getDumbSettings(rating, playerNumber)
  return ServerProtocol.toDumbSettings(
    self.character,
    self.level,
    self.panels_dir,
    playerNumber or self.player_number,
    self.inputMethod,
    rating,
    self.publicPlayerID,
    self.levelData
  )
end

---@return boolean
function Player:usesModifiedLevelData()
  return not deep_content_equal(self.levelData, LevelPresets.getModern(self.level))
end

return Player
