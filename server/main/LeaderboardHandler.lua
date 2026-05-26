local class = require("common.lib.class")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local Leaderboard = require("server.ranking.Leaderboard")
local GameModes = require("common.data.GameModes")
local Persistence = require("server.Persistence")

---@class LeaderboardHandler
---@operator call(Server.Playerbase): LeaderboardHandler
---@field leaderboards table<GameModeID, Server.Leaderboard>
---@field playerbase Server.Playerbase
local LeaderboardHandler = class(
function(self)
  self.leaderboards = {}
end)

---@param gameModeId GameModeID
---@return Server.Leaderboard?
function LeaderboardHandler:getLeaderboard(gameModeId)
  return self.leaderboards[gameModeId]
end

---@param gameModeId GameModeID
---@param persistenceMode PersistenceMode
---@param filePath string?
---@return Server.Leaderboard? leaderboard
function LeaderboardHandler:initializeLeaderboard(gameModeId, persistenceMode, filePath)
  if not self.leaderboards[gameModeId] then
    local gameMode = GameModes.getPreset(gameModeId)
    local leaderboard = Leaderboard(gameMode, persistenceMode, filePath)
    
    leaderboard:connectSignal("leaderboardChanged", self, self.persistLeaderboard)

    self:persistLeaderboard(leaderboard)
    logger.debug("leaderboard report: " .. json.encode(self:getLeaderboardReport(gameModeId)))

    return leaderboard
  else
    logger.warn("Tried to load leaderboard data for mode " .. gameModeId .. " when the server already had its leaderboard loaded!\n" .. debug.traceback())
  end
end

---@param a { rating: number }
---@param b { rating: number }
local function sortByRating(a, b)
  return a.rating > b.rating
end

--returns the leaderboard as an array sorted from highest rating to lowest
---@param gameModeId GameModeID
---@return { user_name: string, rating: number, publicId: PublicPlayerID}[]?
function LeaderboardHandler:getLeaderboardReport(gameModeId)
  local report = {}
  
  local leaderboard = self.leaderboards[gameModeId]

  if not leaderboard then
    return
  end

  local playerbase = Persistence.getPlayerBase()

  for userId, leaderboardPlayer in pairs(leaderboard.players) do
    -- only include in the report players who are still listed in the playerbase
    if playerbase.privateIdToName[userId] then
      if leaderboardPlayer.placement_done and leaderboardPlayer.rating then
        report[#report+1] = {
          user_name = playerbase.privateIdToName[userId],
          rating = leaderboardPlayer.rating,
          publicId = playerbase.privateIdToPublicId[userId],
        }
      end
    end
  end

  table.sort(report, sortByRating)

  for _, entry in ipairs(report) do
    entry.rating = math.round(entry.rating)
  end

  return report
end

---@param leaderboard Server.Leaderboard
function LeaderboardHandler:persistLeaderboard(leaderboard)
  Persistence.persistLeaderboard(leaderboard)
end


return LeaderboardHandler