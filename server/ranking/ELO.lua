---@class RatingAlgorithm


---@class ELO : RatingAlgorithm
local ELO = {}

ELO.consts = {
  DEFAULT_RATING = 1500,
  RATING_SPREAD_MODIFIER = 400,
  PLACEMENT_MATCH_COUNT_REQUIREMENT = 30,
  ALLOWABLE_RATING_SPREAD_MULTIPLIER = .9,
  K = 10,
  PLACEMENT_MATCHES_ENABLED = true,
  PLACEMENT_MATCH_K = 50,
  MIN_LEVEL_FOR_RANKED = 1,
  MAX_LEVEL_FOR_RANKED = 10,
  MIN_PLAYER_COUNT = 2,
  MAX_PLAYER_COUNT = 2,
}

---@param players LeaderboardPlayer[]
---@return boolean
---@return string[] reasons or caveats
function ELO.canPlayRatedMatch(players)
  local reasons = {}
  local caveats = {}
  local both_players_are_placed = nil

  if #players < ELO.consts.MIN_PLAYER_COUNT or #players > ELO.consts.MAX_PLAYER_COUNT then
    return false, {"This rating algorithm is only made to process results from games between two players"}
  end

  if ELO.consts.PLACEMENT_MATCHES_ENABLED then
    if players[1].placement_done and players[2].placement_done then
      --both players are placed on the leaderboard.
      both_players_are_placed = true
    elseif not players[1].placement_done and not players[2].placement_done then
      reasons[#reasons + 1] = "Neither player has finished enough placement matches against already ranked players"
    end
  else
    both_players_are_placed = true
  end
  -- don't let players use the same account
  if players[1].publicId == players[2].publicId then
    reasons[#reasons + 1] = "Players cannot use the same account"
  end

  --don't let players too far apart in rating play ranked
  local ratings = {}
  for i, player in ipairs(players) do
    if not player.placement_done and player.placement_rating then
      ratings[i] = player.placement_rating
    elseif player.rating and player.rating ~= 0 then
      ratings[i] = player.rating
    else
      ratings[i] = ELO.consts.DEFAULT_RATING
    end
  end
  if math.abs(ratings[1] - ratings[2]) > ELO.consts.RATING_SPREAD_MODIFIER * ELO.consts.ALLOWABLE_RATING_SPREAD_MULTIPLIER then
    reasons[#reasons + 1] = "Players' ratings are too far apart"
  end

  local player_level_out_of_bounds_for_ranked = false
  for i = 1, 2 do --we'll change 2 here when more players are allowed.
    if (players[i].level < ELO.consts.MIN_LEVEL_FOR_RANKED or players[i].level > ELO.consts.MAX_LEVEL_FOR_RANKED) then
      player_level_out_of_bounds_for_ranked = true
    end
  end
  if player_level_out_of_bounds_for_ranked then
    reasons[#reasons + 1] = "Only levels between " .. ELO.consts.MIN_LEVEL_FOR_RANKED .. " and " .. ELO.consts.MAX_LEVEL_FOR_RANKED .. " are allowed for ranked play."
  end

  if reasons[1] then
    return false, reasons
  else
    if ELO.consts.PLACEMENT_MATCHES_ENABLED and not both_players_are_placed and ((players[1].placement_done) or (players[2].placement_done)) then
      caveats[#caveats + 1] = "Note: Rating adjustments for these matches will be processed when the newcomer finishes placement."
    end
    return true, caveats
  end
end

---@param player LeaderboardPlayer
function ELO.getK(player)
  local k
  if player.placement_done then
    return ELO.consts.K
  else
   return ELO.consts.PLACEMENT_MATCH_K
  end
end

function ELO.calculate_rating_adjustment(Rc, Ro, Oa, k) -- -- print("calculating expected outcome for") -- print(players[player_number].name.." Ranking: "..self.players[players[player_number].user_id].rating)
  --[[ --Algorithm we are implementing, per community member Bbforky:
      Formula for Calculating expected outcome:
      RATING_SPREAD_MODIFIER = 400
      Oe=1/(1+10^((Ro-Rc)/RATING_SPREAD_MODIFIER)))

      Oe= Expected Outcome
      Ro= Current rating of opponent
      Rc= Current rating

      Formula for Calculating new rating:

      Rn=Rc+k(Oa-Oe)

      Rn=New Rating
      Oa=Actual Outcome (0 for loss, 1 for win)
      k= Constant (Probably will use 10)
  ]] -- print("vs")
  -- print(players[player_number].opponent.name.." Ranking: "..self.players[players[player_number].opponent.user_id].rating)
  Oe = 1 / (1 + 10 ^ ((Ro - Rc) / ELO.consts.RATING_SPREAD_MODIFIER))
  -- print("expected outcome: "..Oe)
  Rn = Rc + k * (Oa - Oe)
  return Rn
end

---@param leaderboard Leaderboard
---@param game LeaderboardGame
---@param isPlacementGame boolean
---@param placementPlayer LeaderboardPlayer
---@return RatingUpdate[] # The rating changes for each player in the game
function ELO.processGameResult(leaderboard, game, isPlacementGame, placementPlayer)
  local ratings = {}

  for i, player in ipairs(game.players) do
    local rating = {}
    rating.old = player.rating
    ratings[i] = rating
  end

  if isPlacementGame then
    ---@cast placementPlayer -nil
    -- if it is a placement match we only need to calculate the placement player and possible finalize placement if the game finished their placements
    -- for the other player there is either no calculation or the calculation is done in the placement finalization

    local placementIndex
    local rankedIndex
    local rankedPlayer
    if game.players[1] == placementPlayer then
      placementIndex = 1
      rankedIndex = 2
    else
      placementIndex = 2
      rankedIndex = 1
    end
    rankedPlayer = game.players[rankedIndex]

    local Oa = (game.winnerId == placementPlayer.publicPlayerID) and 1 or 0
    leaderboard:addPlacementResult(placementPlayer, rankedPlayer, Oa)
    local processPlacementMatches, reason = leaderboard:qualifies_for_placement(placementPlayer.userId)
    if processPlacementMatches then
      leaderboard:process_placement_matches(placementPlayer.userId)
    else
      ratings[placementIndex].placement_match_progress = reason
    end
    for i, player in ipairs(game.players) do
      ratings[i].new = player.rating
      ratings[i].difference = ratings[i].new - ratings[i].old
    end
  else
    local Oa = (game.winnerId == game.players[1].publicPlayerID) and 1 or 0
    ratings[1].new = ELO.calculate_rating_adjustment(ratings[1].old, ratings[2].old, Oa, ELO.getK(game.players[1]))
    ratings[1].difference = ratings[1].new - ratings[1].old

    Oa = (Oa == 1 and 0 or 1)
    ratings[2].new = ELO.calculate_rating_adjustment(ratings[2].old, ratings[1].old, Oa, ELO.getK(game.players[2]))
    ratings[2].difference = ratings[2].new - ratings[2].old
  end

  return ratings
end


return ELO