local class = require("common.lib.class")

---@class PanelSource
---@field generateStartingBoard fun(self: PanelSource, stack: Stack): string
---@field generatePanels fun(self: PanelSource, stack:Stack, rowCount: integer): string
---@field generateGarbagePanels fun(self: PanelSource, stack:Stack, rowCount: integer): string
local PanelSource = class(
function(self)

end)

PanelSource.PANEL_COLOR_NUMBER_TO_UPPER = {"A", "B", "C", "D", "E", "F", "G", "H", "I", [0] = "0"}
PanelSource.PANEL_COLOR_NUMBER_TO_LOWER = {"a", "b", "c", "d", "e", "f", "g", "h", "i", [0] = "0" }
PanelSource.PANEL_COLOR_TO_NUMBER = {
  ["A"] = 1, ["B"] = 2, ["C"] = 3, ["D"] = 4, ["E"] = 5, ["F"] = 6, ["G"] = 7, ["H"] = 8, ["I"] = 9, ["J"] = 0,
  ["a"] = 1, ["b"] = 2, ["c"] = 3, ["d"] = 4, ["e"] = 5, ["f"] = 6, ["g"] = 7, ["h"] = 8, ["i"] = 9, ["j"] = 0,
  ["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7, ["8"] = 8, ["9"] = 9, ["0"] = 0
}

function PanelSource:getStartingBoardHeight(stack)
  error("Did not implement getStartingBoardHeight")
end

---@param stack Stack
function PanelSource:generateStartingBoard(stack)
  error("Did not implement generateStartingBoard")
end

---@param stack Stack
---@param rowCount integer
function PanelSource:generatePanels(stack, rowCount)
  error("Did not implement generatePanels")
end

---@param stack Stack
---@param rowCount integer
function PanelSource:generateGarbagePanels(stack, rowCount)
  error("Did not implement generateGarbagePanels")
end

---@param stack Stack
---@return Panel[]
function PanelSource:createNewRow(stack, row)
  error("Did not implement createNewRow")
end

return PanelSource