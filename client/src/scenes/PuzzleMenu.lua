local Scene = require("client.src.scenes.Scene")
local logger = require("common.lib.logger")
local ui = require("client.src.ui")
local class = require("common.lib.class")

-- Scene for the puzzle selection menu
local PuzzleMenu = class(
  function (self, sceneParams)
    self.music = "select_screen"
    self.fallbackMusic = "main"
    -- set in load
    self.levelSlider = nil
    self.randomColorButtons = nil
    self.menu = nil
    self.puzzleLabel = nil

    self:load(sceneParams)
  end,
  Scene
)

PuzzleMenu.name = "PuzzleMenu"

local BUTTON_WIDTH = 60
local BUTTON_HEIGHT = 25

function PuzzleMenu:startGame(puzzleSet)
  if config.puzzle_level ~= self.levelSlider.value or config.puzzle_randomColors ~= self.randomColorsButtons.value then
    logger.debug("saving settings...")
    write_conf_file()
  end

  if config.puzzle_randomColors or config.puzzle_randomFlipped then
    puzzleSet = deepcpy(puzzleSet)

    for _, puzzle in pairs(puzzleSet.puzzles) do
      if config.puzzle_randomColors then
        puzzle.stack = Puzzle.randomizeColorsInPuzzleString(puzzle.stack)
      end
      if config.puzzle_randomFlipped then
        if math.random(2) == 1 then
          puzzle.stack = puzzle:horizontallyFlipPuzzleString()
        end
      end
    end
  end

  GAME.theme:playValidationSfx()

  GAME.localPlayer:setPuzzleSet(puzzleSet)
  GAME.localPlayer:setWantsReady(true)
end

function PuzzleMenu:exit()
  GAME.theme:playValidationSfx()
  GAME.battleRoom:shutdown()
  GAME.navigationStack:pop()
end

function PuzzleMenu:load(sceneParams)
  local tickLength = 16
  self.levelSlider = ui.LevelSlider({
      tickLength = tickLength,
      value = config.puzzle_level or 5,
      onValueChange = function(s)
        GAME.theme:playMoveSfx()
        config.puzzle_level = s.value
        GAME.localPlayer:setLevel(s.value)
      end
    })

  self.randomColorsButtons = ui.ButtonGroup(
    {
      buttons = {
        ui.TextButton({label = ui.Label({text = "op_off"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
        ui.TextButton({label = ui.Label({text = "op_on"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
      },
      values = {false, true},
      selectedIndex = config.puzzle_randomColors and 2 or 1,
      onChange = function(group, value)
        GAME.theme:playMoveSfx()
        config.puzzle_randomColors = value
      end
    }
  )
  
  self.randomlyFlipPuzzleButtons = ui.ButtonGroup(
    {
      buttons = {
        ui.TextButton({label = ui.Label({text = "op_off"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
        ui.TextButton({label = ui.Label({text = "op_on"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
      },
      values = {false, true},
      selectedIndex = config.puzzle_randomFlipped and 2 or 1,
      onChange = function(group, value)
        GAME.theme:playMoveSfx()
        config.puzzle_randomFlipped = value
      end
    }
  )
  
  local menuOptions = {
    ui.MenuItem.createSliderMenuItem("level", nil, nil, self.levelSlider),
    ui.MenuItem.createToggleButtonGroupMenuItem("randomColors", nil, nil, self.randomColorsButtons),
    ui.MenuItem.createToggleButtonGroupMenuItem("randomHorizontalFlipped", nil, nil, self.randomlyFlipPuzzleButtons),
  }

  for puzzleSetName, puzzleSet in pairsSortedByKeys(GAME.puzzleSets) do
    menuOptions[#menuOptions + 1] = ui.MenuItem.createButtonMenuItem(puzzleSetName, nil, false, function() self:startGame(puzzleSet) end)
  end
  menuOptions[#menuOptions + 1] = ui.MenuItem.createButtonMenuItem("back", nil, nil, self.exit)

  self.menu = ui.Menu.createCenteredMenu(menuOptions)

  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  self.puzzleLabel = ui.Label({text = "pz_puzzles", x = x - 10, y = y - 40})

  self.uiRoot:addChild(self.menu)
  self.uiRoot:addChild(self.puzzleLabel)
end

function PuzzleMenu:update(dt)
  self.menu:receiveInputs()
end

function PuzzleMenu:draw()
  themes[config.theme].images.bg_main:draw()
  self.uiRoot:draw()
end

return PuzzleMenu