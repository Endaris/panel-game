local MatchParticipant = require("client.src.MatchParticipant")
local class = require("common.lib.class")
local CharacterLoader = require("client.src.mods.CharacterLoader")
local ChallengeModePlayerStack = require("client.src.ChallengeModePlayerStack")

---@class ChallengeModePlayerSettings : ParticipantSettings
---@field attackEngineSettings table
---@field healthSettings table
---@field difficulty integer the overall difficulty of the selected challenge mode this player is used in
---@field level integer the current stage within the challenge mode difficulty

---@class ChallengeModePlayer : MatchParticipant
---@field usedCharacterIds string[] array of character ids that have already been used during the life time of the player
---@field settings ChallengeModePlayerSettings

local ChallengeModePlayer = class(
function(self, playerNumber)
  self.name = "Challenger"
  self.playerNumber = playerNumber
  self.isLocal = true
  self.settings.attackEngineSettings = nil
  self.settings.healthSettings = nil
  self.settings.wantsReady = true
  self.usedCharacterIds = {}
  self.human = false
end,
MatchParticipant)

local function characterForStageNumber(stageNumber)
  -- Get all other characters than the player character
  local otherCharacters = {}
  for _, currentCharacter in ipairs(visibleCharacters) do
    if currentCharacter ~= config.character and characters[currentCharacter]:isBundle() == false then
      otherCharacters[#otherCharacters+1] = currentCharacter
    end
  end

  -- If we couldn't find any characters, try sub characters as a last resort
  if #otherCharacters == 0 then
    for _, currentCharacter in ipairs(visibleCharacters) do
      if characters[currentCharacter]:isBundle() == true then
        currentCharacter = characters[currentCharacter].subIds[1]
      end
      if currentCharacter ~= config.character then
        otherCharacters[#otherCharacters+1] = currentCharacter
      end
    end
  end

  local character = otherCharacters[((stageNumber - 1) % #otherCharacters) + 1]
  return character
end

function ChallengeModePlayer:createStackFromSettings(match, which)
  assert(self.settings.healthSettings or self.settings.attackEngineSettings)
  local stack = ChallengeModePlayerStack({
    which = which,
    character = self.settings.characterId,
    is_local = not (match.replay and match.replay.completed),
    attackSettings = self.settings.attackEngineSettings,
    healthSettings = self.settings.healthSettings,
    match = match,
  })

  self.stack = stack
  stack.player = self

  return stack
end

function ChallengeModePlayer:setCharacterForStage(stageNumber)
  self:setCharacter(characterForStageNumber(stageNumber))
end

-- challenge mode players are always ready
function ChallengeModePlayer:setWantsReady(wantsReady)
  self.settings.wantsReady = true
  self:emitSignal("wantsReadyChanged", true)
end

function ChallengeModePlayer.createFromReplayPlayer(replayPlayer, playerNumber)
  local player = ChallengeModePlayer(playerNumber)
  player.settings.attackEngineSettings = replayPlayer.settings.attackEngineSettings
  player.settings.healthSettings = replayPlayer.settings.healthSettings
  player.settings.characterId = CharacterLoader.fullyResolveCharacterSelection(replayPlayer.settings.characterId)
  player.settings.difficulty = replayPlayer.settings.difficulty
  player.isLocal = false
  return player
end

function ChallengeModePlayer:getInfo()
  local info = {}
  info.characterId = self.settings.characterId
  info.selectedCharacterId = self.settings.selectedCharacterId
  info.stageId = self.settings.stageId
  info.selectedStageId = self.settings.selectedStageId
  info.panelId = self.settings.panelId
  info.wantsReady = self.settings.wantsReady
  info.playerNumber = self.playerNumber
  info.isLocal = self.isLocal
  info.human = self.human
  info.wins = self.wins
  info.modifiedWins = self.modifiedWins

  return info
end

return ChallengeModePlayer