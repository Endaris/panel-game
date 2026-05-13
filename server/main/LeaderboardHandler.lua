local class = require("common.lib.class")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")

local LeaderboardHandler = class(
function(self)
  self.leaderboards = {}
end)

---@param gameMode GameMode
function LeaderboardHandler:getLeaderboard(gameMode)
  for i, lb in ipairs(self.leaderboards) do
    if tableUtils.deep_content_equal(gameMode, lb.gameMode) then
      return lb
    end
  end
end


return LeaderboardHandler