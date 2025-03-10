local input = require("client.src.inputManager")
local tableUtils = require("common.lib.tableUtils")
local inputFieldManager = require("client.src.ui.inputFieldManager")
local FileUtils = require("client.src.FileUtils")

local function runSystemCommands()
  -- toggle debug mode
  if input.allKeys.isDown["d"] then
    config.debug_mode = not config.debug_mode
  -- reload characters
  elseif input.allKeys.isDown["c"] then
    characters_reload_graphics()
  -- reload panels
  elseif input.allKeys.isDown["p"] then
    panels_init()
  -- reload stages
  elseif input.allKeys.isDown["s"] then
    stages_reload_graphics()
  -- reload themes
  elseif input.allKeys.isDown["t"] then
    themes[config.theme]:deinitializeGraphics()
    themes[config.theme]:json_init()
    themes[config.theme]:graphics_init(true)
    themes[config.theme]:final_init()
  end
end

local function takeScreenshot()
  local now = os.date("*t", to_UTC(os.time()))
  local filename = "screenshot_" .. "v" .. config.version .. "-" .. string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec) .. ".png"
  love.filesystem.createDirectory("screenshots")
  love.graphics.captureScreenshot("screenshots/" .. filename)
  return true
end

local function refreshDesignHelper()
  if GAME.navigationStack:getActiveScene().name == "DesignHelper" then
    package.loaded["client.src.scenes.DesignHelper"] = nil
    GAME.navigationStack:replace(require("client.src.scenes.DesignHelper")())
  end
end

local function handleCopy()
  local activeScene = GAME.navigationStack:getActiveScene()
  if activeScene and activeScene.match and activeScene.match.stacks[1] then
    local stacks = {}
    local match = activeScene.match

    for i = 1, #match.players do
      local player = match.players[i]
      if player.stack.engine.toPuzzleInfo then
        stacks["P" .. i] = player.stack.engine:toPuzzleInfo()
        stacks["P" .. i]["Player"] = player.name
      end
    end

    if tableUtils.length(stacks) > 0 then
      love.system.setClipboardText(json.encode(stacks))
      return true
    end
  end
end

local function handleDumpAttackPattern(playerNumber)
  local activeScene = GAME.navigationStack:getActiveScene()

  if activeScene and activeScene.match then
    local player = activeScene.match.players[playerNumber]

    if player and player.stack then
      local data, state = player.stack:getAttackPatternData()
      FileUtils.writeJson("training", data.extraInfo.dateGenerated .. "_" .. data.extraInfo.playerName .. "_" .. data.extraInfo.gpm .. "gpm.json", data, state)
      return true
    end
  end
end

local function modifyWinCounts(functionIndex)
  if GAME.battleRoom then
    local players = GAME.battleRoom.players
    if players[1] then
      if functionIndex == 1 then -- Add to P1's win count
        players[1].modifiedWins = math.max(0, players[1].modifiedWins + 1)
      end
      if functionIndex == 2 then -- Subtract from P1's win count
        players[1].modifiedWins = math.max(0, players[1].modifiedWins - 1)
      end
    end
    if players[2] then
      if functionIndex == 3 then -- Add to P2's win count
        players[2].modifiedWins = math.max(0, players[2].modifiedWins + 1)
      end
      if functionIndex == 4 then -- Subtract from P2's win count
        players[2].modifiedWins = math.max(0, players[2].modifiedWins - 1)
      end
    end
    if functionIndex == 5 then -- Reset key
      for i = 1, #players do
        players[i].modifiedWins = 0
      end
    end
  end
end

function handleShortcuts()
  if input.allKeys.isDown["f2"] or input.allKeys.isDown["printscreen"] then
    takeScreenshot()
  end

  if DEBUG_ENABLED and input.allKeys.isDown["f5"] then
    refreshDesignHelper()
  end

  if input.isPressed["SystemKey"] then
    runSystemCommands()
  elseif input.isPressed["Ctrl"] then
    if input.allKeys.isDown["c"] then
      handleCopy()
    elseif input.allKeys.isDown["1"] then
      handleDumpAttackPattern(1)
    elseif input.allKeys.isDown["2"] then
      handleDumpAttackPattern(2)
    elseif input.allKeys.isDown["v"] then
      local clipboard = love.system.getClipboardText()
      if clipboard then
        inputFieldManager.textInput(clipboard)
      end
    end
  elseif input.isPressed["Alt"] then
    if input.allKeys.isDown["return"] then
      GAME:toggleFullscreen()
      input.isDown = {}
    elseif input.allKeys.isDown["1"] then
      modifyWinCounts(1)
    elseif input.allKeys.isDown["2"] then
      modifyWinCounts(2)
    elseif input.allKeys.isDown["3"] then
      modifyWinCounts(3)
    elseif input.allKeys.isDown["4"] then
      modifyWinCounts(4)
    elseif input.allKeys.isDown["5"] then
      modifyWinCounts(5)
    end
  end
end

return handleShortcuts
