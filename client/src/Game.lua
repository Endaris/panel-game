require("client.src.localization")
require("common.lib.Queue")
require("client.src.server_queue")
local CharacterLoader = require("client.src.mods.CharacterLoader")
local StageLoader = require("client.src.mods.StageLoader")
local Panels = require("client.src.mods.Panels")
require("client.src.mods.Theme")

-- The main game object for tracking everything in Panel Attack.
-- Not to be confused with "Match" which is the current battle / instance of the game.
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local class = require("common.lib.class")
local logger = require("common.lib.logger")
local analytics = require("client.src.analytics")
local input = require("client.src.inputManager")
local save = require("client.src.save")
local fileUtils = require("client.src.FileUtils")
local handleShortcuts = require("client.src.Shortcuts")
local Player = require("client.src.Player")
local GameModes = require("common.engine.GameModes")
local NetClient = require("client.src.network.NetClient")
local StartUp = require("client.src.scenes.StartUp")
local SoundController = require("client.src.music.SoundController")
require("client.src.BattleRoom")
local prof = require("common.lib.zoneProfiler")
local tableUtils = require("common.lib.tableUtils")
local system = require("client.src.system")

local RichPresence = require("client.lib.rich_presence.RichPresence")

-- Provides a scale that is on .5 boundary to make sure it renders well.
-- Useful for creating new canvas with a solid DPI
local function newCanvasSnappedScale(self)
  local result = math.max(1, math.floor(self.canvasXScale*2)/2)
  return result
end

---@class PanelAttack
---@field netClient NetClient
---@field battleRoom BattleRoom?
---@field globalCanvas love.Canvas
---@field muteSound boolean
---@field rich_presence table
---@field input table
---@field backgroundImage table
---@field backgroundColor number[]
---@field updater table?
---@field automaticScales number[]
---@field config UserConfig
---@field puzzleSets table<string, PuzzleSet>
---@overload fun(): PanelAttack
local Game = class(
  function(self)
    self.scores = require("client.src.scores")
    self.input = input
    self.match = nil -- Match - the current match going on or nil if inbetween games
    self.battleRoom = nil -- BattleRoom - the current room being used for battles
    self.focused = true -- if the window is focused
    self.backgroundImage = nil -- the background image for the game, should always be set to something with the proper dimensions
    self.puzzleSets = {} -- all the puzzles loaded into the game
    self.netClient = NetClient()
    self.server_queue = ServerQueue()
    self.main_menu_screen_pos = {consts.CANVAS_WIDTH / 2 - 108 + 50, consts.CANVAS_HEIGHT / 2 - 111}
    self.config = config
    self.localization = Localization
    self.replay = {}
    self.currently_paused_tracks = {} -- list of tracks currently paused
    self.rich_presence = RichPresence()
    self.rich_presence:initialize("902897593049301004")

    self.muteSound = false
    self.canvasX = 0
    self.canvasY = 0
    self.canvasXScale = 1
    self.canvasYScale = 1
    self.backgroundColor = { 0.0, 0.0, 0.0 }

    -- depends on canvasXScale
    self.globalCanvas = love.graphics.newCanvas(consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT, {dpiscale=newCanvasSnappedScale(self)})

    self.automaticScales = {1, 1.5, 2, 2.5, 3}
    -- specifies a time that is compared against self.timer to determine if GameScale should be shown
    self.showGameScaleUntil = 0
    self.needsAssetReload = false

    self.crashTrace = nil -- set to the trace of your thread before throwing an error if you use a coroutine

    -- private members
    self.pointer_hidden = false
    self.last_x = 0
    self.last_y = 0
    self.input_delta = 0.0

    -- time in seconds, can be used by other elements to track the passing of time beyond dt
    self.timer = love.timer.getTime()
  end
)

Game.newCanvasSnappedScale = newCanvasSnappedScale

function Game:load()
  GAME.puzzleSets = {}
  save.write_puzzles()
  save.read_puzzles("puzzles")

  -- move to constructor
  self.updater = GAME_UPDATER or nil
  if self.updater then
    logger.debug("Launching game with updater")
    local success = pcall(self.updater.init, self.updater)
    if not success then
      logger.debug("updater:init failed")
      self.updater = nil
    end
  else
    logger.debug("Launching game without updater")
  end
  local user_input_conf = save.read_key_file()
  if user_input_conf then
    self.input:importConfigurations(user_input_conf)
  end

  self.navigationStack = require("client.src.NavigationStack")
  self.navigationStack:push(StartUp({setupRoutine = self.setupRoutine}))
  self.globalCanvas = love.graphics.newCanvas(consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT, {dpiscale=GAME:newCanvasSnappedScale()})
end

local function detectHardwareProblems()
  local compatible, problem, reason = system.isCompatible()

  if not compatible then
    ---@cast problem -nil
    ---@cast reason -nil
    love.window.showMessageBox(problem, reason, "warning")
  end
end

function Game:cleanupOldVersions()
  if self.updater then
    local activeReleaseStream = self.updater.activeReleaseStream
    self.updater:getAvailableVersions(activeReleaseStream)
    while self.updater.state ~= GAME_UPDATER_STATES.idle do
      self.updater:update()
      coroutine.yield("Cleaning up old versions")
    end
    if activeReleaseStream.availableVersions and #activeReleaseStream.availableVersions > 0 then
      local toBeCleared = {}
      for _, installedVersionInfo in pairs(activeReleaseStream.installedVersions) do
        if not tableUtils.first(activeReleaseStream.availableVersions, function(availableVersionInfo)
          return availableVersionInfo.version == installedVersionInfo.version
        end) then
          -- double check we're not trying to remove the very file that is mounted right now
          if not string.find(love.filesystem.getRequirePath(), installedVersionInfo.path, 1, true) then
            toBeCleared[#toBeCleared+1] = installedVersionInfo
          end
        end
      end

      for i, versionInfo in ipairs(toBeCleared) do
        pcall(self.updater.removeInstalledVersion, self.updater, versionInfo)
        coroutine.yield("Cleaning up old versions")
      end
    end
  end
end

-- this function writes configuration files to control updater behaviour on the next startup
function Game:writeReleaseStreamDefinition()
  if self.updater then
    local releaseStreamDefinition =
    {
      releaseStreams =
      {
        {
          name = "stable",
          versioningType = "timestamp",
          serverEndPoint = {
            type = "filesystem",
            url = "https://panelattack.com/downloads/updates/stable",
            prefix = "panel-"
          }
        },
        {
          name = "beta",
          versioningType = "timestamp",
          serverEndPoint = {
            type = "filesystem",
            url = "https://panelattack.com/downloads/updates/beta",
            prefix = "panel-beta-"
          }
        },
        {
          name = "engine-preview",
          versioningType = "timestamp",
          serverEndPoint = {
            type = "filesystem",
            url = "https://panelattack.com/downloads/updates/engine-preview",
            prefix = "panel-"
          }
        }
      },
      default = "stable"
    }

    -- this will only start to be active on next startup
    love.filesystem.write("releaseStreams.json", json.encode(releaseStreamDefinition))

    -- this is for the assumption that a release stream is being retired
    -- comment in / out as fit depending on release
    local retiredReleaseNames = {"canary"}

    if tableUtils.contains(retiredReleaseNames, self.updater.activeReleaseStream.name) then
      local launchDefinition =
      {
        activeReleaseStream = releaseStreamDefinition.default
      }
      love.filesystem.write("updater/launch.json", json.encode(launchDefinition))
    end
  end
end

function Game:setupRoutine()
  -- loading various assets into the game
  coroutine.yield("Loading localization...")
  Localization:init()
  self:setLanguage(config.language_code)

  detectHardwareProblems()

  fileUtils.copyFile("docs/puzzles.txt", "puzzles/README.txt")

  coroutine.yield(loc("ld_theme"))
  theme_init()
  self.theme = themes[config.theme]

  -- stages and panels before characters since they are part of their loading!
  coroutine.yield(loc("ld_stages"))
  StageLoader.initStages()

  coroutine.yield(loc("ld_panels"))
  panels_init()

  coroutine.yield(loc("ld_characters"))
  CharacterLoader.initCharacters()

  coroutine.yield(loc("ld_analytics"))
  analytics.init()

  SoundController:applyConfigVolumes()

  self:createDirectoriesIfNeeded()

  self:cleanupOldVersions()
  self:writeReleaseStreamDefinition()

  self:initializeLocalPlayer()
end

-- GAME.localPlayer is the standard player for battleRooms that don't get started from replays/spectate
-- it basically represents the player that is operating the client (and thus binds to its configuration)
function Game:initializeLocalPlayer()
  self.localPlayer = Player.getLocalPlayer()
  self.localPlayer:connectSignal("selectedCharacterIdChanged", config, function(config, newId) config.character = newId end)
  self.localPlayer:connectSignal("selectedStageIdChanged", config, function(config, newId) config.stage = newId end)
  self.localPlayer:connectSignal("panelIdChanged", config, function(config, newId) config.panels = newId end)
  self.localPlayer:connectSignal("inputMethodChanged", config, function(config, inputMethod) config.inputMethod = inputMethod end)
  --self.localPlayer:connectSignal("startingSpeedChanged", config, function(config, speed) config.endless_speed = speed end)
  self.localPlayer:connectSignal("difficultyChanged", config, function(config, difficulty) config.endless_difficulty = difficulty end)
  self.localPlayer:connectSignal("levelChanged", config, function(config, level) config.level = level end)
  self.localPlayer:connectSignal("wantsRankedChanged", config, function(config, wantsRanked) config.ranked = wantsRanked end)
  self.localPlayer:connectSignal("styleChanged", config, function(config, style)
    if style == GameModes.Styles.CLASSIC then
      config.endless_level = nil
    else
      config.endless_level = config.level
    end
  end)
end

function Game:createDirectoriesIfNeeded()
  coroutine.yield("Creating Folders")

  -- create folders in appdata for those who don't have them already
  love.filesystem.createDirectory("characters")
  love.filesystem.createDirectory("panels")
  love.filesystem.createDirectory("themes")
  love.filesystem.createDirectory("stages")
  love.filesystem.createDirectory("training")

  local oldServerDirectory = consts.SERVER_SAVE_DIRECTORY .. consts.LEGACY_SERVER_LOCATION
  local newServerDirectory = consts.SERVER_SAVE_DIRECTORY .. consts.SERVER_LOCATION
  if not love.filesystem.getInfo(newServerDirectory) then
    love.filesystem.createDirectory(newServerDirectory)

    -- Move the old user ID spot to the new folder (we won't delete the old one for backwards compatibility and safety)
    if love.filesystem.getInfo(oldServerDirectory) then
      local userID = save.read_user_id_file(consts.LEGACY_SERVER_LOCATION)
      save.write_user_id_file(userID, consts.SERVER_LOCATION)
    end
  end

  fileUtils.recursiveCopy("client/assets/default_data/training", "training")
  save.readAttackFiles("training")

  if love.system.getOS() ~= "OS X" then
    fileUtils.recursiveRemoveFiles(".", ".DS_Store")
  end
end

function Game:runUnitTests()
  coroutine.yield("Running Unit Tests")

  -- GAME.localPlayer is the standard player for battleRooms that don't get started from replays/spectate
  -- basically the player that is operating the client
  GAME.localPlayer = Player.getLocalPlayer()
  -- we need to overwrite the local player as all replay related tests need a non-local player
  GAME.localPlayer.isLocal = false

  logger.info("Running Unit Tests...")
  GAME.muteSound = true
  --require("client.tests.Tests")
  SoundController:applyConfigVolumes()
end

function Game:runPerformanceTests()
  coroutine.yield("Running Performance Tests")
  require("tests.StackReplayPerformanceTests")
  -- Disabled since they just prove lua tables are faster for rapid concatenation of strings
  --require("tests.StringPerformanceTests")
end

function Game:updateMouseVisibility(dt)
  if love.mouse.getX() == self.last_x and love.mouse.getY() == self.last_y then
    if not self.pointer_hidden then
      if self.input_delta > consts.MOUSE_POINTER_TIMEOUT then
        self.pointer_hidden = true
        love.mouse.setVisible(false)
      else
        self.input_delta = self.input_delta + dt
      end
    end
  else
    self.last_x = love.mouse.getX()
    self.last_y = love.mouse.getY()
    self.input_delta = 0.0
    if self.pointer_hidden then
      self.pointer_hidden = false
      love.mouse.setVisible(true)
    end
  end
end

function Game:handleResize(newWidth, newHeight)
  self:updateCanvasPositionAndScale(newWidth, newHeight)
  if self.battleRoom and self.battleRoom.match then
    self.needsAssetReload = true
  else
    self:refreshCanvasAndImagesForNewScale()
  end
  self.showGameScaleUntil = self.timer + 5
end

-- Called every few fractions of a second to update the game
-- dt is the amount of time in seconds that has passed.
function Game:update(dt)
  self.timer = love.timer.getTime()

  prof.push("battleRoom update")
  if self.battleRoom then
    self.battleRoom:update(dt)
  end
  prof.pop("battleRoom update")
  self.netClient:update()

  handleShortcuts()

  prof.push("navigationStack update")
  self.navigationStack:update(dt)
  prof.pop("navigationStack update")

  if self.backgroundImage then
    self.backgroundImage:update(dt)
  end

  self:updateMouseVisibility(dt)
  SoundController:update()
  self.rich_presence:runCallbacks()
end

function Game:draw()
  -- Setting the canvas means everything we draw is drawn to the canvas instead of the screen
  love.graphics.setCanvas({self.globalCanvas, stencil = true})
  love.graphics.setBackgroundColor(unpack(self.backgroundColor))
  love.graphics.clear()

  -- With this, self.globalCanvas is clear and set as our active canvas everything is being drawn to
  self.navigationStack:draw()

  self:drawFPS()
  self:drawScaleInfo()

  -- resetting the canvas means everything we draw is drawn to the screen
  love.graphics.setCanvas()

  love.graphics.setBlendMode("alpha", "premultiplied")
  -- now we draw the finished canvas at scale
  -- this way we don't have to worry about scaling singular elements, just draw everything at 1280x720 to the canvas
  love.graphics.draw(self.globalCanvas, self.canvasX, self.canvasY, 0, self.canvasXScale, self.canvasYScale, self.globalCanvas:getWidth() / 2, self.globalCanvas:getHeight() / 2)
  love.graphics.setBlendMode("alpha", "alphamultiply")
end

function Game:drawFPS()
  -- Draw the FPS if enabled
  if self.config.show_fps then
    love.graphics.print("FPS: " .. love.timer.getFPS(), 1, 1)
  end
end

function Game:drawScaleInfo()
  if self.showGameScaleUntil > self.timer then
    local scaleString = "Scale: " .. self.canvasXScale .. " (" .. consts.CANVAS_WIDTH * self.canvasXScale .. " x " .. consts.CANVAS_HEIGHT * self.canvasYScale .. ")"
    local newPixelWidth = love.graphics.getWidth()

    if consts.CANVAS_WIDTH * self.canvasXScale > newPixelWidth then
      scaleString = scaleString .. " Clipped "
    end
    love.graphics.printf(scaleString, GraphicsUtil.getGlobalFontWithSize(30), 5, 5, 2000, "left")
  end
end

function Game.errorData(errorString, traceBack)
  local systemInfo = system.getOsInfo()
  local loveVersion = system.loveVersionString()
  local username = config.name or "Unknown"
  local buildVersion
  if GAME.updater then
    buildVersion = GAME.updater.activeReleaseStream.name .. " " .. GAME.updater.activeVersion.version
  else
    buildVersion = "Unknown"
  end

  local name, version, vendor, device = love.graphics.getRendererInfo()
  local rendererInfo = name .. ";" .. version .. ";" .. vendor .. ";" .. device

  local errorData = {
      stack = traceBack,
      name = username,
      error = errorString,
      engine_version = consts.ENGINE_VERSION,
      release_version = buildVersion,
      operating_system = systemInfo,
      love_version = loveVersion,
      rendererInfo = rendererInfo,
      theme = config.theme
    }

  -- if GAME.battleRoom then
  --   errorData.battleRoomInfo = GAME.battleRoom:getInfo()
  -- end
  -- if GAME.navigationStack and GAME.navigationStack.scenes
  --     and #GAME.navigationStack.scenes > 0
  --     and GAME.navigationStack.scenes[#GAME.navigationStack.scenes].match then
  --   errorData.matchInfo = GAME.navigationStack.scenes[#GAME.navigationStack.scenes].match:getInfo()
  -- end

  return errorData
end

function Game.detailedErrorLogString(errorData)
  local newLine = "\n"
  local now = os.date("*t", to_UTC(os.time()))
  local formattedTime = string.format("%04d-%02d-%02d %02d:%02d:%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)

  local detailedErrorLogString = 
    "Stack Trace: " .. errorData.stack .. newLine ..
    "Username: " .. errorData.name .. newLine ..
    "Theme: " .. errorData.theme .. newLine ..
    "Error Message: " .. errorData.error .. newLine ..
    "Engine Version: " .. errorData.engine_version .. newLine ..
    "Build Version: " .. errorData.release_version .. newLine ..
    "Operating System: " .. errorData.operating_system .. newLine ..
    "Love Version: " .. errorData.love_version .. newLine ..
    "Renderer Info: " .. errorData.rendererInfo .. newLine ..
    "UTC Time: " .. formattedTime .. newLine ..
    "Scene: " .. (GAME.navigationStack.scenes[#GAME.navigationStack.scenes].name or "") .. newLine

    if errorData.matchInfo and not errorData.matchInfo.ended then
      detailedErrorLogString = detailedErrorLogString .. newLine ..
      "Match Info: " .. newLine ..
      "  Stage: " .. errorData.matchInfo.stage .. newLine ..
      "  Stack Interaction: " .. errorData.matchInfo.stackInteraction
      if errorData.matchInfo.timeLimit then
        detailedErrorLogString = detailedErrorLogString .. newLine ..
        "  Time Limit: " .. errorData.matchInfo.timeLimit
      end
      if errorData.matchInfo.doCountdown then
        detailedErrorLogString = detailedErrorLogString .. newLine ..
        "  Do Countdown: " .. tostring(errorData.matchInfo.doCountdown)
      end
      detailedErrorLogString = detailedErrorLogString .. newLine ..
      "  Stacks: "
      for i = 1, #errorData.matchInfo.stacks do
        local stack = errorData.matchInfo.stacks[i]
        detailedErrorLogString = detailedErrorLogString .. newLine ..
        "    P" .. i .. ": " .. newLine ..
        "      Player Number: " .. stack.playerNumber .. newLine ..
        "      Character: " .. stack.character .. newLine ..
        "      InputMethod: " .. stack.inputMethod .. newLine ..
        "      Rollback Count: " .. stack.rollbackCount .. newLine ..
        "      Rollback Frames Saved: " .. stack.rollbackCopyCount
      end
    elseif errorData.battleRoomInfo then
      detailedErrorLogString = detailedErrorLogString .. newLine ..
      "BattleRoom Info: " .. newLine ..
      "  Online: " .. errorData.battleRoomInfo.online .. newLine ..
      "  Spectating: " .. errorData.battleRoomInfo.spectating .. newLine ..
      "  All assets loaded: " .. errorData.battleRoomInfo.allAssetsLoaded .. newLine ..
      "  State: " .. errorData.battleRoomInfo.state .. newLine ..
      "  Players: "
      for i = 1, #errorData.battleRoomInfo.players do
        local player = errorData.battleRoomInfo.players[i]
        detailedErrorLogString = detailedErrorLogString .. newLine ..
        "    P" .. i .. ": " .. newLine ..
        "      Player Number: " .. player.playerNumber .. newLine ..
        "      Panels: " .. player.panelId  .. newLine ..
        "      Selected Character: " .. player.selectedCharacterId .. newLine ..
        "      Character: " .. player.characterId  .. newLine ..
        "      Selected Stage: " .. player.selectedStageId .. newLine ..
        "      Stage: " .. player.stageId .. newLine ..
        "      isLocal: " .. player.isLocal .. newLine ..
        "      wantsReady: " .. player.wantsReady
      end
    end

  return detailedErrorLogString
end

function Game:toggleFullscreen()
  local fullscreen = love.window.getFullscreen()
  love.window.setFullscreen(not fullscreen, "desktop")
  fullscreen = not fullscreen
  if not fullscreen and config.maximizeOnStartup and not love.window.isMaximized() then
    logger.debug("calling maximize via fullscreen toggle")
    love.window.maximize()
  end
  logger.debug("updating canvas scale from fullscreen toggle, toggling to " .. tostring(fullscreen))
  local newWidth, newHeight = love.graphics.getDimensions()
  self:updateCanvasPositionAndScale(newWidth, newHeight)
end

-- Updates the scale and position values to use up the right size of the window based on the user's settings.
function Game:updateCanvasPositionAndScale(newWindowWidth, newWindowHeight)
  logger.debug("Updating canvas scale with args " .. newWindowWidth .. "," .. newWindowHeight)

  -- we want to draw at integer coordinates to prevent weird interpolation
  if newWindowWidth % 2 > 0 then
    newWindowWidth = newWindowWidth - 1
  end

  if newWindowHeight % 2 > 0 then
    newWindowHeight = newWindowHeight - 1
  end

  -- the global canvas is drawn with centered origin so just by placing it in the middle of the screen will do the job fine, always
  self.canvasX = math.floor(newWindowWidth / 2)
  self.canvasY = math.floor(newWindowHeight / 2)

  if config.gameScaleType == "fit" then
    local w, h
    local canvasWidth, canvasHeight = self.globalCanvas:getDimensions()
    if newWindowHeight / canvasHeight > newWindowWidth / canvasWidth then
      w = newWindowWidth
      h = canvasHeight * newWindowWidth / canvasWidth
    else
      w = canvasWidth * newWindowHeight / canvasHeight
      h = newWindowHeight
    end
    self.canvasXScale = w / canvasWidth
    self.canvasYScale = h / canvasHeight
  elseif config.gameScaleType == "fixed" then
    self.canvasXScale = config.gameScaleFixedValue
    self.canvasYScale = config.gameScaleFixedValue
  elseif config.gameScaleType == "auto" then
    local availableScales = shallowcpy(self.automaticScales)
    -- use a default minimum for automatic if the window gets too small
    local newScale = 0.5
    for i= #availableScales, 1, -1 do
      local scale = availableScales[i]
      if (newWindowWidth >= self.globalCanvas:getWidth() * scale and newWindowHeight >= self.globalCanvas:getHeight() * scale) then
        newScale = scale
        break
      end
    end

    self.canvasXScale = newScale
    self.canvasYScale = newScale
  end
end

-- Reloads the canvas and all images / fonts for the new game scale
function Game:refreshCanvasAndImagesForNewScale()
  if themes == nil or themes[config.theme] == nil then
    return -- EARLY RETURN, assets haven't loaded the first time yet
    -- they will load through the normal process
  end

  self:drawLoadingString(loc("ld_characters"))
  coroutine.yield()

  self.globalCanvas = love.graphics.newCanvas(GAME.globalCanvas:getWidth(), GAME.globalCanvas:getHeight(), {dpiscale=self:newCanvasSnappedScale()})
  -- We need to reload all assets and fonts to get the new scaling info and filters

  -- Reload theme to get the new resolution assets
  themes[config.theme]:graphics_init(true)
  themes[config.theme]:final_init()
  -- Reload stages to get the new resolution assets
  stages_reload_graphics()
  -- Reload panels to get the new resolution assets
  panels_init()
  -- Reload characters to get the new resolution assets
  characters_reload_graphics()

  -- Reload loc to get the new font
  self:setLanguage(config.language_code)
end

-- Transform from window coordinates to game coordinates
function Game:transform_coordinates(x, y)
  local newX, newY = (x - self.canvasX) / self.canvasXScale + self.globalCanvas:getWidth() / 2, (y - self.canvasY) / self.canvasYScale + self.globalCanvas:getHeight() / 2
  return newX, newY
end


function Game:drawLoadingString(loadingString) 
  local textMaxWidth = 300
  local textHeight = 40
  local x = 0
  local y = consts.CANVAS_HEIGHT/2 - textHeight/2
  local backgroundPadding = 10
  GraphicsUtil.drawRectangle("fill", consts.CANVAS_WIDTH / 2 - (textMaxWidth / 2) , y - backgroundPadding, textMaxWidth, textHeight, 0, 0, 0, 0.5)
  GraphicsUtil.printf(loadingString, x, y, consts.CANVAS_WIDTH, "center", nil, nil, 10)
end

function Game:setLanguage(lang_code)
  for i, v in ipairs(Localization.codes) do
    if v == lang_code then
      Localization.lang_index = i
      break
    end
  end
  config.language_code = Localization.codes[Localization.lang_index]

  if themes[config.theme] and themes[config.theme].font and themes[config.theme].font.path then
    GraphicsUtil.setGlobalFont(themes[config.theme].font.path, themes[config.theme].font.size, self:newCanvasSnappedScale())
  elseif config.language_code == "JP" then
    GraphicsUtil.setGlobalFont("client/assets/fonts/jp.ttf", 14, self:newCanvasSnappedScale())
  elseif config.language_code == "TH" then
    GraphicsUtil.setGlobalFont("client/assets/fonts/th.otf", 14, self:newCanvasSnappedScale())
  else
    GraphicsUtil.setGlobalFont(nil, 12, self:newCanvasSnappedScale())
  end

  Localization:refresh_global_strings()
end

return Game
