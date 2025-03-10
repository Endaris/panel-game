-- provide an abstraction layer to convert messages as defined in common/network/ClientProtocol
-- into the format used by the server's internals
-- so that changes in the ClientProtocol only affect this abstraction layer and not server code
-- and changes in server code likewise only affect this abstraction layer instead of the ClientProtocol
local logger = require("common.lib.logger")
local LevelData = require("common.data.LevelData")

local ClientMessages = {}

-- central sanitization function that picks a sanitization function based on the presence of key fields
function ClientMessages.sanitizeMessage(clientMessage)
  if clientMessage.login_request then
    return ClientMessages.sanitizeLoginRequest(clientMessage)
  elseif clientMessage.game_request then
    return ClientMessages.sanitizeGameRequest(clientMessage)
  elseif clientMessage.menu_state then
    return ClientMessages.sanitizeMenuState(clientMessage.menu_state)
  elseif clientMessage.spectate_request then
    return ClientMessages.sanitizeSpectateRequest(clientMessage)
  elseif clientMessage.leaderboard_request then
    return ClientMessages.sanitizeLeaderboardRequest(clientMessage)
  elseif clientMessage.leave_room then
    return ClientMessages.sanitizeLeaveRoom(clientMessage)
  elseif clientMessage.taunt then
    return ClientMessages.sanitizeTaunt(clientMessage)
  elseif clientMessage.game_over then
    return ClientMessages.sanitizeGameResult(clientMessage)
  elseif clientMessage.logout then
    return clientMessage
  elseif clientMessage.type and clientMessage.type == "roomRequest" then
    return ClientMessages.sanitizeRoomRequest(clientMessage)
  elseif clientMessage.type and clientMessage.type == "matchAbort" then
    return ClientMessages.sanitizeMatchAbort(clientMessage)
  elseif clientMessage.error_report then
    return clientMessage
  else
    local errorMsg = "Received an unexpected message"
    local messageJson = json.encode(clientMessage)
    if messageJson and type(messageJson) == "string" and messageJson:len() > 10000 then
      errorMsg = errorMsg .. " with " .. messageJson:len() .. " characters"
    else
      errorMsg = errorMsg .. ":\n  " .. tostring(messageJson)
    end
    logger.error(errorMsg)
    return { unknown = true}
  end
end

---@class ServerIncomingPlayerSettings
---@field cursor string?
---@field stage string?
---@field stage_is_random string?
---@field ready boolean?
---@field character string?
---@field character_is_random string?
---@field panels_dir string?
---@field level integer?
---@field ranked boolean?
---@field inputMethod InputMethod?
---@field wants_ready boolean?
---@field loaded boolean?
---@field publicId integer?
---@field levelData LevelData?
---@field wants_ranked_match boolean?

---@return {playerSettings: ServerIncomingPlayerSettings}
function ClientMessages.sanitizeMenuState(playerSettings)
  local sanitized = {}

  sanitized.character = playerSettings.character
  sanitized.character_is_random = playerSettings.character_is_random
  sanitized.cursor = playerSettings.cursor -- nil when from login
  sanitized.inputMethod = (playerSettings.inputMethod or "controller") --one day we will require message to include input method, but it is not this day.
  sanitized.level = playerSettings.level
  sanitized.panels_dir = playerSettings.panels_dir
  sanitized.ready = playerSettings.ready -- nil when from login
  sanitized.stage = playerSettings.stage
  sanitized.stage_is_random = playerSettings.stage_is_random
  sanitized.wants_ranked_match = playerSettings.ranked
  sanitized.loaded = playerSettings.loaded
  sanitized.wants_ready = playerSettings.wants_ready
  if playerSettings.levelData and LevelData.validate(playerSettings.levelData) then
    sanitized.levelData = playerSettings.levelData
    setmetatable(sanitized.levelData, LevelData)
  end

  return {playerSettings = sanitized}
end

---@class ServerIncomingLoginMessage
---@field playerSettings ServerIncomingPlayerSettings
---@field login_request boolean
---@field user_id privateUserId
---@field engine_version string
---@field name string
---@field save_replays_publicly ("not at all" | "anonymously" | "with my name")

---@return ServerIncomingLoginMessage
function ClientMessages.sanitizeLoginRequest(loginRequest)
  ---@type ServerIncomingLoginMessage
  local sanitized = ClientMessages.sanitizeMenuState(loginRequest)
  sanitized.login_request = true
  sanitized.user_id = loginRequest.user_id
  sanitized.engine_version = loginRequest.engine_version
  sanitized.name = loginRequest.name
  sanitized.save_replays_publicly = loginRequest.save_replays_publicly

  return sanitized
end

function ClientMessages.sanitizeGameRequest(gameRequest)
  local sanitized =
  {
    game_request =
    {
      sender = gameRequest.game_request.sender,
      receiver = gameRequest.game_request.receiver,
    }
  }

  return sanitized
end

function ClientMessages.sanitizeSpectateRequest(spectateRequest)
  local sanitized =
  {
    spectate_request =
    {
      sender = spectateRequest.spectate_request.sender,
      roomNumber = spectateRequest.spectate_request.roomNumber,
    }
  }

  return sanitized
end

function ClientMessages.sanitizeLeaderboardRequest(leaderboardRequest)
  local sanitized =
  {
    leaderboard_request = leaderboardRequest.leaderboard_request
  }

  return sanitized
end

function ClientMessages.sanitizeLeaveRoom(leaveRoom)
  local sanitized =
  {
    leave_room = leaveRoom.leave_room
  }

  return sanitized
end

function ClientMessages.sanitizeGameResult(gameResult)
  local sanitized =
  {
    game_over = gameResult.game_over,
    outcome = gameResult.outcome
  }

  return sanitized
end

function ClientMessages.sanitizeTaunt(taunt)
  local sanitized =
  {
    taunt = taunt.taunt,
    type = taunt.type,
    index = taunt.index
  }

  return sanitized
end

function ClientMessages.sanitizeRoomRequest(roomRequest)
  local sanitized =
  {
    roomRequest = true,
    gameMode = roomRequest.content.gameMode
  }

  return sanitized
end

function ClientMessages.sanitizeMatchAbort(matchAbort)
  local sanitized =
  {
    matchAbort = true
  }

  return sanitized
end

return ClientMessages