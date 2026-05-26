local PlayerBase = require("server.PlayerBase")

---@diagnostic disable: missing-fields, duplicate-set-field, inject-field

---@type Persistence
local MockPersistence = {}
local testData

-- this should be a reference to the same player data the Playerbase holds onto
local PlayerData
local playerBase

---@param data table<privateUserId, string>
---@return Server.Playerbase
function MockPersistence.injectPlayerData(data)
  MockPersistence.clearData()
  playerBase = PlayerBase.initialize(data, MockPersistence)
  return playerBase
end

function MockPersistence.getPlayerBase()
  if not playerBase then
    error("Tried to fetch cached playerbase before it was initialized")
  end
  return playerBase
end

function MockPersistence.clearData()
  playerBase = nil
end

---@param game ServerGame
function MockPersistence.persistGame(game)
end

function MockPersistence.getLeaderboardData()
end

---@param userId privateUserId
---@param placementData table
function MockPersistence.persistPlacementGames(userId, placementData)
end

---@param userId privateUserId
function MockPersistence.persistPlacementFinalization(userId)
end

---@param userId privateUserId
function MockPersistence.getPlacementData(userId)
  return {}
end

function MockPersistence.persistPlayerData()
end

function MockPersistence.persistNewPlayer(userId, name)
  return true
end

function MockPersistence.persistPlayerNameChange(userId, name)
  return true
end

---@param privateUserId privateUserId
---@return DB_Player?
function MockPersistence.getPlayerInfo(privateUserId)
  if testData and testData[tonumber(privateUserId)] then
    --publicPlayerID: integer, privatePlayerID: integer, username: string, lastLoginTime: integer
    return {publicPlayerID = testData[tonumber(privateUserId)].publicPlayerID, privatePlayerID = privateUserId, username = testData[tonumber(privateUserId)].name, lastLoginTime = 0}
  end
end

function MockPersistence.persistNewIpBan(ip, reason, completionTime)
end

-- set this in case it's important to have pre-existing players for a test with cohesive ids that can be verified against
-- otherwise every new player will be considered "new" on login for the test and may have a new id assigned
function MockPersistence.setTestData(playerData)
  testData = playerData
end

return MockPersistence