local class = require("common.lib.class")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local Persistence

-- Represents all player accounts on the server.
---@class Server.Playerbase
---@field privateIdToName table<privateUserId, string>
---@field publicIdToPrivateId privateUserId[]
---@field privateIdToPublicId table<privateUserId, integer>
local Playerbase = {}

function Playerbase.initialize(playerData, persistence)
  if Persistence then
    error("Playerbase can only be initialized once")
  end

  Persistence = persistence
  Playerbase.privateIdToName = playerData or {}
  Playerbase.publicIdToPrivateId = {}
  Playerbase.privateIdToPublicId = {}

  for privateId, _ in pairs(Playerbase.privateIdToName) do
    local playerInfo = Persistence.getPlayerInfo(privateId)
    if playerInfo then
      Playerbase.publicIdToPrivateId[playerInfo.publicPlayerID] = privateId
      Playerbase.privateIdToPublicId[privateId] = playerInfo.publicPlayerID
    else
      Playerbase.publicIdToPrivateId[#Playerbase.publicIdToPrivateId+1] = privateId
      Playerbase.privateIdToPublicId[privateId] = #Playerbase.publicIdToPrivateId
    end
  end

  logger.info(tableUtils.length(Playerbase.privateIdToName) .. " players loaded")

  return Playerbase
end

---@param dbPlayers DB_Player[]
---@param persistence Persistence
function Playerbase.initializeFromDbData(dbPlayers, persistence)
  if Persistence then
    error("Playerbase can only be initialized once")
  end

  Persistence = persistence
  Playerbase.privateIdToName = {}
  Playerbase.publicIdToPrivateId = {}
  Playerbase.privateIdToPublicId = {}

  for i, player in ipairs(dbPlayers) do
    local privateId = tostring(player.privatePlayerID)
    Playerbase.publicIdToPrivateId[player.publicPlayerID] = privateId
    Playerbase.privateIdToPublicId[privateId] = player.publicPlayerID
    Playerbase.privateIdToName[privateId] = player.name
  end

  logger.info(tableUtils.length(Playerbase.privateIdToName) .. " players loaded")

  return Playerbase
end

---@param userID privateUserId
---@param playerName string
---@return boolean success
function Playerbase:addPlayer(userID, playerName)
  self.privateIdToName[userID] = playerName
  if Persistence.persistNewPlayer(userID, playerName) then
    local playerInfo = Persistence.getPlayerInfo(userID)
    if playerInfo then
      self.publicIdToPrivateId[playerInfo.publicPlayerID] = userID
      self.privateIdToPublicId[userID] = playerInfo.publicPlayerID
    else
      self.publicIdToPrivateId[#self.publicIdToPrivateId+1] = userID
      self.privateIdToPublicId[userID] = #self.publicIdToPrivateId
    end
    return true
  else
    return false
  end
end

---@param userId privateUserId
---@param playerName string
function Playerbase:updatePlayer(userId, playerName)
  self.privateIdToName[userId] = playerName
  Persistence.persistPlayerNameChange(userId, playerName)
end

-- returns true if the name is taken by a different user already
---@param userID privateUserId
---@param playerName string
---@return boolean
function Playerbase:nameTaken(userID, playerName)

  for key, value in pairs(self.privateIdToName) do
    if value:lower() == playerName:lower() then
      if key ~= userID then
        return true
      end
    end
  end

  return false
end

return Playerbase