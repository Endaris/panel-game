local class = require("common.lib.class")
local CharacterSelect = require("client.src.scenes.CharacterSelect")
local GameModes = require("common.engine.GameModes")
local ui = require("client.src.ui")

-- Scene for the time attack game setup menu
local TimeAttackMenu = class(
  function(self, sceneParams)
    self.gameMode = GameModes.getPreset("ONE_PLAYER_TIME_ATTACK")
    self.gameScene = "TimeAttackGame"
  end,
  CharacterSelect
)

TimeAttackMenu.name = "TimeAttackMenu"

function TimeAttackMenu:customLoad(sceneParams)
  self:loadUserInterface()
end

function TimeAttackMenu:loadUserInterface()
  local player = GAME.battleRoom.players[1]

  local unitSize = 100
  self.ui.grid = ui.Grid({unitSize = unitSize, gridWidth = 9, gridHeight = 6, unitMargin = 8, hAlign = "center", vAlign = "center"})
  self.uiRoot:addChild(self.ui.grid)

  self.ui.characterIcons[1] = self:createPlayerIcon(player)
  self.ui.grid:createElementAt(1, 1, 1, 1, "selectedCharacter", self.ui.characterIcons[1])

  self.ui.recordBox = self:createRecordsBox("Last Score")
  self.ui.recordBox:setVisibility(player.settings.style == GameModes.Styles.CLASSIC)
  self:refresh()
  self.ui.grid:createElementAt(2, 1, 2, 1, "recordBox", self.ui.recordBox, nil, true)

  self.ui.panelSelection = ui.MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "top"})
  self.ui.panelSelection:setTitle("panels")
  local panelCarousel = self:createPanelCarousel(player, self.ui.grid.unitSize - self.ui.grid.unitMargin * 2 - self.ui.panelSelection.height)
  self.ui.panelSelection:addElement(panelCarousel, player)
  self.ui.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.ui.panelSelection, nil, true)

  local stageCarousel = self:createStageCarousel(player, self.ui.grid.unitSize * 2 - self.ui.grid.unitMargin * 2)
  self.ui.stageSelection = ui.MultiPlayerSelectionWrapper({vFill = true, alignment = "left", hAlign = "center", vAlign = "center"})
  self.ui.stageSelection:setTitle("stage")
  self.ui.stageSelection:addElement(stageCarousel, player)
  self.ui.grid:createElementAt(3, 2, 2, 1, "stageSelection", self.ui.stageSelection, nil, true)

  self.ui.styleSelection = ui.MultiPlayerSelectionWrapper({vFill = true, alignment = "left", hAlign = "center", vAlign = "center"})
  self.ui.styleSelection:setTitle("endless_modern")
  local styleSelector = self:createStyleSelection(player, unitSize)
  self.ui.styleSelection:addElement(styleSelector, player)

  self.ui.grid:createElementAt(5, 2, 1, 1, "styleSelection", self.ui.styleSelection, nil, true)

  self.ui.speedSelection = ui.MultiPlayerSelectionWrapper({
    hFill = true,
    alignment = "top",
    hAlign = "center",
    vAlign = "top",
  })
  self.ui.speedSelection:setTitle("speed")
  local speedSlider = self:createSpeedSlider(player, self.ui.grid.unitSize - self.ui.grid.unitMargin * 2 - self.ui.speedSelection.height)
  self.ui.speedSelection:addElement(speedSlider, player)

  self.ui.difficultySelection = ui.MultiPlayerSelectionWrapper({
    hFill = true,
    alignment = "top",
    hAlign = "center",
    vAlign = "top",
  })
  self.ui.difficultySelection:setTitle("difficulty")

  local difficultyCarousel = self:createDifficultyCarousel(player, self.ui.grid.unitSize - self.ui.grid.unitMargin * 2 - self.ui.difficultySelection.height)
  self.ui.difficultySelection:addElement(difficultyCarousel, player)

  self.ui.levelSelection = ui.MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "top"})
  self.ui.levelSelection:setTitle("level")
  local levelSlider = self:createLevelSlider(player, 20, self.ui.grid.unitSize - self.ui.grid.unitMargin * 2 - self.ui.levelSelection.height)
  self.ui.levelSelection:addElement(levelSlider, player)

  if player.settings.style == GameModes.Styles.MODERN then
    self.ui.grid:createElementAt(6, 2, 3, 1, "levelSelection", self.ui.levelSelection, nil, true)
  else
    self.ui.grid:createElementAt(6, 2, 2, 1, "speedSelection", self.ui.speedSelection, nil, true)
    self.ui.grid:createElementAt(8, 2, 1, 1, "difficultySelection", self.ui.difficultySelection, nil, true)
  end

  styleSelector.onValueChange = function(boolSelector, value)
    GAME.theme:playValidationSfx()
    self.ui.grid:removeElementsIn(6, 2, 3, 1)
    if value and player.settings.style ~= GameModes.Styles.MODERN then
      player:setStyle(GameModes.Styles.MODERN)
      self.ui.grid:createElementAt(6, 2, 3, 1, "levelSelection", self.ui.levelSelection, nil, true)
      self.ui.recordBox:setVisibility(false)
    elseif value == false and player.settings.style ~= GameModes.Styles.CLASSIC then
      player:setStyle(GameModes.Styles.CLASSIC)
      self.ui.grid:createElementAt(6, 2, 2, 1, "speedSelection", self.ui.speedSelection, nil, true)
      self.ui.grid:createElementAt(8, 2, 1, 1, "difficultySelection", self.ui.difficultySelection, nil, true)
      self.ui.recordBox:setVisibility(true)
    end
  end

  self.ui.readyButton = self:createReadyButton()
  self.ui.grid:createElementAt(9, 2, 1, 1, "readyButton", self.ui.readyButton)

  local characterButtons = self:getCharacterButtons()
  local characterGridWidth, characterGridHeight = 9, 3
  self.ui.characterGrid = self:createCharacterGrid(characterButtons, self.ui.grid, characterGridWidth, characterGridHeight)
  self.ui.grid:createElementAt(1, 3, characterGridWidth, characterGridHeight, "characterSelection", self.ui.characterGrid, true)

  self.ui.pageIndicator = self:createPageIndicator(self.ui.characterGrid)
  self.ui.grid:createElementAt(5, 6, 1, 1, "pageIndicator", self.ui.pageIndicator)

  self.ui.pageTurnButtons = self:createPageTurnButtons(self.ui.characterGrid)

  self.ui.leaveButton = self:createLeaveButton()
  self.ui.grid:createElementAt(9, 6, 1, 1, "leaveButton", self.ui.leaveButton)

  self.ui.cursors[1] = self:createCursor(self.ui.grid, player)
  self.ui.cursors[1].raise1Callback = function()
    self.ui.characterGrid:turnPage(-1)
  end
  self.ui.cursors[1].raise2Callback = function()
    self.ui.characterGrid:turnPage(1)
  end
end

function TimeAttackMenu:refresh()
  local difficulty
  if GAME.battleRoom then
    difficulty = GAME.battleRoom.players[1].settings.difficulty
  else
    difficulty = GAME.localPlayer.settings.difficulty
  end

  self.lastScore = GAME.scores:lastTimeAttack1PForLevel(difficulty)
  self.record = GAME.scores:recordTimeAttack1PForLevel(difficulty)
  self.ui.recordBox:setLastResult(self.lastScore)
  self.ui.recordBox:setRecord(self.record)
end

return TimeAttackMenu