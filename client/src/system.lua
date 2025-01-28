local system = {}

---@return boolean
function system.isMobileOS()
  local osString = love.system.getOS()

  if osString == "Android" then
    return true
  end

  if osString == "iOS" then
    return true
  end

  return false
end

---@return boolean
---@return string? problem detected problem
---@return string? reason why the system is not compatible
function system.isCompatible()
  local osString = love.system.getOS()
  if osString == "Windows" then
    local version, vendor = select(2, love.graphics.getRendererInfo())
    if vendor == "ATI Technologies Inc." and
		(version:find("22.7.1", 1, true) or version:find(".2207", 1, true)) then
      return false, "AMD driver 22.7.1 detected", "AMD driver 22.7.1 is known to have problems with running LÖVE (this includes Panel Attack). If the game fails to render its visuals, it is recommended to upgrade or downgrade your AMD GPU drivers."
    end
  end

  return true
end

function system.supportsFileBrowserOpen()
  local osString = love.system.getOS()

  if osString == "Android" then
    -- see https://www.love2d.org/wiki/love.system.openURL
    return false
  end

  return true
end

function system.supportsSaveDirectoryOpen()
  local osString = love.system.getOS()

  if osString == "iOS" then
    return false
  end

  return system.supportsFileBrowserOpen()
end

function system.getPathSeparator()
  return package.config:sub(1, 1)
end

function system.startDebugger()
  if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    -- VS Code / VS Codium
    require("lldebugger").start()
  elseif pcall(function() require("mobdebug") end) then
    -- ZeroBrane
    -- afaik there is no good way to detect whether the game was started with zerobrane other than trying the require and succeeding
    require("mobdebug").start()
    require('mobdebug').coro()
  end
end

return system