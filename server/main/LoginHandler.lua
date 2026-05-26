local class = require("common.lib.class")
local logger = require("common.lib.logger")
local util = require("common.lib.util")
local utf8 = require("common.lib.utf8Additions")
local Player = require("server.Player")
local tableUtils = require("common.lib.tableUtils")

---@class LoginHandler
---@field persistence Persistence
---@field nameToConnectionIndex table<string, integer>?
local LoginHandler = class(
function(self, persistence)
  self.persistence = persistence
  self.playerbase = persistence.getPlayerBase()
end)

---@param ipAddress string
---@param userId privateUserId
---@return DB_Ban?
function LoginHandler:getOutstandingBan(ipAddress, userId)
  local bans = {}
  bans[#bans+1] = self.persistence.getBanByIP(ipAddress)
  bans[#bans+1] = self.persistence.getBanByID(userId)

  if #bans == 0 then
    return nil
  else
    table.sort(bans, function(a, b) return a.completionTime > b.completionTime end)
    return bans[1]
  end
end

---@param player ServerPlayer
---@param ipAddress string
---@param loginMessage ServerIncomingLoginMessage
---@return table message
function LoginHandler:login(player, ipAddress, loginMessage)
  local message = {}

  -- Name change is allowed because it was already checked above
  if self.playerbase.privateIdToName[player.userId] ~= player.name then
    local oldName = self.playerbase.privateIdToName[player.userId]
    self:changeUsername(player.userId, player.name)

    logger.warn(player.userId .. " changed name from '" .. oldName .. "' to '" .. player.name .. "'")

    message.name_changed = true
    message.old_name = oldName
    message.new_name = player.name
  end

  player.save_replays_publicly = loginMessage.save_replays_publicly

  player:updateSettings(loginMessage.playerSettings)
  -- This doesn't really make sense to log this way; hiding for inactivity from leaderboards should happen for lack of ranked activity
  -- Just logging in and leaving without playing a (ranked) game shouldn't be enough
  --for i, leaderboard in ipairs(self.leaderboards) do
  --  leaderboard:update_timestamp(player.userId)
  --end
  self.persistence.persistIpIdPair(player.publicPlayerID, ipAddress)

  local serverNotices = self.persistence.getUnseenMessagesForPublicId(player.publicPlayerID)
  if tableUtils.length(serverNotices) > 0 then
    local noticeString = ""
    for messageID, serverNotice in pairs(serverNotices) do
      noticeString = noticeString .. serverNotice .. "\n\n"
      self.persistence.markMessageAsSeen(messageID)
    end
    message.server_notice = noticeString
  end

  return message
end

---@return boolean loginApproved if the player can log in
---@return string denyReason why the player cannot log in, nil if login was approved
function LoginHandler:canLogin(userID, name, IP_logging_in, engineVersion)
  local denyReason = nil
  if engineVersion ~= ENGINE_VERSION and not ANY_ENGINE_VERSION_ENABLED then
    denyReason = "Please update your game, server expects engine version: " .. ENGINE_VERSION
  elseif not name or name == "" then
    denyReason = "Name cannot be blank"
  elseif string.lower(name) == "anonymous" then
    denyReason = 'Username cannot be "anonymous"'
  elseif name:lower():match("d+e+f+a+u+l+t+n+a+m+e?") then
    denyReason = 'Username cannot be "defaultname" or a variation of it'
  elseif name:find("[^_%w]") then
    denyReason = "Usernames are limited to alphanumeric and underscores"
  elseif utf8.len(name) > NAME_LENGTH_LIMIT then
    denyReason = "The name length limit is " .. NAME_LENGTH_LIMIT .. " characters"
  elseif not userID then
    denyReason = "Client did not send a user ID in the login request"
  elseif userID == "need a new user id" then
    if self.playerbase:nameTaken("", name) then
      denyReason = "That player name is already taken"
      logger.warn("Login failure: Player tried to create a new user with an already taken name: " .. name)
    end
  elseif not self.playerbase.privateIdToName[userID] then
    denyReason = "The user ID provided was not found on this server"
    local playerBan = self.persistence.persistNewIpBan(IP_logging_in, denyReason, os.time() + 60)
    logger.warn("Login failure: " .. name .. " specified an invalid user ID")
  elseif self.playerbase.privateIdToName[userID] ~= name and self.playerbase:nameTaken(userID, name) then
    denyReason = "That player name is already taken"
    logger.warn("Login failure: Player (" .. userID .. ") tried to use already taken name: " .. name)
  elseif self.nameToConnectionIndex[name] then
    denyReason = "Cannot login with the same name twice"
  end

  if denyReason then
    return false, denyReason
  else
    return true, ""
  end
end

---@param name string
---@return privateUserId?
function LoginHandler:createNewUser(name)
  local user_id = nil
  while not user_id or self.playerbase.privateIdToName[user_id] do
    user_id = self:generateNewUserId()
  end
  if self.playerbase:addPlayer(user_id, name) then
    return user_id
  end
end

---@return privateUserId new_user_id
function LoginHandler:generateNewUserId()
  local new_user_id = cs_random()
  local result = tostring(new_user_id)
  assert(result)
  return result
end

function LoginHandler:changeUsername(privateUserID, username)
  self.playerbase:updatePlayer(privateUserID, username)
end

function LoginHandler:setNameToConnectionReference(nameToConnectionIndex)
  self.nameToConnectionIndex = nameToConnectionIndex
end

return LoginHandler