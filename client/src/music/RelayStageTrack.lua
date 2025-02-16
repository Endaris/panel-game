local class = require("common.lib.class")
local StageTrack = require("client.src.music.StageTrack")

local RelayStageTrack = class(function(stageTrack, normalMusic, dangerMusic, volumeMultiplier)
  assert(dangerMusic, "Relay tracks need danger music!")
end,
StageTrack)

function RelayStageTrack:changeMusic(useDangerMusic)
  self.currentMusic:pause()
  if useDangerMusic then
    self.state = "danger"
  else
    self.state = "normal"
  end
  self:play()
end

return RelayStageTrack