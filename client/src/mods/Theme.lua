local consts = require("common.engine.consts")
local class = require("common.lib.class")
local logger = require("common.lib.logger")
local fileUtils = require("client.src.FileUtils")
local levelPresets = require("common.data.LevelPresets")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local ImageContainer = require("client.src.ui.ImageContainer")
local Music = require("client.src.music.Music")
local tableUtils = require("common.lib.tableUtils")
local SoundController = require("client.src.music.SoundController")
local UpdatingImage = require("client.src.graphics.UpdatingImage")

local MAX_SUPPORTED_PLAYERS = 2

-- from https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
local flags = {
  "cn", -- China
  "de", -- Germany
  "es", -- Spain
  "fr", -- France
  "gb", -- United Kingdom of Great Britain and Northern Ireland
  "in", -- India
  "it", -- Italy
  "jp", -- Japan
  "pt", -- Portugal
  "us" -- United States of America
}

-- Represents the current styles and images to apply to the game UI
---@class Theme
---@field path string
---@field name string
---@field version ThemeVersion
---@field images table
---@field fontMaps table<string, PixelFontMap | PixelFontMap[]>
---@field sounds table<string, (love.Source | table | nil)>
---@field musics table<string, Music>
---@field font table
---@field main_menu_screen_pos number[]
---@field main_menu_y_max number
---@field main_menu_max_height number
---@field defaultStage Stage
Theme =
  class(
---@param self Theme
  function(self, fullPath, foldername)
    self.path = fullPath
    self.name = foldername
    self.version = Theme.THEME_VERSIONS.original
    self.images = {} -- theme images
    self.fontMaps = {}
    self.sounds = {} -- theme sfx
    self.musics = {} -- theme music
    self.font = {} -- font
    self.font.size = 12

    self.main_menu_screen_pos = {0, 0} -- the top center position of most menus
    self.main_menu_y_max = 0
    self.main_menu_max_height = 0
  end
)

---@enum ThemeVersion
Theme.THEME_VERSIONS = { original = 1, two = 2, fixedOffsets = 3, current = 3}

Theme.TYPE = "theme"
-- name of the top level save directory for mods of this type
Theme.SAVE_DIR = "themes"

-- Returns a list of keys and their type allowed in theme config files
function Theme:configurableKeys() 
  local result = {}

  result["version"] = "number"
  result["matchtypeLabel_Pos"] = "table"
  result["matchtypeLabel_Scale"] = "number"
  result["timeLabel_Pos"] = "table"
  result["timeLabel_Scale"] = "number"
  result["time_Pos"] = "table"
  result["time_Scale"] = "number"
  result["moveLabel_Pos"] = "table"
  result["moveLabel_Scale"] = "number"
  result["move_Pos"] = "table"
  result["move_Scale"] = "number"
  result["scoreLabel_Pos"] = "table"
  result["scoreLabel_Scale"] = "number"
  result["score_Pos"] = "table"
  result["score_Scale"] = "number"
  result["speedLabel_Pos"] = "table"
  result["speedLabel_Scale"] = "number"
  result["speed_Pos"] = "table"
  result["speed_Scale"] = "number"
  result["levelLabel_Pos"] = "table"
  result["levelLabel_Scale"] = "number"
  result["level_Pos"] = "table"
  result["level_Scale"] = "number"
  result["winLabel_Pos"] = "table"
  result["winLabel_Scale"] = "number"
  result["win_Pos"] = "table"
  result["win_Scale"] = "number"
  result["name_Pos"] = "table"
  result["name_Font_Size"] = "number"
  result["ratingLabel_Pos"] = "table"
  result["ratingLabel_Scale"] = "number"
  result["rating_Pos"] = "table"
  result["rating_Scale"] = "number"
  result["spectators_Pos"] = "table"
  result["healthbar_frame_Pos"] = "table"
  result["healthbar_frame_Scale"] = "number"
  result["healthbar_Pos"] = "table"
  result["healthbar_Scale"] = "number"
  result["healthbar_Rotate"] = "number"
  result["multibar_Pos"] = "table"
  result["multibar_Scale"] = "number"
  result["multibar_is_absolute"] = "boolean"
  result["multibar_LeftoverTime_Pos"] = "table"
  result["multibar_LeftoverTime_Decimals"] = "number"
  result["font_size"] = "number"
  result["bg_title_speed_x"] = "number"
  result["bg_title_speed_y"] = "number"
  result["bg_main_speed_x"] = "number"
  result["bg_main_speed_y"] = "number"
  result["bg_select_screen_speed_x"] = "number"
  result["bg_select_screen_speed_y"] = "number"
  result["bg_readme_speed_x"] = "number"
  result["bg_readme_speed_y"] = "number"
  result["bg_title_is_tiled"] = "boolean"
  result["bg_main_is_tiled"] = "boolean"
  result["bg_select_screen_is_tiled"] = "boolean"
  result["bg_readme_is_tiled"] = "boolean"
  result["gameover_text_Pos"] = "table"

  return result
end

function Theme:loadVersion1DefaultValues()
  -- Version 1 values
  -- All of the default values below are legacy "version 1" values, the modern values are are loaded from the default theme config file
  -- Old themes inherit these values if they do not specify a version.
  self.matchtypeLabel_Pos = {-40, -30} -- the position of the "match type" label
  self.matchtypeLabel_Scale = 3 -- the scale size of the "match type" lavel
  self.timeLabel_Pos = {-4, 2} -- the position of the timer label
  self.timeLabel_Scale = 2 -- the scale size of the timer label
  self.time_Pos = {26, 26} -- the position of the timer
  self.time_Scale = 2 -- the scale size of the timer
  self.name_Pos = {20, -30} -- the position of the name
  self.name_Font_Size = 12 -- the font size of the name
  self.moveLabel_Pos = {468, 170} -- the position of the move label
  self.moveLabel_Scale = 2 -- the scale size of the move label
  self.move_Pos = {40, 34} -- the position of the move
  self.move_Scale = 1 -- the scale size of the move
  self.scoreLabel_Pos = {104, 25} -- the position of the score label
  self.scoreLabel_Scale = 2 -- the scale size of the score label
  self.score_Pos = {116, 32} -- the position of the score
  self.score_Scale = 1.5 -- the scale size of the score
  self.speedLabel_Pos = {106, 42} -- the position of the speed label
  self.speedLabel_Scale = 2 -- the scale size of the speed label
  self.speed_Pos = {116, 48} -- the position of the speed
  self.speed_Scale = 1.35 -- the scale size of the speed
  self.levelLabel_Pos = {104, 58} -- the position of the level label
  self.levelLabel_Scale = 2 -- the scale size of the level label
  self.level_Pos = {112, 66} -- the position of the level
  self.level_Scale = 1 -- the scale size of the level
  self.winLabel_Pos = {10, 190} -- the position of the win label
  self.winLabel_Scale = 2 -- the scale size of the win label
  self.win_Pos = {40, 220} -- the position of the win counter
  self.win_Scale = 2 -- the scale size of the win counter
  self.ratingLabel_Pos = {5, 140} -- the position of the rating label
  self.ratingLabel_Scale = 2 -- the scale size of the rating label
  self.rating_Pos = {38, 160} -- the position of the rating value
  self.rating_Scale = 1 -- the scale size of the rating value
  self.spectators_Pos = {547, 460} -- the position of the spectator list
  self.healthbar_frame_Pos = {-17, -4} -- the position of the healthbar frame
  self.healthbar_frame_Scale = 3 -- the scale size of the healthbar frame
  self.healthbar_Pos = {-13, 148} -- the position of the healthbar
  self.healthbar_Scale = 1 -- the scale size of the healthbar
  self.healthbar_Rotate = 0 -- the rotation of the healthbar
  self.multibar_Pos = {-13, 96} -- the position of the multibar
  self.multibar_Scale = 1 -- the scale size of the multibar
  self.multibar_is_absolute = false -- if the multibar should render in absolute scale
  self.bg_title_is_tiled = false -- if the image should tile (default is stretch)
  self.bg_title_speed_x = 0 -- speed the various backgrounds move at
  self.bg_title_speed_y = 0
  self.bg_main_is_tiled = false -- if the image should tile (default is stretch)
  self.bg_main_speed_x = 0
  self.bg_main_speed_y = 0
  self.bg_select_screen_is_tiled = false -- if the image should tile (default is stretch)
  self.bg_select_screen_speed_x = 0
  self.bg_select_screen_speed_y = 0
  self.bg_readme_is_tiled = false -- if the image should tile (default is stretch)
  self.bg_readme_speed_x = 0
  self.bg_readme_speed_y = 0
end

function Theme:loadVersion2DefaultValues()
  -- Version 2 values
  -- All of the default values below are legacy "version 2" values, the modern values are are loaded from the default theme config file
  self.timeLabel_Pos = {-4, 2} -- the position of the timer label
  self.time_Pos = {26, 26} -- the position of the timer
  self.name_Pos = {20, -30} -- the position of the name
  self.name_Font_Size = 12 -- the font size of the name
  self.scoreLabel_Pos = {104, 25} -- the position of the score label
  self.score_Pos = {116, 34} -- the position of the score
  self.speedLabel_Pos = {104, 42} -- the position of the speed label
  self.speed_Pos = {116, 50} -- the position of the speed
  self.levelLabel_Scale = 1 -- the scale size of the level label
  self.levelLabel_Pos = {105, 58} -- the position of the level label
  self.level_Pos = {112, 66} -- the position of the level
  self.level_Scale = 1 -- the scale size of the level
  self.ratingLabel_Pos = {0, 140} -- the position of the rating label
  self.rating_Pos = {38, 162} -- the position of the rating value
  self.spectators_Pos = {547, 460} -- the position of the spectator list
  self.winLabel_Pos = {10, 190} -- the position of the win label
  self.win_Pos = {40, 212} -- the position of the win counter
  self.moveLabel_Scale = 1 -- the scale size of the move label
  self.moveLabel_Pos = {468, 170} -- the position of the move label
  self.move_Scale = 1 -- the scale size of the move
  self.move_Pos = {40, 34} -- the position of the move
  self.healthbar_frame_Pos = {-17, -4} -- the position of the healthbar frame
end

function Theme:loadVersion3DefaultValues()
    self.version = 3
    self.matchtypeLabel_Scale = 1
    self.matchtypeLabel_Pos = {640, 60}
    self.timeLabel_Scale = 1
    self.timeLabel_Pos = {640, -126}
    self.time_Scale = 0.70
    self.time_Pos = {640, 8}
    self.spectators_Pos = {546, 460}
    self.name_Pos = {184, -108}
    self.name_Font_Size = 20
    self.levelLabel_Scale = 1
    self.levelLabel_Pos = {318, 0}
    self.level_Scale = 1
    self.level_Pos = {340, 24}
    self.moveLabel_Scale = 1
    self.moveLabel_Pos = {312, 60}
    self.move_Scale = 1
    self.move_Pos = {354, 86}
    self.scoreLabel_Scale = 1
    self.scoreLabel_Pos = {316, 64}
    self.score_Scale = 0.5
    self.score_Pos = {352, 88}
    self.speedLabel_Scale = 1
    self.speedLabel_Pos = {316, 122}
    self.speed_Scale = 0.5
    self.speed_Pos = {352, 146}
    self.ratingLabel_Scale = 1
    self.ratingLabel_Pos = {310, 180}
    self.rating_Scale = 0.5
    self.rating_Pos = {354, 206}
    self.winLabel_Scale = 1
    self.winLabel_Pos = {318, -246}
    self.win_Scale = 0.75
    self.win_Pos = {260, -112}
    self.gameover_text_Pos = {640, 60}
    self.healthbar_frame_Pos = {-51, -12}
    self.healthbar_frame_Scale = 1
    self.healthbar_Pos = {-39, 68}
    self.healthbar_Scale = 0.33
    self.healthbar_Rotate = 0
    self.multibar_Pos = {-12, 589} -- edit to {-39, 288} for relative multibar
    self.multibar_Scale = 1
    self.multibar_LeftoverTime_Pos = {-19, 5}
    self.multibar_LeftoverTime_Decimals = 0
    self.multibar_is_absolute = true
    self.bg_title_is_tiled = false
    self.bg_title_speed_x = 0
    self.bg_title_speed_y = 0
    self.bg_main_is_tiled = false
    self.bg_main_speed_x = 0
    self.bg_main_speed_y = 0
    self.bg_select_screen_is_tiled = false
    self.bg_select_screen_speed_x = 0
    self.bg_select_screen_speed_y = 0
    self.bg_readme_is_tiled = false
    self.bg_readme_speed_x = 0
    self.bg_readme_speed_y = 0
end

function Theme:loadDefaultConfig()
  self:loadVersion3DefaultValues()
end

Theme.themeDirectoryPath = THEME_DIRECTORY_PATH or "themes/"
Theme.defaultThemeDirectoryPath = "client/assets/themes/" .. consts.DEFAULT_THEME_DIRECTORY

-- loads the image of the given name
---@param name string
---@param useBackup boolean?
---@return love.Texture
function Theme:load_theme_img(name, useBackup)
  if useBackup == nil then
    useBackup = true
  end
  local img = GraphicsUtil.loadImageFromSupportedExtensions(self.path .. "/" .. name)
  if not img and useBackup then
    img = GraphicsUtil.loadImageFromSupportedExtensions(Theme.defaultThemeDirectoryPath .. "/".. name)
    ---@cast img -nil # this is not strictly true but the default should always be able to provide a backup
  end
  return img
end

function Theme:loadFont()
  for key, value in pairs(fileUtils.getFilteredDirectoryItems(self.path)) do
    if value:lower():match(".*%.ttf") or value:lower():match(".*%.otf") then -- Any .ttf file
      self.font.path = self.path .. "/" .. value
      break
    end
  end

end

function Theme:loadMenuGraphics()
  self.images.bg_main = UpdatingImage(self:load_theme_img("background/main"), self.bg_main_is_tiled, self.bg_main_speed_x, self.bg_main_speed_y, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)

  self:loadFont()

  local titleImage = self:load_theme_img("background/title", false)
  if titleImage then
    self.images.bg_title = UpdatingImage(titleImage, self.bg_title_is_tiled, self.bg_title_speed_x, self.bg_title_speed_y, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)
  end

  self.images.bg_select_screen = UpdatingImage(self:load_theme_img("background/select_screen"), self.bg_select_screen_is_tiled, self.bg_select_screen_speed_x, self.bg_select_screen_speed_y, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)
  self.images.bg_readme = UpdatingImage(self:load_theme_img("background/readme"), self.bg_readme_is_tiled, self.bg_readme_speed_x, self.bg_readme_speed_y, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)
  self.images.IMG_bug = self:load_theme_img("bug")
end

---@param theme Theme
---@return table<integer, love.Texture[]>
local function loadGridCursors(theme)
  local gridCursors = {}
  theme.images.IMG_char_sel_cursors = {}
  for playerNumber = 1, MAX_SUPPORTED_PLAYERS do
    gridCursors[playerNumber] = {}
    for position_num = 1, 2 do
      gridCursors[playerNumber][position_num] = theme:load_theme_img("p" .. playerNumber .. "_select_screen_cursor" .. position_num)
    end
  end

  theme.images.IMG_char_sel_cursors = gridCursors

  return theme.images.IMG_char_sel_cursors
end

---@return love.Texture[]
local function loadPlayerNumberIcons(theme)
  local icons = {}
  for playerNumber = 1, MAX_SUPPORTED_PLAYERS do
    icons[playerNumber] = theme:load_theme_img("p" .. playerNumber)
  end

  theme.images.IMG_players = icons

  return theme.images.IMG_players
end

function Theme:loadSelectionGraphics()
  self.images.flags = {}
  for _, flag in ipairs(flags) do
    self.images.flags[flag] = self:load_theme_img("flags/" .. flag)
  end

  self.images.IMG_level_cursor = self:load_theme_img("level/level_cursor")
  self.images.IMG_levels = {}
  self.images.IMG_levels_unfocus = {}
  self.images.IMG_levels[1] = self:load_theme_img("level/level1")
  self.images.IMG_levels_unfocus[1] = nil -- meaningless by design
  for i = 2, levelPresets.modernPresetCount do --which should equal the number of levels in the game
    self.images.IMG_levels[i] = self:load_theme_img("level/level" .. i .. "")
    self.images.IMG_levels_unfocus[i] = self:load_theme_img("level/level" .. i .. "unfocus")
  end

  self.images.IMG_ready = self:load_theme_img("ready")
  self.images.IMG_loading = self:load_theme_img("loading")
  self.images.IMG_super = self:load_theme_img("super")
  self.images.IMG_numbers = {}
  for i = 1, 3 do
    self.images.IMG_numbers[i] = self:load_theme_img(i .. "")
  end

  local pixelFontCharacters = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ&?!%*."
  local pixelFontBlueAtlas = self:load_theme_img("pixel_font_blue")

  self.fontMaps.pixelFontBlue = GraphicsUtil.createPixelFontMap(pixelFontCharacters, pixelFontBlueAtlas)

  self.images.IMG_random_stage = self:load_theme_img("random_stage")
  self.images.IMG_random_character = self:load_theme_img("random_character")

  loadPlayerNumberIcons(self)
  loadGridCursors(self)
end

function Theme:loadIngameGraphics()
  local bgOverlay = self:load_theme_img("background/bg_overlay")
  local fgOverlay = self:load_theme_img("background/fg_overlay")
  if bgOverlay then
    self.images.bg_overlay = ImageContainer({
      image = bgOverlay,
      hAlign = "center",
      vAlign = "center",
      width = consts.CANVAS_WIDTH,
      height = consts.CANVAS_HEIGHT
    })
  end

  if fgOverlay then
    self.images.fg_overlay = ImageContainer({
      image = fgOverlay,
      hAlign = "center",
      vAlign = "center",
      width = consts.CANVAS_WIDTH,
      height = consts.CANVAS_HEIGHT
    })
  end

  self.images.pause = self:load_theme_img("pause")

  --play field frames, plus the wall at the bottom.
  self.images.frames = {}
  self.images.walls = {}
  for i = 1, MAX_SUPPORTED_PLAYERS do
    self.images.frames[i] = self:load_theme_img("frame/frame" .. i .. "P")
    self.images.walls[i] = self:load_theme_img("frame/wall" .. i .. "P")
  end

  self:loadIngameLabels()
  self:loadMultibar()
  self:loadAnalyticsIcons()
  self:loadCards()
  self:loadGameCursor()
end

function Theme:loadIngameLabels()
  local timeAtlasCharacters = "0123456789:'"
  local timeAtlas = self:load_theme_img("time_numbers")
  self.fontMaps.time = GraphicsUtil.createPixelFontMap(timeAtlasCharacters, timeAtlas)

  local numberAtlasCharacters = "0123456789"
  self.fontMaps.numbers = {}
  self.images.speedLabels = {}
  self.images.levelLabels = {}
  self.images.scoreLabels = {}
  self.images.ratingLabels = {}
  for i = 1, MAX_SUPPORTED_PLAYERS do
    self.images.speedLabels[i] = self:load_theme_img("speed_" .. i .. "P")
    self.images.levelLabels[i] = self:load_theme_img("level_" .. i .. "P")
    self.images.scoreLabels[i] = self:load_theme_img("score_" .. i .. "P")
    self.images.ratingLabels[i] = self:load_theme_img("rating_" .. i .. "P")
    local numberAtlas = self:load_theme_img("numbers_" .. i .. "P")
    self.fontMaps.numbers[i] = GraphicsUtil.createPixelFontMap(numberAtlasCharacters, numberAtlas)
  end

  self.images.IMG_time = self:load_theme_img("time")
  self.images.IMG_moves = self:load_theme_img("moves")
  self.images.IMG_wins = self:load_theme_img("wins")

  self.images.IMG_casual = self:load_theme_img("casual")
  self.images.IMG_ranked = self:load_theme_img("ranked")

  self:loadLevelNumberAtlasses()
end

function Theme:loadMultibar()
  self.images.healthbarFrames = {}
  self.images.healthbarFrames.relative = {}
  self.images.healthbarFrames.absolute = {}
  for i = 1, MAX_SUPPORTED_PLAYERS do
    self.images.healthbarFrames.relative[i]  = self:load_theme_img("healthbar_frame_" .. i .. "P")
    self.images.healthbarFrames.absolute[i] = self:load_theme_img("healthbar_frame_" .. i .. "P_absolute")
  end

  self.images.IMG_healthbar = self:load_theme_img("healthbar")

  self.images.IMG_multibar_frame = self:load_theme_img("multibar_frame")
  self.images.IMG_multibar_prestop_bar = self:load_theme_img("multibar_prestop_bar")
  self.images.IMG_multibar_stop_bar = self:load_theme_img("multibar_stop_bar")
  self.images.IMG_multibar_shake_bar = self:load_theme_img("multibar_shake_bar")
end

function Theme:loadAnalyticsIcons()
  self.images.IMG_swap = self:load_theme_img("swap")
  self.images.IMG_apm = self:load_theme_img("apm")
  self.images.IMG_gpm = self:load_theme_img("GPM")
  self.images.IMG_cursorCount = self:load_theme_img("CursorCount")
end

function Theme:loadCards()
  self.images.IMG_cards = {}
  self.images.IMG_cards[true] = {}
  self.images.IMG_cards[false] = {}
  for i = 4, 72 do
    self.images.IMG_cards[false][i] = self:load_theme_img("combo/combo" .. tostring(math.floor(i / 10)) .. tostring(i % 10) .. "")
  end
  -- mystery chain
  self.images.IMG_cards[true][0] = self:load_theme_img("chain/chain00")
  -- mystery combo
  self.images.IMG_cards[false][0] = self:load_theme_img("combo/combo00")

  -- Chain card loading
  -- load as many chain cards as there are available until 99
  -- we assume if the theme provided any chains, they want to control all of them so don't load backups
  local hasChainCards = love.filesystem.getInfo(self.path .. "/chain")
  local wantsBackupChainCards = hasChainCards == nil
  for i = 2, 13 do
    -- with backup from default theme
    self.images.IMG_cards[true][i] = self:load_theme_img("chain/chain" .. tostring(math.floor(i / 10)) .. tostring(i % 10) .. "")
  end
  -- load as many more chain cards as there are available until 999, we will substitute in the mystery card if a card is missing
  self.chainCardLimit = 999
  for i = 14, 999 do
    -- without backup from default theme
    self.images.IMG_cards[true][i] = self:load_theme_img("chain/chain" .. tostring(math.floor(i / 10)) .. tostring(i % 10) .. "", wantsBackupChainCards)
    if self.images.IMG_cards[true][i] == nil then
      self.chainCardLimit = i - 1
      break
    end
  end
end

-- effectively these are the same as PixelFontMaps, convert them?
function Theme:loadLevelNumberAtlasses()
  self.images.levelNumberAtlas = {}
  local levels = 11
  for i = 1, MAX_SUPPORTED_PLAYERS do
    self.images.levelNumberAtlas[i] = {}
    self.images.levelNumberAtlas[i].image = self:load_theme_img("level_numbers_" .. i .. "P")
    local charWidth = self.images.levelNumberAtlas[i].image:getWidth() / levels
    local charHeight = self.images.levelNumberAtlas[i].image:getHeight()
    local quads = {}
    for j = 1, levels do
      quads[j] = GraphicsUtil:newRecycledQuad((j - 1) * charWidth, 0, charWidth, charHeight, self.images.levelNumberAtlas[i].image:getDimensions())
    end
    self.images.levelNumberAtlas[i].quads = quads
    self.images.levelNumberAtlas[i].charWidth = charWidth
    self.images.levelNumberAtlas[i].charHeight = charHeight
  end
end

function Theme:loadGameCursor()
  self.images.cursor = {}
  -- Cursor animation is 2 frames
  for i = 1, 2 do
    self.images.cursor[i] = {}
    -- Cursor images used to be named weird and make modders think they were for different players
    -- Load either format from the custom theme, and fallback to the built in cursor otherwise.
    local cursorImage = self:load_theme_img("cursor" .. i, false)
    local legacyCursorImage = self:load_theme_img("p" .. i .. "_cursor", false)
    if not cursorImage then
      if legacyCursorImage then
        cursorImage = legacyCursorImage
      else
        cursorImage = self:load_theme_img("cursor" .. i, true)
      end
    end
    assert(cursorImage ~= nil)
    self.images.cursor[i].image = cursorImage
    self.images.cursor[i].touchQuads = { }
    -- For touch we will show just one panels worth of cursor. 
    -- Until we decide to make an asset for that we can just use the left and right side of the controller cursor.
    -- The cursor image has a margin that extends past the panel and two panels in the middle
    -- We want to render the margin and just the outer half of the panel
    local imageWidth, imageHeight = cursorImage:getDimensions()
    local cursorWidth = 40
    local panelWidth = 16
    local margin = (cursorWidth - panelWidth * 2) / 2
    local halfCursorWidth = margin + panelWidth / 2
    local percentDesired = halfCursorWidth / 40
    local quadWidth = math.floor(imageWidth * percentDesired)
    self.images.cursor[i].touchQuads[1] = GraphicsUtil:newRecycledQuad(0, 0, quadWidth, imageHeight, imageWidth, imageHeight)
    self.images.cursor[i].touchQuads[2] = GraphicsUtil:newRecycledQuad(imageWidth-quadWidth, 0, quadWidth, imageHeight, imageWidth, imageHeight)
  end
end

-- releases all quads loaded on the same back into the quad pool
-- currently not in use but could routinely be done for theme switching in the future
function Theme:deinitializeGraphics()
  -- deinit cursor quads for recycling
  for i = 1, #self.images.cursor do
    for j = 1, #self.images.cursor[i].touchQuads do
      GraphicsUtil:releaseQuad(self.images.cursor[i].touchQuads[j])
    end
  end

  -- deinit level atlas for recycling
  for i = 1, #self.images.levelNumberAtlas do
    for j = 1, #self.images.levelNumberAtlas[i].quads do
      GraphicsUtil:releaseQuad(self.images.levelNumberAtlas[i].quads[j])
    end
  end

  -- deinit pixel font quads for recycling
  for index, fontMap in pairs(self.fontMaps) do
    if index == "numbers" then
      -- numbers have 1 more level of nesting so make a union of that and set it to fontMap
      local f = {}
      for i = 1, #fontMap do
        for _, value in pairs(fontMap.charToQuad[i]) do
          f[#f + 1] = value
        end
      end
      fontMap = f
    end

    for _, value in pairs(fontMap.charToQuad) do
      if value:typeOf("Quad") then
        GraphicsUtil:releaseQuad(value)
      end
    end
  end
end

function Theme:graphics_init(full)
  self.images = {}
  self.fontMaps = {}

  self:loadMenuGraphics()

  if full then
    self:loadSelectionGraphics()
    self:loadIngameGraphics()
  end
end

-- applies the config volume to the theme
function Theme:applyConfigVolume()
  SoundController:applySfxVolume(self.sounds)
  SoundController:applyMusicVolume(self.musics)
end


---@param theme Theme
---@param SFX_name string
---@return love.Source?
local function loadThemeSfx(theme, SFX_name)
  local dirs_to_check = {
    theme.path .. "/sfx/",
    Theme.defaultThemeDirectoryPath .. "/sfx/"
  }
  return fileUtils.findSound(SFX_name, dirs_to_check)
end

-- initializes the theme sounds
function Theme:sound_init(full)
  self.zero_sound = fileUtils.loadSoundFromSupportExtensions("client/assets/zero_music")

  self.sounds = {}
  self:loadSfx(full)
  self:loadMusic(full)

  self:applyConfigVolume()
end

function Theme:loadMenuSfx()
  self.sounds.menu_move = loadThemeSfx(self, "menu_move")
  self.sounds.menu_validate = loadThemeSfx(self, "menu_validate")
  self.sounds.menu_cancel = loadThemeSfx(self, "menu_cancel")
  self.sounds.notification = loadThemeSfx(self, "notification")
end

function Theme:loadIngameSfx()
  self.sounds.cur_move = loadThemeSfx(self, "move")
  self.sounds.swap = loadThemeSfx(self, "swap")
  self.sounds.land = loadThemeSfx(self, "land")
  self.sounds.fanfare1 = loadThemeSfx(self, "fanfare1")
  self.sounds.fanfare2 = loadThemeSfx(self, "fanfare2")
  self.sounds.fanfare3 = loadThemeSfx(self, "fanfare3")
  self.sounds.game_over = loadThemeSfx(self, "gameover")
  self.sounds.countdown = loadThemeSfx(self, "countdown")
  self.sounds.go = loadThemeSfx(self, "go")
  ---@type love.Source[]
  self.sounds.garbage_thud = {
      loadThemeSfx(self, "thud_1"),
      loadThemeSfx(self, "thud_2"),
      loadThemeSfx(self, "thud_3")
    }
  ---@type love.Source[][]
  self.sounds.pops = {}

  for popLevel = 1, 4 do
    self.sounds.pops[popLevel] = {}
    for popIndex = 1, 10 do
      self.sounds.pops[popLevel][popIndex] = loadThemeSfx(self, "pop" .. popLevel .. "-" .. popIndex)
    end
  end
end

function Theme:loadSfx(full)
  self:loadMenuSfx()

  if full then
    self:loadIngameSfx()
  end
end

local basicMusics = {"main",}
local fullMusics = {"main", "select_screen", "title_screen",} -- the music used in a theme

function Theme:loadMusic(full)
  local musics = full and fullMusics or basicMusics
  for _, music in ipairs(musics) do
    self.musics[music] = Music.load(self.path .. "/music", music)
  end
end

function Theme:upgradeAndSaveVerboseConfig()
  if self.version == Theme.THEME_VERSIONS.original then
    self.version = Theme.THEME_VERSIONS.two
    self:saveVerboseConfig()
  end
end

function Theme:saveVerboseConfig()
  local jsonPath = self.path .. "/config.json"

  -- Get the data from the file in case there is something we don't know about
  local jsonData = fileUtils.readJsonFile(jsonPath)

  -- Save off any configurable data that may have changed / upgraded
  local configurableKeys = self:configurableKeys()
  for key, _ in pairs(configurableKeys) do
    jsonData[key] = self[key]
  end

  fileUtils.writeJson(self.path, "config.json", jsonData)
end

-- initializes theme using the json settings
function Theme.json_init(self)
  self:loadDefaultConfig()

  -- Then override with custom theme
  local customData = fileUtils.readJsonFile(self.path .. "/config.json")
  local version = self:versionForJSONVersion(customData.version)
  if version == Theme.THEME_VERSIONS.original then
    self:loadVersion1DefaultValues()
  elseif version == Theme.THEME_VERSIONS.two then
    self:loadVersion2DefaultValues()
  end
  self:applyJSONData(customData)

  self:upgradeAndSaveVerboseConfig()
end

function Theme:versionForJSONVersion(jsonVersion)
  if jsonVersion and type(jsonVersion) == "number" then
    return  jsonVersion
  else
    return Theme.THEME_VERSIONS.original
  end
end

-- applies all the JSON values from a table
function Theme:applyJSONData(read_data)
  local configurableKeys = self:configurableKeys()
  for key, value in pairs(read_data) do
    if configurableKeys[key] ~= nil and type(value) == configurableKeys[key] then
      self[key] = read_data[key]
    end
  end

  -- Handle non standard mappings
  if self.font_size then
    self.font.size = self.font_size
    self.font_size = nil
  end
  self.version = self:versionForJSONVersion(read_data.version)
end

function Theme:final_init()
  local menuYPadding = 10
  self.centerMenusVertically = true
  if self.images.bg_title then
    menuYPadding = 100
    self.main_menu_screen_pos = {532, menuYPadding}
    self.main_menu_y_max = consts.CANVAS_HEIGHT - menuYPadding
  else
    self.main_menu_screen_pos = {532, 249}
    self.main_menu_y_max = consts.CANVAS_HEIGHT - menuYPadding
    self.centerMenusVertically = false
  end
  self.main_menu_max_height = (self.main_menu_y_max - self.main_menu_screen_pos[2])
  self.main_menu_y_center = self.main_menu_screen_pos[2] + (self.main_menu_max_height / 2)

end

function Theme:offsetsAreFixed()
  return self.version >= Theme.THEME_VERSIONS.fixedOffsets
end

function Theme:chainImage(chainAmount)
  local cardImage = self.images.IMG_cards[true][chainAmount]
  if cardImage == nil then
   cardImage = self.images.IMG_cards[true][0]
  end
  return cardImage
end

function Theme:comboImage(comboAmount)
  local cardImage = self.images.IMG_cards[false][comboAmount]
  if cardImage == nil then
   cardImage = self.images.IMG_cards[false][0]
  end
  return cardImage
end

function Theme:defaultModInit()
  self:loadDefaultStage()
end

function Theme:loadDefaultStage()
  local stagePath = self.path .. "/default/stage"
  local defaultStage
  if love.filesystem.getInfo(stagePath, "directory") then
    defaultStage = require("client.src.mods.Stage")(stagePath, "__default")
    -- we don't want to do a full json init but we need to find out the music style of the default stage
    local read_data = fileUtils.readJsonFile(defaultStage.path .. "/config.json")
    if read_data and read_data.music_style and type(read_data.music_style) == "string" then
      defaultStage.music_style = read_data.music_style
    end
    defaultStage:preload()
    defaultStage:load(true)
  elseif self.path ~= consts.DEFAULT_THEME_DIRECTORY then
    defaultStage = themes[consts.DEFAULT_THEME_DIRECTORY]:loadDefaultStage()
  else
    error("No default stage available")
  end

  self.defaultStage = defaultStage
  return defaultStage
end

-- loads a theme into the game
function Theme:load()
  logger.debug("loading theme " .. self.name)
  self:json_init()
  self:graphics_init(true)
  self:sound_init(true)
  self:final_init()
  self:defaultModInit()
  self.fullyLoaded = true
  logger.debug("loaded theme " .. self.name)
end

function Theme:preload()
  logger.debug("preloading theme " .. self.name)
  self:json_init()
  self:graphics_init(false)
  self:sound_init(false)
  self:final_init()
  self.fullyLoaded = false
  logger.debug("preloaded theme " .. self.name)
end

-- initializes a theme
function theme_init()
  -- only one theme at a time for now, but we may decide to allow different themes in the future
  themes = {}
  themeIds = {}
  for _, dirName in ipairs(fileUtils.getFilteredDirectoryItems("themes", "directory")) do
    if tableUtils.contains(fileUtils.getFilteredDirectoryItems("themes/" .. dirName, "file"), "config.json") then
      themeIds[#themeIds + 1] = dirName
      themes[dirName] = Theme("themes/" .. dirName, dirName)
    end
  end

  -- add the default theme
  themeIds[#themeIds+1] = consts.DEFAULT_THEME_DIRECTORY
  -- sort by name because the default name was added in only later
  table.sort(themeIds)
  themes[consts.DEFAULT_THEME_DIRECTORY] = Theme(Theme.defaultThemeDirectoryPath, consts.DEFAULT_THEME_DIRECTORY)

  themes[config.theme]:load()
  if themes[config.theme].font then
    GraphicsUtil.setGlobalFont(themes[config.theme].font.path, themes[config.theme].font.size)
  end
end

function Theme:playCancelSfx()
  SoundController:playSfx(self.sounds.menu_cancel)
end

function Theme:playValidationSfx()
  SoundController:playSfx(self.sounds.menu_validate)
end

function Theme:playMoveSfx()
  SoundController:playSfx(self.sounds.menu_move)
end

---@param index integer?
---@return love.Texture[]
function Theme:getGridCursor(index)
  index = index or 1
  if not (self.images.IMG_char_sel_cursors and self.images.IMG_char_sel_cursors[index]) then
    loadGridCursors(self)
  end

  return self.images.IMG_char_sel_cursors[index]
end

---@return love.Texture
function Theme:getWinsLabel()
  index = index or 1
  if not self.images.IMG_wins then
    self:loadIngameLabels()
  end

  return self.images.IMG_wins
end

---@return love.Texture
function Theme:getMovesLabel()
  index = index or 1
  if not self.images.IMG_moves then
    self:loadIngameLabels()
  end

  return self.images.IMG_moves
end

---@param index integer?
---@return love.Texture
function Theme:getSpeedLabel(index)
  index = index or 1
  if not (self.images.speedLabels and self.images.speedLabels[index]) then
    self:loadIngameLabels()
  end

  return self.images.speedLabels[index]
end

---@param index integer?
---@return love.Texture
function Theme:getRatingLabel(index)
  index = index or 1
  if not (self.images.ratingLabels and self.images.ratingLabels[index]) then
    self:loadIngameLabels()
  end

  return self.images.ratingLabels[index]
end

---@param index integer?
---@return love.Texture
function Theme:getLevelLabel(index)
  index = index or 1
  if not (self.images.levelLabels and self.images.levelLabels[index]) then
    self:loadIngameLabels()
  end

  return self.images.levelLabels[index]
end

---@param index integer?
---@return love.Texture
function Theme:getScoreLabel(index)
  index = index or 1
  if not (self.images.scoreLabels and self.images.scoreLabels[index]) then
    self:loadIngameLabels()
  end

  return self.images.scoreLabels[index]
end

---@param index integer?
---@return PixelFontMap
function Theme:getNumberPixelFont(index)
  index = index or 1
  if not (self.fontMaps.numbers and self.fontMaps.numbers[index]) then
    self:loadIngameLabels()
  end

  return self.fontMaps.numbers[index]
end

---@param index integer?
---@return {image: love.Texture, charWidth: integer, charHeight: integer, quads: love.Quad[]}
function Theme:getLevelAtlas(index)
  index = index or 1
  if not (self.images.levelNumberAtlas and self.images.levelNumberAtlas[index]) then
    self:loadIngameLabels()
  end

  return self.images.levelNumberAtlas[index]
end

---@param index integer?
---@return love.Texture
function Theme:getFrame(index)
  index = index or 1
  if not (self.images.frames and self.images.frames[index]) then
    self:loadIngameGraphics()
  end

  return self.images.frames[index]
end

---@param index integer?
---@return love.Texture
function Theme:getWall(index)
  index = index or 1
  if not (self.images.walls and self.images.walls[index]) then
    self:loadIngameGraphics()
  end

  return self.images.walls[index]
end

---@param index integer?
---@return love.Texture
function Theme:getPlayerNumberIcon(index)
  index = index or 1
  if not (self.images.IMG_players and self.images.IMG_players[index]) then
    loadPlayerNumberIcons(self)
  end

  return self.images.IMG_players[index]
end

---@param index integer?
---@return love.Texture
function Theme:getHealthBarFrameAbsolute(index)
  index = index or 1
  if not (self.images.healthbarFrames and self.images.healthbarFrames.absolute and self.images.healthbarFrames.absolute[index]) then
    self:loadMultibar()
  end

  return self.images.healthbarFrames.absolute[index]
end

---@param index integer?
---@return love.Texture
function Theme:getHealthBarFrameRelative(index)
  index = index or 1
  if not (self.images.healthbarFrames and self.images.healthbarFrames.relative and self.images.healthbarFrames.relative[index]) then
    self:loadMultibar()
  end

  return self.images.healthbarFrames.relative[index]
end

---@param index integer
---@return MultiBarPack
function Theme:getMultibar(index)
  ---@class MultiBarPack
  local multibar = {
    frameAbsolute = self:getHealthBarFrameAbsolute(index),
    frameRelative = self:getHealthBarFrameRelative(index),
    health = self.images.IMG_healthbar,
    preStop = self.images.IMG_multibar_prestop_bar,
    stop = self.images.IMG_multibar_stop_bar,
    shake = self.images.IMG_multibar_shake_bar,
  }

  return multibar
end

---@return PixelFontMap
function Theme:getTimePixelFont()
  index = index or 1
  if not self.fontMaps.time then
    self:loadIngameLabels()
  end

  return self.fontMaps.time
end

---@param index integer
---@return IngameAssetPack
function Theme:getIngameAssetPack(index)
  ---@class IngameAssetPack
  local pack = {
    speed = self:getSpeedLabel(index),
    score = self:getScoreLabel(index),
    rating = self:getRatingLabel(index),
    level = self:getLevelLabel(index),
    levelAtlas = self:getLevelAtlas(index),
    numberPixelFont = self:getNumberPixelFont(index),
    frame = self:getFrame(index),
    wall = self:getWall(index),
    multibar = self:getMultibar(index),
    wins = self:getWinsLabel(),
    moves = self:getMovesLabel(),
  }

  return pack
end

function Theme:getSelectionAssetPack(index)
  local pack = {
    playerNumberIcon = self:getPlayerNumberIcon(index),
    gridCursor = self:getGridCursor(index),
  }

  return pack
end

return Theme