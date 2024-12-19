local logger = require("common.lib.logger")
require("common.lib.mathExtensions")
local utf8 = require("common.lib.utf8Additions")
local inputManager = require("common.lib.inputManager")
require("client.src.globals")
local touchHandler = require("client.src.ui.touchHandler")
local inputFieldManager = require("client.src.ui.inputFieldManager")
local CustomRun = require("client.src.CustomRun")
require("common.lib.util")

local Game = require("client.src.Game")
-- move to load once global dependencies have been resolved
GAME = Game()

-- We override love.run with a function that refers to `runInternal` for its gameloop function
-- so by overwriting that, the new runInternal will get used on the next iteration
love.runInternal = CustomRun.innerRun

function love.run()
  return CustomRun.run()
end

-- Called at the beginning to load the game
-- Either called directly or from auto_updater
function love.load(args, rawArgs)
  love.keyboard.setTextInput(false)

  -- there is a bug on windows that causes the game to start with a size equal to the desktop causing the window handle to be offscreen
  -- check for that and restore the window if that's the case:
  local x, y, displayIndex = love.window.getPosition()
  local desktopWidth, desktopHeight = love.window.getDesktopDimensions(displayIndex)
  local w, windowHeight, flags = love.window.getMode()

  if not flags.fullscreen and not flags.borderless and love.system.getOS() ~= "Android" then
    if y == 0 and windowHeight >= desktopHeight then
      if love.window.isMaximized() then
        love.window.restore()
      end
      local offset = math.ceil(desktopHeight / 32)
      love.window.updateMode(desktopWidth, desktopHeight - offset, flags)
      love.window.setPosition(x, offset, displayIndex)
    end

    if config.maximizeOnStartup and not love.window.isMaximized() then
      love.window.maximize()
    end
  end

  local newPixelWidth, newPixelHeight = love.graphics.getWidth(), love.graphics.getHeight()
  GAME:updateCanvasPositionAndScale(newPixelWidth, newPixelHeight)

  GAME:load()
end

function love.focus(f)
  GAME.focused = f
end

-- Called every few fractions of a second to update the game
-- dt is the amount of time in seconds that has passed.
function love.update(dt)
  -- if config.show_fps and config.debug_mode then
  --   if CustomRun.runTimeGraph == nil then
  --     CustomRun.runTimeGraph = RunTimeGraph()
  --   end
  -- else
  --   CustomRun.runTimeGraph = nil
  -- end

  -- inputManager:update(dt)
  -- inputFieldManager.update()
  -- touchHandler:update(dt)

  GAME:update(dt)
end

-- Called whenever the game needs to draw.
function love.draw()
  GAME:draw()
end

-- Handle a mouse or touch press
function love.mousepressed(x, y, button)
  touchHandler:touch(x, y)
  inputManager:mousePressed(x, y, button)
end

function love.mousereleased(x, y, button)
  if button == 1 then
    touchHandler:release(x, y)
    inputManager:mouseReleased(x, y, button)
  end
end

function love.mousemoved( x, y, dx, dy, istouch )
  if love.mouse.isDown(1) then
    touchHandler:drag(x, y)
  end
  inputManager:mouseMoved(x, y)
end

function love.joystickpressed(joystick, button)
  inputManager:joystickPressed(joystick, button)
end

function love.joystickreleased(joystick, button)
  inputManager:joystickReleased(joystick, button)
end

-- Handle a touch press
-- Note we are specifically not implementing this because mousepressed above handles mouse and touch
-- function love.touchpressed(id, x, y, dx, dy, pressure)
-- local _x, _y = GAME:transform_coordinates(x, y)
-- click_or_tap(_x, _y, {id = id, x = _x, y = _y, dx = dx, dy = dy, pressure = pressure})
-- end

-- quit handling
function love.quit()
  love.audio.stop()
  config.fullscreen = love.window.getFullscreen()
  local x, y, displayIndex = love.window.getPosition()
  config.displayIndex = displayIndex
  if config.fullscreen then
    _, _, config.display = love.window.getPosition()
    config.fullscreen = true
    -- don't save the other values so the settings from previous windowed mode usage are preserved
  else
    config.windowX = math.max(x, 0)
    config.windowY = math.max(y, 0)
    if config.windowY == 0 then
      --don't let 'y' be zero, or the title bar will not be visible on next launch.
      config.windowY = 30
    end
    config.windowWidth, config.windowHeight, _ = love.window.getMode()
    config.maximizeOnStartup = love.window.isMaximized()
  end

  write_conf_file()
  pcall(love.filesystem.write, "debug.log", table.concat(logger.messages, "\n"))
end

function love.resize(newWidth, newHeight)
  if GAME then
    GAME:handleResize(newWidth, newHeight)
  end
end

function love.keypressed(key, scancode, rep)
  logger.trace("key pressed: " .. key)
  if scancode then
    inputManager:keyPressed(key, scancode, rep)
  end
end

function love.textinput(text)
  inputFieldManager.textInput(text)
end

function love.keyreleased(key, unicode)
  inputManager:keyReleased(key, unicode)
end

function love.joystickaxis(joystick, axisIndex, value)
  inputManager:joystickaxis(joystick, axisIndex, value)
end