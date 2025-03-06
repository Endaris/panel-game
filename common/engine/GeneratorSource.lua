local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local PanelGenerator = require("common.engine.PanelGenerator")

---@class GeneratorSource : PanelSource
---@field seed integer
---@overload fun(seed: integer): GeneratorSource
local GeneratorSource = class(
---@param self GeneratorSource
---@param seed integer
function(self, seed)
  self.seed = seed
  self.panelBuffer = ""
  self.garbagePanelBuffer = ""
  self.panelGenCount = 0
  self.garbageGenCount = 0
end)

function GeneratorSource:getStartingBoardHeight(stack)
  return 7
end

---@param stack Stack
function GeneratorSource:generateStartingBoard(stack)
  PanelGenerator:setSeed(self.seed + self.panelGenCount)

  local allowAdjacentColors = stack.allowAdjacentColorsOnStartingBoard

  local ret = PanelGenerator.privateGeneratePanels(self:getStartingBoardHeight(stack), stack.width, stack.levelData.colors, self.panelBuffer, not allowAdjacentColors)
  -- technically there can never be metal on the starting board but we need to call it to advance the RNG (compatibility)
  ret = PanelGenerator.assignMetalLocations(ret, stack.width)

  self.panelGenCount = self.panelGenCount + 1

  -- legacy crutch, the arcane magic for the non-uniform starting board assumes this is there and it really doesn't work without it
  ret = string.rep("0", stack.width) .. ret
  -- arcane magic to get a non-uniform starting board
  ret = procat(ret)
  local maxStartingHeight = 7
  local height = tableUtils.map(procat(string.rep(maxStartingHeight, stack.width)), function(s) return tonumber(s) end)
  local to_remove = 2 * stack.width
  while to_remove > 0 do
    local idx = PanelGenerator:random(1, stack.width) -- pick a random column
    if height[idx] > 0 then
      ret[idx + stack.width * (-height[idx] + 8)] = "0" -- delete the topmost panel in this column
      height[idx] = height[idx] - 1
      to_remove = to_remove - 1
    end
  end

  ret = table.concat(ret)
  ret = string.sub(ret, stack.width + 1)

  return ret
end

---@param stack Stack
function GeneratorSource:generatePanels(stack)
  PanelGenerator:setSeed(self.seed + self.panelGenCount)

  local panelColors = PanelGenerator.privateGeneratePanels(100, stack.width, stack.levelData.colors, self.panelBuffer, not stack.behaviours.allowAdjacentColors)
  panelColors = PanelGenerator.assignMetalLocations(panelColors, stack.width)

  self.panelGenCount = self.panelGenCount + 1

  return panelColors
end

---@param stack Stack
function GeneratorSource:generateGarbagePanels(stack)
  PanelGenerator:setSeed(self.seed + self.garbageGenCount)
  self.garbageGenCount = self.garbageGenCount + 1
  return PanelGenerator.privateGeneratePanels(20, stack.width, stack.levelData.colors, self.garbagePanelBuffer, not stack.behaviours.allowAdjacentColors)
end

---@param stack Stack
---@param row integer
---@return Panel[] panelRow
function GeneratorSource:createNewRow(stack, row)
  if self.panelGenCount == 0 then
    self.panelBuffer = self:generateStartingBoard(stack)
  else
    if string.len(self.panelBuffer) <= 10 * stack.width then
      self.panelBuffer = self:generatePanels(stack)
    end
  end


  -- assign colors to the new row 0
  local metal_panels_this_row = 0
  if stack.metal_panels_queued > 3 then
    stack.metal_panels_queued = stack.metal_panels_queued - 2
    metal_panels_this_row = 2
  elseif stack.metal_panels_queued > 0 then
    stack.metal_panels_queued = stack.metal_panels_queued - 1
    metal_panels_this_row = 1
  end

  for col = 1, stack.width do
    local panel = stack:createPanelAt(row, col)
    local colorString = self.panelBuffer:sub(col, col)
    local color = 0
    if tonumber(colorString) then
      color = colorString + 0
    elseif colorString >= "A" and colorString <= "Z" then
      if metal_panels_this_row > 0 then
        color = 8
      else
        color = PanelGenerator.PANEL_COLOR_TO_NUMBER[colorString]
      end
    elseif colorString >= "a" and colorString <= "z" then
      if metal_panels_this_row > 1 then
        color = 8
      else
        color = PanelGenerator.PANEL_COLOR_TO_NUMBER[colorString]
      end
    end
    panel.color = color
    panel.state = "dimmed"
  end

  self.panelBuffer = string.sub(self.panelBuffer, stack.width + 1)

  return stack.panels[row]
end

function GeneratorSource:getGarbagePanelRowString(stack)
  if string.len(self.garbagePanelBuffer) <= 10 * stack.width then
    -- generateGarbagePanels already appends to the existing garbagePanelBuffer
    local newGarbagePanels = self:generateGarbagePanels(stack)
    -- and then we append that result to the remaining buffer
    self.garbagePanelBuffer = self.garbagePanelBuffer .. newGarbagePanels
    -- that means the next 10 rows of garbage will use the same colors as the 10 rows after
  -- that's a bug but it cannot be fixed without breaking replays
  -- it is also hard to abuse as 
  -- a) players would need to accurately track the 10 row cycles
  -- b) "solve into the same thing" only applies to a limited degree:
  --   a garbage panel row of 123456 solves into 1234 for ====00 but into 3456 for 00====
  --   that means information may be incomplete and partial memorization may prove unreliable
  -- c) garbage panels change every (10 + n * 20 rows) with n>0 in ℕ 
  --    so the player needs to always survive 20 rows to start abusing
  --    and can then only abuse for every 10 rows out of 20
  -- overall it is to be expected that the strain of trying to memorize outweighs the gains
  -- this bug should be fixed with the next breaking change to the engine
  end
  local garbagePanelRow = string.sub(self.garbagePanelBuffer, 1, stack.width)
  self.garbagePanelBuffer = string.sub(self.garbagePanelBuffer, stack.width + 1)
  return garbagePanelRow
end

function GeneratorSource:clone()
  local source = GeneratorSource(self.seed)
  source.panelBuffer = self.panelBuffer
  source.garbagePanelBuffer = self.garbagePanelBuffer
  source.panelGenCount = self.panelGenCount
  source.garbageGenCount = self.garbageGenCount
  return source
end

return GeneratorSource