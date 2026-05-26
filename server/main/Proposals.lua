local class = require("common.lib.class")

---@class Server.Proposals
---@field proposals table<PublicPlayerID, table<PublicPlayerID, table<GameModeID, boolean>>> mapping of player name to a mapping of the players they have challenged for each game mode
local Proposals = class(
function(self)
  self.proposals = {}
end)

---@param player ServerPlayer
function Proposals:clearPlayer(player)
  -- blanket reset for the player
  self.proposals[player.publicPlayerID] = {}
  -- reset all challenges to the player
  for _, challenges in pairs(self.proposals) do
    if challenges[player.publicPlayerID] then
      challenges[player.publicPlayerID] = nil
    end
  end
end 

---@param sender ServerPlayer
---@param receiver ServerPlayer
---@param gameModeId GameModeID
---@param challengeActive boolean
function Proposals:updateChallenge(sender, receiver, gameModeId, challengeActive)
  local senderChallenges = self.proposals[sender.publicPlayerID] or {}
  senderChallenges[receiver.publicPlayerID] = senderChallenges[receiver.publicPlayerID] or {}
  senderChallenges[receiver.publicPlayerID][gameModeId] = challengeActive
  
  self.proposals[sender.publicPlayerID] = senderChallenges
end

---@param sender ServerPlayer
---@param receiver ServerPlayer
---@param gameModeId GameModeID
function Proposals:isRoomNeeded(sender, receiver, gameModeId)
  local senderChallenges = self.proposals[sender.publicPlayerID]
  local receiverChallenges = self.proposals[receiver.publicPlayerID]
  if senderChallenges == nil or receiverChallenges == nil then
    return false
  end

  if senderChallenges[receiver.publicPlayerID] == nil or receiverChallenges[sender.publicPlayerID] == nil then
    return false
  end

  if senderChallenges[receiver.publicPlayerID][gameModeId] == true and receiverChallenges[sender.publicPlayerID][gameModeId] == true then
    return true
  else
    return false
  end
end

return Proposals