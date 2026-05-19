local class = require("common.lib.class")
local logger = require("common.lib.logger")
local GameModes = require("common.data.GameModes")
local ELO = require("server.ranking.ELO")
local LeaderboardGame = require("server.ranking.LeaderboardGame")
local signal = require("common.lib.signal")

local leagues = {
            {league="Newcomer",     min_rating = -1000},
            {league="Copper",       min_rating = 1},
            {league="Bronze",       min_rating = 1125},
            {league="Silver",       min_rating = 1275},
            {league="Gold",         min_rating = 1425},
            {league="Platinum",     min_rating = 1575},
            {league="Diamond",      min_rating = 1725},
            {league="Master",       min_rating = 1875},
            {league="Grandmaster",  min_rating = 2025}
          }

logger.debug("Leagues")
for k, v in ipairs(leagues) do
  logger.debug(v.league .. ":  " .. v.min_rating)
end

---@class LeaderboardPlayer
---@field publicId PublicPlayerID?
---@field user_name string?
---@field rating number
---@field placement_done boolean?
---@field placement_rating number?
---@field ranked_games_played integer?
---@field ranked_games_won integer?
---@field last_login_time integer?

-- Object that represents players rankings and placement matches, along with login times
---@class Leaderboard : Signal
---@field filePath string doubles as the filename without extension
---@field players table<string, LeaderboardPlayer>
---@field loadedPlacementMatches {incomplete: table, complete: table}
---@field playersPerGame integer
---@field gameMode GameMode the game mode this leaderboard is for; currently unused
---@field persistence Persistence a collection of persistence methods; referenced directly on the leaderboard so they can be replaced for testing
---@field persistenceMode PersistenceMode
---@overload fun(gameMode: GameMode, persistence: Persistence, mode: PersistenceMode, filePath: string?): Leaderboard
local Leaderboard = class(
---@param self Leaderboard
---@param gameMode GameMode
---@param persistence Persistence
---@param persistenceMode PersistenceMode
---@param filePath string?
function(self, gameMode, persistence, persistenceMode, filePath)
  self.gameMode = gameMode
  self.persistence = persistence
  self.persistenceMode = persistenceMode
  if self.persistenceMode == persistence.modes.FILE then
    assert(filePath, "need to provide a file path when running a leaderboard in file mode")
    self.filePath = filePath
  end

  self.players = {}
  self.loadedPlacementMatches = {
    incomplete = {},
    complete = {}
  }
  self.playersPerGame = 2

  local data = self.persistence.getLeaderboardData(self)
  if data then
    self:importData(data)
  end

  logger.debug("leaderboard for " .. gameMode.id .. ":")
  logger.debug(json.encode(self.leaderboard.players))

  signal.turnIntoEmitter(self)
  self:createSignal("leaderboardChanged")
end
)

---@param data {[1]: privateUserId, [2]: string, [3]: number, [4]: string, [5]: number?, [6]: integer, [7]: integer?, [8]: integer?, [9]: integer?}[]
--- user_id, user_name, rating, placement_done, placement_rating, ranked_games_played, ranked_games_won, last_login_time, public_id
function Leaderboard:importData(data)
  if data then
    for row = 2, #data do
      local number = tostring(data[row][1])
      assert(number)
      data[row][1] = number
---@diagnostic disable-next-line: missing-fields
      self.players[data[row][1]] = {}
      for col = 1, #data[1] do
        --Note csv_table[row][1] will be the player's user_id
        --csv_table[1][col] will be a property name such as "rating"
        if data[row][col] == "" then
          data[row][col] = nil
        end
        --player with this user_id gets this property equal to the csv_table cell's value
        if data[1][col] == "user_name" then
          self.players[data[row][1]][data[1][col]] = tostring(data[row][col])
        elseif data[1][col] == "rating" then
          self.players[data[row][1]][data[1][col]] = tonumber(data[row][col])
        elseif data[1][col] == "placement_done" then
          self.players[data[row][1]][data[1][col]] = data[row][col] and string.lower(data[row][col]) ~= "false"
        elseif data[1][col] == "public_id" then
          self.players[data[row][1]][data[1][col]] = tonumber(data[row][col])
        else
          self.players[data[row][1]][data[1][col]] = data[row][col]
        end
      end
    end
  end
end

---@deprecated should change this to a "last ranked game played" column instead
function Leaderboard:update_timestamp(user_id)
  if self.players[user_id] then
    local timestamp = os.time()
    self.players[user_id].last_login_time = timestamp
    self:emitSignal("leaderboardChanged", self)
    logger.debug(user_id .. "'s login timestamp has been updated to " .. timestamp)
  else
    logger.debug(user_id .. " is not on the leaderboard, so no timestamp will be assigned at this time.")
  end
end

---@param userId privateUserId
---@return boolean processPlacementMatches if the player's placement matches should get processed
---@return string? reason why they should not get processed
function Leaderboard:qualifies_for_placement(userId)
  --local placement_match_win_ratio_requirement = .2
  self:loadPlacementMatches(userId)
  local placement_matches_played = #self.loadedPlacementMatches.incomplete[userId]
  if (self.players[userId] and self.players[userId].placement_done) then
    return false, "user is already placed"
  elseif placement_matches_played < ELO.consts.PLACEMENT_MATCH_COUNT_REQUIREMENT then
    return false, placement_matches_played .. "/" .. ELO.consts.PLACEMENT_MATCH_COUNT_REQUIREMENT .. " placement matches played."
  -- else
  -- local win_ratio
  -- local win_count
  -- for i=1,placement_matches_played do
  -- win_count = win_count + self.loadedPlacementMatches.incomplete[user_id][i].outcome
  -- end
  -- win_ratio = win_count / placement_matches_played
  -- if win_ratio < placement_match_win_ratio_requirement then
  -- return false, "placement win ratio is currently "..math.round(win_ratio*100).."%.  "..math.round(placement_match_win_ratio_requirement*100).."% is required for placement."
  -- end
  elseif not ELO.consts.PLACEMENT_MATCHES_ENABLED then
    return false, ""
  end
  return true
end

---@param userId privateUserId
function Leaderboard:loadPlacementMatches(userId)
  logger.debug("Requested loading placement matches for user_id:  " .. (userId or "nil"))
  if not self.loadedPlacementMatches.incomplete[userId] then
    self.loadedPlacementMatches.incomplete[userId] = self.persistence.getPlacementData(userId)
    logger.debug(tostring(self.loadedPlacementMatches.incomplete[userId]))
    logger.debug(json.encode(self.loadedPlacementMatches.incomplete[userId]))
  else
    logger.debug("Didn't load placement matches from file. It is already loaded")
  end

  return self.loadedPlacementMatches.incomplete[userId]
end

---@param player ServerPlayer
---@return number rating 0 if no rating has been set yet
function Leaderboard:getRating(player)
  if self.players[player.userId] then
    local lp = self.players[player.userId]
    if lp.placement_done then
      return lp.rating or 0
    else
      -- the leaderboard is a backend processing component and should not have any opinions on display matters
      -- as long as it communicates someone is still in their placement matches, the client can choose to hide it
      return lp.placement_rating or 0
    end
  else
    return 0
  end
end

---@param player ServerPlayer
---@return string?
function Leaderboard:getPlacementProgress(player)
  local qualifies, progress = self:qualifies_for_placement(player.userId)
  if not (self.players[player.userId] and self.players[player.userId].placement_done) and not qualifies then
    return progress
  end
end

---@param player ServerPlayer
function Leaderboard:addToLeaderboard(player)
  if not self.players[player.userId] or not self.players[player.userId].rating then
    self.players[player.userId] = {user_name = player.name, rating = ELO.consts.DEFAULT_RATING, publicId = player.publicPlayerID}
    logger.debug("Gave " .. self.players[player.userId].user_name .. " a new rating of " .. ELO.consts.DEFAULT_RATING)
    if not ELO.consts.PLACEMENT_MATCHES_ENABLED then
      self.players[player.userId].placement_done = true
    end
    self:emitSignal("leaderboardChanged", self)
  end
end

---@param serverPlayer ServerPlayer
---@return LeaderboardPlayer
function Leaderboard:getLeaderboardPlayer(serverPlayer)
  if self.players[serverPlayer.userId] then
    return self.players[serverPlayer.userId]
  else
    return {user_name = serverPlayer.name, rating = ELO.consts.DEFAULT_RATING, publicId = serverPlayer.publicPlayerID}
  end
end

---@param rating number
---@return string
function Leaderboard:get_league(rating)
  if not rating then
    return leagues[1].league --("Newcomer")
  end
  for i = 1, #leagues do
    if i == #leagues or leagues[i + 1].min_rating > rating then
      return leagues[i].league
    end
  end
  return "LeagueNotFound"
end

---@param player LeaderboardPlayer
---@param opponent LeaderboardPlayer
---@param result (0 | 1)
function Leaderboard:addPlacementResult(player, opponent, result)
  local placementMatches = self:loadPlacementMatches(player.userId)
  placementMatches[#placementMatches+1] = {
    op_user_id = opponent.userId,
    op_name = opponent.name,
    op_rating = self.players[opponent.userId].rating,
    outcome = result
  }

  logger.debug("PRINTING PLACEMENT MATCHES FOR USER")
  logger.debug(json.encode(self.loadedPlacementMatches.incomplete[player.userId]))
  self.persistence.persistPlacementGames(player.userId, self.loadedPlacementMatches.incomplete[player.userId])

  local leaderboardPlayer = self.players[player.userId]
  --adjust newcomer's placement_rating
  leaderboardPlayer.placement_rating = ELO.calculate_rating_adjustment(leaderboardPlayer.placement_rating or ELO.consts.DEFAULT_RATING, self.players[opponent.userId].rating, result, ELO.getK(leaderboardPlayer))
  logger.debug("New newcomer rating: " .. leaderboardPlayer.placement_rating)
end

---@param game ServerGame
---@return boolean # if the game is a placement game
---@return LeaderboardPlayer?
function Leaderboard:isPlacementGame(game)
  for _, player in ipairs(game.players) do
    if not self.players[player.userId].placement_done then
      return true, self.players[player.userId]
    end
  end
  return false
end

---@alias RatingUpdate {old: number, new: number, difference: number, ranked_games_played: integer, ranked_games_won: integer, userId: privateUserId, placement_match_progress: string, league: string}

---@param game ServerGame
---@return RatingUpdate[] # The rating changes for each player in the game
function Leaderboard:processGameResult(game)
  if not game.winnerId then
    -- the current approach is to ignore ties
    return {}
  end

  if #game.players ~= self.playersPerGame then
    logger.error("This leaderboard is only made to process results from games between two players")
    return {}
  end

  if not self:rating_adjustment_approved(game.players) then
    return {}
  end

  for _, player in ipairs(game.players) do
    --if they aren't on the leaderboard yet, give them the default rating
    self:addToLeaderboard(player)
  end

  
  local isPlacementGame, placementPlayer = self:isPlacementGame(game)
  local leaderboardGame = LeaderboardGame(self, game)

  local ratings = ELO.processGameResult(self, leaderboardGame, isPlacementGame, placementPlayer)

  for i, player in ipairs(game.players) do
    local leaderboardPlayer = self.players[player.userId]
    if not isPlacementGame or player == placementPlayer then
      -- placement games don't count as games for ranked players until they are done at which point these stats are updated from the placement match data
      leaderboardPlayer.ranked_games_played = (leaderboardPlayer.ranked_games_played or 0) + 1
      if player.publicPlayerID == game.winnerId then
        leaderboardPlayer.ranked_games_won = (leaderboardPlayer.ranked_games_won or 0) + 1
      end
    end
    if leaderboardPlayer.placement_done then
      leaderboardPlayer.rating = ratings[i].new
    end
    ratings[i].ranked_games_played = leaderboardPlayer.ranked_games_played or 0
    ratings[i].ranked_games_won = leaderboardPlayer.ranked_games_won or 0
    ratings[i].userId = player.userId
    if ratings[i].placement_match_progress then
      ratings[i].league = self:get_league(0)
    else
      ratings[i].league = self:get_league(ratings[i].new)
    end
  end

  logger.debug("done with Leaderboard.processGameResult")
  self:emitSignal("leaderboardChanged", self)

  return ratings
end

---@param userId privateUserId
function Leaderboard:process_placement_matches(userId)
  self:loadPlacementMatches(userId)
  local placement_matches = self.loadedPlacementMatches.incomplete[userId]
  if #placement_matches < 1 then
    logger.error("Failed to process placement matches because we couldn't find any")
    return
  end

  --assign the current placement_rating as the newcomer's official rating.
  self.players[userId].rating = self.players[userId].placement_rating
  self.players[userId].placement_done = true
  logger.debug("FINAL PLACEMENT RATING for " .. (self.players[userId].user_name or "nil") .. ": " .. (self.players[userId].rating or "nil"))

  --Calculate changes to opponents ratings for placement matches won/lost
  logger.debug("adjusting opponent rating(s) for these placement matches")
  for i = 1, #placement_matches do
    if placement_matches[i].outcome == 0 then
      op_outcome = 1
    else
      op_outcome = 0
    end
    local op_rating_change = ELO.calculate_rating_adjustment(placement_matches[i].op_rating, self.players[userId].placement_rating, op_outcome, 10) - placement_matches[i].op_rating
    self.players[placement_matches[i].op_user_id].rating = self.players[placement_matches[i].op_user_id].rating + op_rating_change
    self.players[placement_matches[i].op_user_id].ranked_games_played = (self.players[placement_matches[i].op_user_id].ranked_games_played or 0) + 1
    self.players[placement_matches[i].op_user_id].ranked_games_won = (self.players[placement_matches[i].op_user_id].ranked_games_won or 0) + op_outcome
  end
  self.players[userId].placement_done = true

  self.persistence.persistPlacementFinalization(userId)
  self:emitSignal("leaderboardChanged", self)
end

---@param players ServerPlayer[]
---@return boolean # if the players can play ranked with their current settings
---@return string[] reasons why the players cannot play ranked with each other
function Leaderboard:rating_adjustment_approved(players)
  --returns whether both players in the room have game states such that rating adjustment should be approved

  local lbPlayers = {}

  for i, player in ipairs(players) do
    lbPlayers[i] = self:getLeaderboardPlayer(player)
  end

  local approved, reasons = ELO.canPlayRatedMatch(lbPlayers)
  return approved, reasons
end

---@return table[] # the leaderboard with full information for saving internally
---@return table[] # the leaderboard with a reduced data set for saving in a publicly accessible location
function Leaderboard:toSheetData()
  local leaderboard_table = {}
  local public_leaderboard_table = {}
  leaderboard_table[#leaderboard_table + 1] = {"user_id", "user_name", "rating", "placement_done", "placement_rating", "ranked_games_played", "ranked_games_won","last_login_time"}
  public_leaderboard_table[#public_leaderboard_table + 1] = {"user_name", "rating", "ranked_games_played"} --excluding ranked_games_won for now because it doesn't track properly, and user_id because they are secret.
  for user_id, v in pairs(self.players) do
    leaderboard_table[#leaderboard_table + 1] = {user_id, v.user_name, v.rating, tostring(v.placement_done or ""), v.placement_rating, v.ranked_games_played, v.ranked_games_won, v.last_login_time}
    public_leaderboard_table[#public_leaderboard_table + 1] = {v.user_name, v.rating, v.ranked_games_played}
  end

  return leaderboard_table, public_leaderboard_table
end

return Leaderboard