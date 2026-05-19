local class = require("common.lib.class")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local Leaderboard = require("server.ranking.Leaderboard")
local GameModes = require("common.data.GameModes")
local FileIO = require("server.FileIO")

---@class LeaderboardHandler
---@operator call(Persistence): LeaderboardHandler
---@field leaderboards table<GameModeID, Leaderboard>
---@field persistence Persistence
---@field playerbase Playerbase
local LeaderboardHandler = class(
function(self, persistence, playerbase)
  self.leaderboards = {}
  self.persistence = persistence
  self.playerbase = playerbase
end)

---@param gameModeId GameModeID
---@return Leaderboard?
function LeaderboardHandler:getLeaderboard(gameModeId)
  return self.leaderboards[gameModeId]
end

---@param gameModeId GameModeID
---@param persistenceMode PersistenceMode
---@param filePath string?
---@return Leaderboard? leaderboard
function LeaderboardHandler:initializeLeaderboard(gameModeId, persistenceMode, filePath)
  if not self.leaderboards[gameModeId] then
    local gameMode = GameModes.getPreset(gameModeId)
    local leaderboard = Leaderboard(gameMode, self.persistence, persistenceMode, filePath)
    
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

  for userId, leaderboardPlayer in pairs(leaderboard.players) do
    -- only include in the report players who are still listed in the playerbase
    if self.playerbase.privateIdToName[userId] then
      if leaderboardPlayer.placement_done and leaderboardPlayer.rating then
        report[#report+1] = {
          user_name = self.playerbase.privateIdToName[userId],
          rating = leaderboardPlayer.rating,
          publicId = self.playerbase.privateIdToPublicId[userId],
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

---@return table[] # the leaderboard with full information for saving internally
---@return table[] # the leaderboard with a reduced data set for saving in a publicly accessible location
function LeaderboardHandler:toSheetData(leaderboard)
  local leaderboardTable = {}
  local publicLeaderboardTable = {}
  leaderboardTable[#leaderboardTable + 1] = {"user_id", "user_name", "rating", "placement_done", "placement_rating", "ranked_games_played", "ranked_games_won","last_login_time", "public_id"}
  publicLeaderboardTable[#publicLeaderboardTable + 1] = {"user_name", "rating", "ranked_games_played", "public_id"} --excluding ranked_games_won for now because it doesn't track properly, and user_id because they are secret.
  for user_id, v in pairs(leaderboard.players) do
    leaderboardTable[#leaderboardTable + 1] = {user_id, self.playerbase.privateIdToName[user_id], v.rating, tostring(v.placement_done or ""), v.placement_rating, v.ranked_games_played, v.ranked_games_won, v.last_login_time, v.publicId or self.playerbase.privateIdToPublicId[user_id]}
    publicLeaderboardTable[#publicLeaderboardTable + 1] = {self.playerbase.privateIdToName[user_id], v.rating, v.ranked_games_played, v.publicId or self.playerbase.privateIdToPublicId[user_id]}
  end

  return leaderboardTable, publicLeaderboardTable
end

---@param leaderboard Leaderboard
function LeaderboardHandler:persistLeaderboard(leaderboard)
  local leaderboardTable, publicLeaderboardTable = self:toSheetData(leaderboard)
  if leaderboard.mode == self.persistence.modes.FILE then
    FileIO.writeAsCSV(FileIO.combinePath(".", leaderboard.filePath), leaderboardTable)

  elseif leaderboard.mode == self.persistence.modes.DATABASE then
    -- TODO: DB persistence for leaderboards
  end

  -- always write the public one to file for accessibility
  FileIO.writePublicLeaderboardFile(leaderboard.filePath, publicLeaderboardTable)
end


return LeaderboardHandler