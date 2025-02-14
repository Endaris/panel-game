local PATH = (...):gsub('%.[^%.]+$', '')
local Carousel = require(PATH .. ".Carousel")
local StackPanel = require(PATH .. ".StackPanel")
local Label = require(PATH .. ".Label")
local ImageContainer = require(PATH .. ".ImageContainer")
local class = require("common.lib.class")
local consts = require("common.engine.consts")
local Stage = require("client.src.mods.Stage")

local StageCarousel = class(function(carousel, options)

end, Carousel)


function StageCarousel:createPassenger(id, image, text)
  local passenger = {}
  passenger.id = id
  passenger.uiElement = StackPanel({alignment = "top", hFill = true, hAlign = "center", vAlign = "center", y = 4})
  passenger.image = ImageContainer({image = image, vAlign = "top", hAlign = "center", drawBorders = true, width = 80, height = 45})
  passenger.uiElement:addElement(passenger.image)
  passenger.label = Label({text = text, translate = id == consts.RANDOM_STAGE_SPECIAL_VALUE, hAlign = "center"})
  passenger.uiElement:addElement(passenger.label)
  return passenger
end

function StageCarousel:loadCurrentStages()
  for i = 0, #visibleStages do
    local stage
    if i == 0 then
      stage = Stage.getRandom()
    else
      stage = stages[visibleStages[i]]
    end

    if not stage.images.thumbnail then
      error("Cannot load stage " .. stage.id .. " because no thumbnail was loaded")
    end
    local passenger = StageCarousel:createPassenger(stage.id, stage.images.thumbnail, stage.display_name)
    self:addPassenger(passenger)
  end

  self:setPassengerById(config.stage)
end

return StageCarousel