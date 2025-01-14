--[[
  level data is a data format that determines how a Stack operates
  level data does not cover EVERYTHING about a stack's behaviour (search allowAdjacentColors) - but almost
  level data is also used as an exchange format for server communication
]]--

local class = require("common.lib.class")
local logger = require("common.lib.logger")

---@class StopData
---@field formula STOP_FORMULA
---@field comboConstant integer
---@field chainConstant integer
---@field dangerConstant integer
---@field coefficient integer
---@field dangerCoefficient integer

---@class FrameData
---@field HOVER integer
---@field GARBAGE_HOVER integer
---@field FLASH integer
---@field FACE integer
---@field POP integer


---@class LevelData
---@field startingSpeed integer The speed the stack should start at
---@field speedIncreaseMode SPEED_INCREASE_MODE The manner in which speed increases throughout the game
---@field shockFrequency integer How many blocks need to be cleared to queue the next shock panel for panel generation
---@field shockCap integer How many shock panels can be queued at maximum; 0 disables shock blocks
---@field colors integer How many colors are used for panel generation
---@field maxHealth integer Unconditional invincibility frames that run out while topped out with no other type of invincibility frames available
---@field stop StopData Dictionary of number values used to award stop time
---@field frameConstants FrameData Dictionary of number values used to determine panel physics 

---@class LevelData
---@overload fun(): LevelData
---normally declaring @type in addition to @class isn't necessary
---we do it here because as an interop format, LevelData is assigned as the metatable in some places
---and LuaLS flags that because it somehow cannot believe LevelData is a table without this declaration
---@type LevelData
local LevelData = class(
function(self)
  -- the initial speed upon match start
  -- defines how many frames it takes to rise one row via the Stack's SPEED_TO_RISE_TIME table
  -- values are only valid within the range of indexes of SPEED_TO_RISE_TIME (so 1 - 99)
  self.startingSpeed = 1
  self.speedIncreaseMode = self.SPEED_INCREASE_MODES.TIME_INTERVAL

  -- how many blocks need to be cleared to queue the next shock panel for panel generation
  self.shockFrequency = 12
  -- how many shock panels can be queued at maximum; 0 disables shock blocks
  self.shockCap = 21

  -- how many colors are used for panel generation
  self.colors = 5

  -- unconditional invincibility frames that run out while topped out with no other type of invincibility frames available
  -- may refill once no longer topped out
  self.maxHealth = 121

  -- the stop table contains constants for calculating the awarded stop time from chains and combos
  self.stop = {
    -- the formula used for calculating stop time
    formula = nil, --self.STOP_FORMULAS.MODERN,
    --formula 1 & 2: unconditional constant awarded for any combo while not topped out
    comboConstant = nil,
    --formula 1: unconditional constant awarded for any chain while not topped and any combo while topped out
    --formula 2: unconditional constant awarded for any chain while not topped out
    chainConstant = nil,
    --formula 1: unconditional constant awarded for any chain while topped out
    --formula 2: unconditional costant awarded for any combo or chain while topped out
    dangerConstant = nil,
    --formula 1: additional stoptime is provided upon meeting certain thresholds for chain length / combo size, both regular and topped out
    --formula 2: does not use coefficients
    coefficient = nil,
    --equivalent to coefficient in use but may be different in danger
    dangerCoefficient = nil,
  }

  -- the frameConstants table contains information relevant for panels physics
  self.frameConstants = {
    -- for how long a panel stays above an empty space before falling down
    HOVER = nil,
    -- for how long garbage panels are in hover state after popping
    GARBAGE_HOVER = nil,
    -- for how long panels flash after being matched
    FLASH = nil,
    -- for how long panels show their matched face after completing the flash (before the pop timers of the panels start)
    -- this may not be directly referenced in favor of a MATCH constant that equals FLASH + FACE (the total time a panel stays in matched state)
    FACE = nil,
    -- how long it takes for 1 panel of a match to pop (go from popping to popped)
    POP = nil,
  }
end)

LevelData.TYPE = "LevelData"

-- the mechanism through which speed increases throughout the game
--   mode 1: in constant time intervals
--   mode 2: depending on how many panels were cleared according to the Stack's PANELS_TO_NEXT_SPEED table
---@enum SPEED_INCREASE_MODE
LevelData.SPEED_INCREASE_MODES = {
  TIME_INTERVAL = 1,
  CLEARED_PANEL_COUNT = 2,
}

-- represents the two different ways the Stack may calculate stop time
---@enum STOP_FORMULA
LevelData.STOP_FORMULAS = {
  MODERN = 1,
  CLASSIC = 2,
}

---@param a LevelData
---@param b LevelData
---@return boolean
function LevelData.__eq(a, b)
  return a.colors == b.colors and
         a.maxHealth == b.maxHealth and
         a.startingSpeed == b.startingSpeed and
         a.speedIncreaseMode == b.speedIncreaseMode and
         a.shockFrequency == b.shockFrequency and
         a.shockCap == b.shockCap and
         a.stop.formula == b.stop.formula and
         a.stop.comboConstant == b.stop.comboConstant and
         a.stop.chainConstant == b.stop.chainConstant and
         a.stop.dangerConstant == b.stop.dangerConstant and
         a.stop.coefficient == b.stop.coefficient and
         a.stop.dangerCoefficient == b.stop.dangerCoefficient and
         a.frameConstants.HOVER == b.frameConstants.HOVER and
         a.frameConstants.GARBAGE_HOVER == b.frameConstants.GARBAGE_HOVER and
         a.frameConstants.FLASH == b.frameConstants.FLASH and
         a.frameConstants.FACE == b.frameConstants.FACE and
         a.frameConstants.POP == b.frameConstants.POP
end

---@return boolean # if the LevelData is suitable for a Stack that receives garbage
function LevelData:isGarbageCompatible()
  return self.frameConstants.GARBAGE_HOVER ~= nil
end

---@param speedIncreaseMode SPEED_INCREASE_MODE
---@return self LevelData the modified LevelData (same object the function was called on)
function LevelData:setSpeedIncreaseMode(speedIncreaseMode)
  if speedIncreaseMode ~= self.SPEED_INCREASE_MODES.TIME_INTERVAL and speedIncreaseMode ~= self.SPEED_INCREASE_MODES.CLEARED_PANEL_COUNT then
    logger.warn("Tried to set invalid speedIncreaseMode " .. tostring(speedIncreaseMode))
  else
    self.speedIncreaseMode = speedIncreaseMode
  end
  return self
end

---@param startingSpeed number the starting speed to use for the stack
function LevelData:setStartingSpeed(startingSpeed)
  if startingSpeed < 0 or startingSpeed > 99 then
    logger.warn("Tried to set invalid starting speed " .. tostring(startingSpeed))
  else
    self.startingSpeed = startingSpeed
  end
  return self
end

function LevelData:setShockFrequency(frequency)
  self.shockFrequency = frequency
  return self
end

function LevelData:setShockCap(cap)
  self.shockCap = cap
  return self
end

function LevelData:setColorCount(colorCount)
  if colorCount < 4 or colorCount > 7 then
    logger.warn("Tried to set invalid color count " .. tostring(colorCount))
  else
    self.colors = colorCount
  end
  return self
end

function LevelData:setMaxHealth(maxHealth)
  if maxHealth < 1 then
    logger.warn("Tried to set invalid max health " .. tostring(maxHealth))
  else
    self.maxHealth = maxHealth
  end
  return self
end

---@param formula STOP_FORMULA
function LevelData:setStopFormula(formula)
  if formula ~= self.STOP_FORMULAS.MODERN and formula ~= self.STOP_FORMULAS.CLASSIC then
    logger.warn("Tried to set invalid stop formula " .. tostring(formula))
  else
    self.stop.formula = formula
  end
  return self
end

function LevelData:setStopComboConstant(comboConstant)
  self.stop.comboConstant = comboConstant
  return self
end

function LevelData:setStopChainConstant(chainConstant)
  self.stop.chainConstant = chainConstant
  return self
end

function LevelData:setStopDangerConstant(dangerConstant)
  self.stop.dangerConstant = dangerConstant
  return self
end

function LevelData:setStopCoefficient(coefficient)
  self.stop.coefficient = coefficient
  return self
end

function LevelData:setStopDangerCoefficient(dangerCoefficient)
  self.stop.dangerCoefficient = dangerCoefficient
  return self
end

function LevelData:setHover(hover)
  self.frameConstants.HOVER = hover
  return self
end

function LevelData:setGarbageHover(garbageHover)
  self.frameConstants.GARBAGE_HOVER = garbageHover
  return self
end

function LevelData:setFlash(flash)
  self.frameConstants.FLASH = flash
  return self
end

function LevelData:setFace(face)
  self.frameConstants.FACE = face
  return self
end

function LevelData:setPop(pop)
  self.frameConstants.POP = pop
  return self
end

function LevelData.validate(data)
  if not data.startingSpeed or type(data.startingSpeed) ~= "number" then
    return false
  elseif data.startingSpeed < 0 or data.startingSpeed > 99 then
    return false
  elseif not data.speedIncreaseMode or type(data.speedIncreaseMode) ~= "number" then
    return false
  elseif data.speedIncreaseMode ~= LevelData.SPEED_INCREASE_MODES.TIME_INTERVAL and data.speedIncreaseMode ~= LevelData.SPEED_INCREASE_MODES.CLEARED_PANEL_COUNT then
    return false
  elseif not data.shockCap or type(data.shockCap) ~= "number" then
    return false
  elseif not data.shockFrequency or type(data.shockFrequency) ~= "number" then
    return false
  elseif not data.colors or type(data.colors) ~= "number" then
    return false
  elseif data.colors < 4 or data.colors > 7 then
    return false
  elseif not data.maxHealth or type(data.maxHealth) ~= "number" then
    return false
  elseif data.maxHealth < 1 then
    return false
  elseif not data.stop or type(data.stop) ~= "table" then
    return false
  elseif not data.stop.formula or type(data.stop.formula) ~= "number" then
    return false
  elseif data.stop.formula ~= LevelData.STOP_FORMULAS.CLASSIC and data.stop.formula ~= LevelData.STOP_FORMULAS.MODERN then
    return false
  elseif not data.stop.comboConstant or type(data.stop.comboConstant) ~= "number" then
    return false
  elseif not data.stop.chainConstant or type(data.stop.chainConstant) ~= "number" then
    return false
  elseif not data.stop.dangerConstant or type(data.stop.dangerConstant) ~= "number" then
    return false
  elseif not data.stop.coefficient or type(data.stop.coefficient) ~= "number" then
    return false
  elseif not data.stop.dangerCoefficient or type(data.stop.dangerCoefficient) ~= "number" then
    return false
  elseif not data.stop.comboConstant or type(data.stop.comboConstant) ~= "number" then
    return false
  elseif not data.frameConstants or type(data.frameConstants) ~= "table" then
    return false
  elseif not data.frameConstants.HOVER or type(data.frameConstants.HOVER) ~= "number" then
    return false
  -- GARBAGE_HOVER can be nil
  elseif not data.frameConstants.FLASH or type(data.frameConstants.FLASH) ~= "number" then
    return false
  elseif not data.frameConstants.FACE or type(data.frameConstants.FACE) ~= "number" then
    return false
  elseif not data.frameConstants.POP or type(data.frameConstants.POP) ~= "number" then
    return false
  end

  return true
end

return LevelData