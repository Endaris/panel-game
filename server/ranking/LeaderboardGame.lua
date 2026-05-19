local class = require("common.lib.class")

---@class LeaderboardGame
---@field players LeaderboardPlayer[]
---@field winnerId PublicPlayerID
---@field winnerIndex integer
local LeaderboardGame = class(
---@param self LeaderboardGame
---@param leaderboard Leaderboard
---@param game ServerGame
function(self, leaderboard, game)
  self.players = {}
  for i, player in ipairs(game.players) do
    self.players[i] = leaderboard.players[player.userId]
  end
  self.winnerId = game.winnerId
  self.winnerIndex = game.winnerIndex
end)



return LeaderboardGame