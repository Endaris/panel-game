local class = require("common.lib.class")
local GameModes = require("common.engine.GameModes")
local LevelPresets = require("common.data.LevelPresets")
local input = require("client.src.inputManager")
local MatchParticipant = require("client.src.MatchParticipant")
local consts = require("common.engine.consts")
local CharacterLoader = require("client.src.mods.CharacterLoader")
local PlayerStack = require("client.src.PlayerStack")
require("client.src.network.PlayerStack")
local logger = require("common.lib.logger")
---@module "common.data.LevelData"

-- A player is mostly a data representation of a Panel Attack player
-- It holds data pertaining to their online status (like name, public id)
-- It holds data pertaining to their client status (like character, stage, panels, level etc)
-- Player implements a lot of setters that emit signals on changes, allowing other components to be notified about the changes by connecting a function to it
-- Due to this, unless for a good reason, all properties on Player should be set using the setters
---@class Player : MatchParticipant, Signal
---@overload fun(name: string, publicId: integer, isLocal: boolean?)
local Player = class(
function(self, name, publicId, isLocal)
  ---@class Player
  self = self
  self.name = name
  self.settings = {
    -- these need to all be initialized so subscription works
    -- the gist is that all settings inside here are modifiable clientside for local players as part of match setup
    -- while everything outside settings is static or dictated server side
    level = 1,
    difficulty = 1,
    speed = 1,
    ---@type LevelData
    levelData = LevelPresets.getModern(1),
    style = GameModes.Styles.MODERN,
    characterId = "",
    stageId = "",
    panelId = "",
    wantsReady = false,
    wantsRanked = true,
    inputMethod = "controller",
    attackEngineSettings = nil,
    puzzleSet = nil,
    puzzleIndex = nil
  }
  -- planned for the future, players don't have public ids yet
  self.publicId = publicId or -1
  self.league = nil
  self.rating = nil
  self.ratingHistory = {}
  self.stack = nil
  self.playerNumber = nil
  self.isLocal = isLocal or false
  -- a player may have only one configuration at a time
  self.inputConfiguration = nil
  self.human = true

  -- the player emits signals when its properties change that other components may be interested in
  -- they can register a callback with each signal via Signal.connectSignal
  -- there are a few more signals in MatchParticipant (which is why we don't have to explicitly declare us as emitting Signals again)
  self:createSignal("styleChanged")
  self:createSignal("difficultyChanged")
  self:createSignal("startingSpeedChanged")
  self:createSignal("colorCountChanged")
  self:createSignal("levelChanged")
  self:createSignal("levelDataChanged")
  self:createSignal("inputMethodChanged")
  self:createSignal("puzzleSetChanged")
  self:createSignal("ratingChanged")
  self:createSignal("leagueChanged")
  self:createSignal("wantsRankedChanged")
end,
MatchParticipant)

Player.TYPE = "Player"

-- creates a stack for the given match according to the player's settings and returns it
-- the stack is also saved as a reference on player
function Player:createStackFromSettings(match, which)
  local args = {}
  args.which = which
  args.player_number = self.playerNumber
  args.is_local = self.isLocal
  args.panels_dir = self.settings.panelId
  args.character = self.settings.characterId
  if self.settings.style == GameModes.Styles.MODERN then
    args.level = self.settings.level
    if match.stackInteraction == GameModes.StackInteractions.NONE then
      args.allowAdjacentColors = true
    else
      args.allowAdjacentColors = args.level < 8
    end
  else
    args.difficulty = self.settings.difficulty
    args.allowAdjacentColors = true
  end

  ---@type LevelData
  args.levelData = self.settings.levelData

  -- the client Player does not currently allow management of allowAdjacentColors
  -- so it is determined above by looking at match and player properties
  -- but it is tracked in replays and set for player in createFromReplayPlayer
  -- so if the match is from a loaded replay, use it
  if match.replay and self.settings.allowAdjacentColors ~= nil then
    args.allowAdjacentColors = self.settings.allowAdjacentColors
  end
  args.inputMethod = self.settings.inputMethod
  args.stackInteraction = match.stackInteraction
  args.gameOverConditions = match.gameOverConditions
  args.seed = match.seed
  args.match = match

  args.player = self

  self.stack = PlayerStack(args)

  return self.stack
end

function Player:getRatingDiff()
  if self.rating and tonumber(self.rating) and #self.ratingHistory > 0 then
    return self.rating - self.ratingHistory[#self.ratingHistory]
  else
    return 0
  end
end

function Player:setPanels(panelId)
  if panelId ~= self.settings.panelId then
    if panels[panelId] then
      self.settings.panelId = panelId
    else
      -- default back to config panels always
      self.settings.panelId = config.panels
    end
    -- panels are always loaded so no loading is necessary

    self:emitSignal("panelIdChanged", self.settings.panelId)
  end
end

function Player:setWantsRanked(wantsRanked)
  if wantsRanked ~= self.settings.wantsRanked then
    self.settings.wantsRanked = wantsRanked
    self:emitSignal("wantsRankedChanged", wantsRanked)
  end
end

function Player:setDifficulty(difficulty)
  if difficulty ~= self.settings.difficulty then
    self.settings.difficulty = difficulty
    if self.settings.style == GameModes.Styles.CLASSIC then
      self:setLevelData(LevelPresets.getClassic(difficulty))
    end
    self:emitSignal("difficultyChanged", difficulty)
  end
end

---@param levelData LevelData
function Player:setLevelData(levelData)
  self.settings.levelData = levelData
  self:setColorCount(levelData.colors)
  self:setSpeed(levelData.startingSpeed)
  self:emitSignal("levelDataChanged", levelData)
end

function Player:setSpeed(speed)
  if speed ~= self.settings.speed or speed ~= self.settings.levelData.startingSpeed then
    self.settings.levelData.startingSpeed = speed
    self.settings.speed = speed
    self:emitSignal("startingSpeedChanged", speed)
  end
end

function Player:setColorCount(colorCount)
  if colorCount ~= self.settings.colorCount or colorCount ~= self.settings.levelData.colors  then
    self.settings.levelData.colors = colorCount
    self.settings.colorCount = colorCount
    self:emitSignal("colorCountChanged", colorCount)
  end
end

function Player:setLevel(level)
  if level ~= self.settings.level then
    self.settings.level = level
    if self.settings.style == GameModes.Styles.MODERN then
      self:setLevelData(LevelPresets.getModern(level))
    end
    self:emitSignal("levelChanged", level)
  end
end

function Player:setInputMethod(inputMethod)
  if inputMethod ~= self.settings.inputMethod then
    self.settings.inputMethod = inputMethod
    self:emitSignal("inputMethodChanged", inputMethod)
  end
end

-- sets the style of "level" presets the player selects from
-- 1 = classic
-- 2 = modern
-- longterm we want to abandon the concept of "style" on the player / battleRoom level
-- just setting difficulty or level should set the levelData and done with it, style is a menu-only concept
-- there is no technical reason why someone on level 10 shouldn't be able to play against someone on Hard
function Player:setStyle(style)
  if style ~= self.settings.style then
    self.settings.style = style
    if style == GameModes.Styles.MODERN then
      self:setLevelData(LevelPresets.getModern(self.settings.level or config.level))
    else
      self:setLevelData(LevelPresets.getClassic(self.settings.difficulty or config.difficulty))
      self:setSpeed(self.settings.speed)
    end
    -- reset color count while we don't have an established caching mechanism for it
    self:setColorCount(self.settings.levelData.colors)
    self:emitSignal("styleChanged", style)
  end
end

function Player:setPuzzleSet(puzzleSet)
  if puzzleSet ~= self.settings.puzzleSet then
    self.settings.puzzleSet = puzzleSet
    self:emitSignal("puzzleSetChanged", puzzleSet)
  end
  self.settings.puzzleIndex = 1
end

function Player:setPuzzleIndex(puzzleIndex)
  if puzzleIndex ~= self.settings.puzzleIndex then
    self.settings.puzzleIndex = puzzleIndex
  end
end

function Player:setRating(rating)
  if self.rating and tonumber(self.rating) then
    -- only save a rating if we actually have one, tonumber assures that rating does not track placement progress instead
    self.ratingHistory[#self.ratingHistory + 1] = self.rating
  end

  if rating and tonumber(rating) then
    rating = math.round(tonumber(rating))
  end

  self.rating = rating
  self:emitSignal("ratingChanged", rating, self:getRatingDiff())
end

function Player:setLeague(league)
  if self.league ~= league then
    self.league = league
    self:emitSignal("leagueChanged", league)
  end
end

function Player:restrictInputs(inputConfiguration)
  if self.inputConfiguration and self.inputConfiguration ~= inputConfiguration then
    error("Player " .. self.playerNumber .. " is trying to claim a second input configuration")
  end
  self.inputConfiguration = input:claimConfiguration(self, inputConfiguration)
end

function Player:unrestrictInputs()
  if self.inputConfiguration then
    -- in the case of online play, it is possible that we ready up, causing the server to send out a match start message
    -- and then before that arrives we unready, thus losing the input configuration which crashes the match
    -- for this case, the last used input configuration is stored here
    -- if a match start arrives while no input configuration is set, the player gets restricted to the last used one again
    logger.debug("Unrestricting inputs for player " .. self.playerNumber)
    self.lastUsedInputConfiguration = self.inputConfiguration
    input:releaseConfiguration(self, self.inputConfiguration)
    self.inputConfiguration = nil
  end
end

---@return Player
function Player.getLocalPlayer()
  local player = Player(config.name, -1, true)

  player:setDifficulty(config.endless_difficulty)
  player:setSpeed(config.endless_speed)
  player:setLevel(config.level)
  player:setCharacter(config.character)
  player:setStage(config.stage)
  player:setPanels(config.panels)
  player:setWantsReady(false)
  player:setWantsRanked(config.ranked)
  player:setInputMethod(config.inputMethod)
  if config.endless_level then
    player:setStyle(GameModes.Styles.MODERN)
  else
    player:setStyle(GameModes.Styles.CLASSIC)
  end

  return player
end

function Player.createFromReplayPlayer(replayPlayer, playerNumber)
  local player = Player(replayPlayer.name, replayPlayer.publicId, false)

  player.playerNumber = playerNumber
  player:setWinCount(replayPlayer.wins)
  player:setPanels(replayPlayer.settings.panelId)
  player:setCharacter(replayPlayer.settings.characterId)
  player:setInputMethod(replayPlayer.settings.inputMethod)
  -- style will be obsolete for replays with style-independent levelData
  if replayPlayer.settings.level then
    player:setStyle(GameModes.Styles.MODERN)
    player:setLevel(replayPlayer.settings.level)
  else
    player:setStyle(GameModes.Styles.CLASSIC)
    player:setDifficulty(replayPlayer.settings.difficulty)
  end
  -- no matter what style / level / difficulty is actually selected, levelData should have gotten preloaded correctly
  player:setLevelData(replayPlayer.settings.levelData)
  player.settings.allowAdjacentColors = replayPlayer.settings.allowAdjacentColors
  player:setAttackEngineSettings(replayPlayer.settings.attackEngineSettings)

  return player
end

function Player:updateSettings(settings)
  if settings.characterId ~= nil then
    if characters[settings.characterId] then
      -- if we have their character, use it
      self:setCharacter(settings.characterId)
      if characters[settings.selectedCharacterId] then
        -- picking their bundle for display is a bonus
        self.settings.selectedCharacterId = settings.selectedCharacterId
        self:emitSignal("selectedCharacterIdChanged", self.settings.selectedCharacterId)
      end
    elseif settings.selectedCharacterId and characters[settings.selectedCharacterId] then
      -- if we don't have their character rolled from their bundle, but the bundle itself, use that
      -- very unlikely tbh
      self:setCharacter(settings.selectedCharacterId)
    elseif self.settings.characterId == "" then
      -- we don't have their character and we didn't roll them a random character yet
      self:setCharacter(consts.RANDOM_CHARACTER_SPECIAL_VALUE)
    end
  end

  if settings.stageId ~= nil then
    if stages[settings.stageId] then
      -- if we have their stage, use it
      self:setStage(settings.stageId)
      if stages[settings.selectedStageId] then
        -- picking their bundle for display is a bonus
        self.settings.selectedStageId = settings.selectedStageId
        self:emitSignal("selectedStageIdChanged", self.settings.selectedStageId)
      end
    elseif settings.selectedStageId and stages[settings.selectedStageId] then
      -- if we don't have their stage rolled from their bundle, but the bundle itself, use that
      -- very unlikely tbh
      self:setStage(settings.selectedStageId)
    elseif self.settings.stageId == "" then
      -- we don't have their stage and we didn't roll them a random stage yet
      self:setStage(consts.RANDOM_STAGE_SPECIAL_VALUE)
    end
  end

  if settings.wantsRanked ~= nil then
    self:setWantsRanked(settings.wantsRanked)
  end

  if settings.panelId ~= nil then
    self:setPanels(settings.panelId)
  end

  if settings.levelData ~= nil then
    if settings.level ~= nil then
      if settings.levelData.frameConstants.GARBAGE_HOVER then
        self:setStyle(GameModes.Styles.MODERN)
        self:setLevel(settings.level)
      else
        self:setStyle(GameModes.Styles.CLASSIC)
        self:setDifficulty(settings.level)
      end
    end

    self:setLevelData(settings.levelData)
  end

  if settings.inputMethod ~= nil then
    self:setInputMethod(settings.inputMethod)
  end

  -- these are both simply not sent by the server for some messages so make sure they are there
  if settings.wantsReady ~= nil then
    self:setWantsReady(settings.wantsReady)
  end
  if settings.hasLoaded ~= nil then
    self:setLoaded(settings.hasLoaded)
  end

  if settings.ready ~= nil then
    self:setReady(settings.ready)
  end
end

function Player:getInfo()
  local info = {}
  info.name = self.name
  info.level = self.settings.level
  info.difficulty = self.settings.difficulty
  info.speed = self.settings.speed
  info.characterId = self.settings.characterId
  info.selectedCharacterId = self.settings.selectedCharacterId
  info.stageId = self.settings.stageId
  info.selectedStageId = self.settings.selectedStageId
  info.panelId = self.settings.panelId
  info.wantsReady = tostring(self.settings.wantsReady)
  info.wantsRanked = tostring(self.settings.wantsRanked)
  info.inputMethod = self.settings.inputMethod
  info.publicId = self.publicId
  info.playerNumber = self.playerNumber
  info.isLocal = tostring(self.isLocal)
  info.human = tostring(self.human)
  info.wins = self.wins
  info.modifiedWins = self.modifiedWins

  return info
end

return Player