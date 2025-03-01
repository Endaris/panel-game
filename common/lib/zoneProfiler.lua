---@enum ZoneProfiler
local profilers = { jprof = 1, jit = 2 }

local zoneProfiler = {
  enabled = false,
  minimumDuration = 0,
  ---@type ZoneProfiler
  profiler = profilers.jprof,
}

local function noop() end

zoneProfiler.push = noop
zoneProfiler.pop = noop

function zoneProfiler.enable(enable)
  zoneProfiler.enabled = enable
  if zoneProfiler.enabled then
    -- we want to optimize in a way that our weakest platforms benefit
    -- on our weakest platform (android), jit is default disabled
    jit.off()
    if zoneProfiler.profiler == profilers.jit then
      -- to be implemented
      -- for jit profiling we *might* want jit to be on but it depends
    elseif zoneProfiler.profiler == profilers.jprof then
      package.loaded["common.lib.jprof.jprof"] = nil
      PROF_CAPTURE = true
      local jprof = require("common.lib.jprof.jprof")
      zoneProfiler.push = jprof.push
      zoneProfiler.pop = jprof.pop
    else
      error("Tried to enable zone profiling with an unknown profiler")
    end
  else
    zoneProfiler.push = noop
    zoneProfiler.pop = noop
  end
end

---@param time number
function zoneProfiler.setDurationFilter(time)
  zoneProfiler.minimumDuration = tonumber(time) or 0
  if zoneProfiler.profiler == profilers.jprof then
    local jprof = require("common.lib.jprof.jprof")
    jprof.setMinimumDuration(zoneProfiler.minimumDuration)
  end
end

---@param profiler ZoneProfiler
function zoneProfiler.setProfiler(profiler)
  zoneProfiler.profiler = profiler
end

function zoneProfiler.write()
  if zoneProfiler.profiler == profilers.jprof then
    local jprof = require("common.lib.jprof.jprof")
    jprof.write("prof.mpack")
  end
end

return zoneProfiler