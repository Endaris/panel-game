local util = require("common.lib.util")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local PanelSource = require("common.engine.PanelSource")

-- table of static functions used for generating panels
---@class PanelGenerator : PanelSource
---@field rng love.RandomGenerator
---@field generatedCount integer
---@field seed integer
local PanelGenerator = {rng = love.math.newRandomGenerator(), generatedCount = 0}
setmetatable(PanelGenerator, PanelSource)

-- sets the seed for the PanelGenerators own random number generator
-- seed has to be a number
function PanelGenerator:setSeed(seed)
  if seed then
    self.generatedCount = 0
    self.seed = seed
    self.rng:setSeed(seed)
  end
end

function PanelGenerator:random(min, max)
  self.generatedCount = self.generatedCount + 1
  return self.rng:random(min, max)
end

---@param rowsToMake integer
---@param rowWidth integer
---@param ncolors integer
---@param previousPanels string
---@param disallowAdjacentColors boolean
---@return string panelBuffer
function PanelGenerator.privateGeneratePanels(rowsToMake, rowWidth, ncolors, previousPanels, disallowAdjacentColors)
  -- logger.info("generating panels with seed: " .. PanelGenerator.rng:getSeed() ..
  --              "\nbuffer: " .. previousPanels ..
  --              "\ncolors: " .. ncolors)

  local result = previousPanels

  if ncolors < 2 then
    error("Trying to generate panels with only " .. ncolors .. " colors")
  end

  for x = 0, rowsToMake - 1 do
    for y = 0, rowWidth - 1 do
      local previousTwoMatchOnThisRow = y > 1 and PanelSource.PANEL_COLOR_TO_NUMBER[string.sub(result, -1, -1)] ==
                                            PanelSource.PANEL_COLOR_TO_NUMBER[string.sub(result, -2, -2)]
      local nogood = true
      local color = 0
      local belowColor = PanelSource.PANEL_COLOR_TO_NUMBER[string.sub(result, -rowWidth, -rowWidth)]
      while nogood do
        color = PanelGenerator:random(1, ncolors)
        nogood =
            (previousTwoMatchOnThisRow and color == PanelSource.PANEL_COLOR_TO_NUMBER[string.sub(result, -1, -1)]) or -- Can't have three in a row on this column
            color == belowColor or -- can't have the same color as below
                (y > 0 and color == PanelSource.PANEL_COLOR_TO_NUMBER[string.sub(result, -1, -1)] and disallowAdjacentColors) -- on level 8+ vs, don't allow any adjacent colors
      end
      result = result .. tostring(color)
    end
  end
  -- logger.debug(result)
  return result
end

---@param ret string
---@param rowWidth integer
---@return string panelBuffer
function PanelGenerator.assignMetalLocations(ret, rowWidth)
  -- logger.debug("panels before potential metal panel position assignments:")
  -- logger.debug(ret)
  -- assign potential metal panel placements
  local new_ret = string.rep("0", rowWidth)
  local new_row
  local prev_row
  for i = 1, string.len(ret) / rowWidth do
    local current_row_from_ret = string.sub(ret, (i - 1) * rowWidth + 1, (i - 1) * rowWidth + rowWidth)
    -- logger.debug("current_row_from_ret: " .. current_row_from_ret)
    if tonumber(current_row_from_ret) then -- doesn't already have letters in it for metal panel locations
      prev_row = string.sub(new_ret, 0 - rowWidth, -1)
      local first, second -- locations of potential metal panels
      -- while panel vertically adjacent is not numeric, so can be a metal panel
      while not first or not tonumber(string.sub(prev_row, first, first)) do
        first = PanelGenerator:random(1, rowWidth)
      end
      while not second or second == first or not tonumber(string.sub(prev_row, second, second)) do
        second = PanelGenerator:random(1, rowWidth)
      end
      new_row = ""
      for j = 1, rowWidth do
        local chr_from_ret = string.sub(ret, (i - 1) * rowWidth + j, (i - 1) * rowWidth + j)
        local num_from_ret = tonumber(chr_from_ret)
        if j == first then
          new_row = new_row .. (PanelSource.PANEL_COLOR_NUMBER_TO_UPPER[num_from_ret] or chr_from_ret or "0")
        elseif j == second then
          new_row = new_row .. (PanelSource.PANEL_COLOR_NUMBER_TO_LOWER[num_from_ret] or chr_from_ret or "0")
        else
          new_row = new_row .. chr_from_ret
        end
      end
    else
      new_row = current_row_from_ret
    end
    new_ret = new_ret .. new_row
  end

  -- new_ret was started with a row of 0 because the algorithm relies on a row without shock panels being there at the start
  -- so cut that extra row out again
  new_ret = string.sub(new_ret, rowWidth + 1)

  -- logger.debug("panels after potential metal panel position assignments:")
  -- logger.debug(ret)
  return new_ret
end

function PanelGenerator:getStartingBoardHeight(stack)
  return 7
end

---@param stack Stack
function PanelGenerator:generateStartingBoard(stack)
  PanelGenerator:setSeed(stack.seed + stack.panelGenCount)

  local allowAdjacentColors = stack.allowAdjacentColorsOnStartingBoard

  local ret = PanelGenerator.privateGeneratePanels(PanelGenerator:getStartingBoardHeight(stack), stack.width, stack.levelData.colors, stack.panel_buffer, not allowAdjacentColors)
  -- technically there can never be metal on the starting board but we need to call it to advance the RNG (compatibility)
  ret = PanelGenerator.assignMetalLocations(ret, stack.width)

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
---@param rowCount integer
function PanelGenerator:generatePanels(stack, rowCount)
  PanelGenerator:setSeed(stack.seed + stack.panelGenCount)
  local panels = PanelGenerator.privateGeneratePanels(rowCount, stack.width, stack.levelData.colors, stack.panel_buffer, not stack.behaviours.allowAdjacentColors)
  panels = PanelGenerator.assignMetalLocations(panels, stack.width)
  return panels
end

---@param stack Stack
---@param rowCount integer
function PanelGenerator:generateGarbagePanels(stack, rowCount)
  PanelGenerator:setSeed(stack.seed + stack.garbageGenCount)
  return PanelGenerator.privateGeneratePanels(rowCount, stack.width, stack.levelData.colors, stack.gpanel_buffer, not stack.behaviours.allowAdjacentColors)
end

---@param stack Stack
---@param row integer
---@return Panel[] panelRow
function PanelGenerator:createNewRow(stack, row)
  if string.len(stack.panel_buffer) <= 10 * stack.width then
    stack.panel_buffer = stack:makePanels()
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
    local colorString = stack.panel_buffer:sub(col, col)
    local color = 0
    if tonumber(colorString) then
      color = colorString + 0
    elseif colorString >= "A" and colorString <= "Z" then
      if metal_panels_this_row > 0 then
        color = 8
      else
        color = self.PANEL_COLOR_TO_NUMBER[colorString]
      end
    elseif colorString >= "a" and colorString <= "z" then
      if metal_panels_this_row > 1 then
        color = 8
      else
        color = self.PANEL_COLOR_TO_NUMBER[colorString]
      end
    end
    panel.color = color
    panel.state = "dimmed"
  end

  stack.panel_buffer = string.sub(stack.panel_buffer, stack.width + 1)

  return stack.panels[row]
end

return PanelGenerator