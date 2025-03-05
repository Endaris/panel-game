local class = require("common.lib.class")
local PanelSource = require("common.engine.PanelSource")

---@class PuzzleSource : PanelSource
---@field puzzleString string
---@field panelBuffer string
---@field garbageBuffer string
local PuzzleSource = class(
function(self, puzzleString, panelBuffer, garbageBuffer)
  self.puzzleString = puzzleString
  self.panelBuffer = panelBuffer
  self.garbageBuffer = garbageBuffer
end,
PanelSource)

function PuzzleSource:getStartingBoardHeight(stack)
  return math.ceil(self.puzzleString / stack.width)
end

function PuzzleSource:generateStartingBoard(stack)
  return self.puzzleString
end

function PuzzleSource:generatePanels(stack, rowCount)
  local panels = ""
  local desiredCount = stack.width * rowCount
  if self.panelBuffer:len() > desiredCount then
    panels = self.panelBuffer:sub(1, desiredCount)
    self.panelBuffer = self.panelBuffer:sub(desiredCount + 1)
  else
    panels = self.panelBuffer
    self.panelBuffer = ""
    panels = panels .. string.rep(9, desiredCount - panels:len())
  end

  return panels
end

function PuzzleSource:generateGarbagePanels(stack, rowCount)
  local panels = ""
  local desiredCount = stack.width * rowCount
  if self.garbageBuffer:len() > desiredCount then
    panels = self.garbageBuffer:sub(1, desiredCount)
    self.garbageBuffer = self.garbageBuffer:sub(desiredCount + 1)
  else
    panels = self.garbageBuffer
    self.garbageBuffer = ""
    panels = panels .. string.rep(9, desiredCount - panels:len())
  end

  return panels
end

return PuzzleSource