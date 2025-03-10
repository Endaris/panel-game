local class = require("common.lib.class")
local ClientMessages = require("common.network.ClientProtocol")
local save = require("client.src.save")

-- abstraction level function
-- returns things as a parameter list so the API in ClientProtocol can be more explicit about which parameters it expects
--  (which it cannot if things are passed as tables)
local function toLoginData(configuration, localPlayer)
  local ps = localPlayer.settings
  local c = configuration
  return
    c.name,
    ps.level,
    ps.inputMethod,
    ps.panels,
    ps.selectedCharacterId,
    ps.characterId,
    ps.selectedStageId,
    ps.stageId,
    ps.wantsRanked,
    c.save_replays_publicly
end

-- returns true/false as the first return value to indicate success or failure of the login
-- returns a string with a message to display for the user
-- not meant to be called directly as it may block update for a good while, hence local, use the LoginRoutine instead!
local function login(tcpClient, ip, port)
  local result = {loggedIn = false, message = ""}

  if not tcpClient:connectToServer(ip, port) then
    result.loggedIn = false
    result.message = loc("ss_could_not_connect")
    return result
  else
    -- this should also probably be elsewhere
    GAME.connected_server_ip = ip
    GAME.connected_server_port = port

    local response = tcpClient:sendRequest(ClientMessages.requestVersionCompatibilityCheck())
    local status, value = response:tryGetValue()
    while status == "waiting" do
      coroutine.yield("Checking version compatibility with the server")
      status, value = response:tryGetValue()
    end

    if status == "timeout" then
      result.loggedIn = false
      result.message = loc("nt_conn_timeout")
      return result
    elseif status == "received" then
      if not value.versionCompatible then
        result.loggedIn = false
        result.message = loc("nt_ver_err")
        return result
      else
        local userId = save.read_user_id_file(ip)
        if not userId then
          userId = "need a new user id"
        end

        response = tcpClient:sendRequest(ClientMessages.requestLogin(userId, toLoginData(config, GAME.localPlayer)))
        status, value = response:tryGetValue()
        while status == "waiting" do
          coroutine.yield("Logging in")
          status, value = response:tryGetValue()
        end

        if status == "timeout" then
          result.loggedIn = false
          result.message = loc("nt_conn_timeout")
          return result
        elseif status == "received" then
          if value.login_successful then
            result.loggedIn = true
            if value.new_user_id then
              save.write_user_id_file(value.new_user_id, GAME.connected_server_ip)
              result.message = loc("lb_user_new", config.name)
            elseif value.name_changed then
              result.message = loc("lb_user_update", value.old_name, value.new_name)
            else
              result.message = loc("lb_welcome_back", config.name)
            end
            if value.server_notice then
              result.message = result.message .. "\n" value.server_notice:gsub("\\n", "\n")
            end
            if value.publicId then
              GAME.localPlayer.publicId = value.publicId
            end

            return result
          else --if result.login_denied then
            result.loggedIn = false
            result.message = loc("lb_error_msg") .. "\n" .. value.reason
            if value.ban_duration then
              result.message = result.message .. "\n" .. value.ban_duration
            end
            return result
          end
        else
          error("Unexpected status " .. status .. " trying to login with user id on the server " .. ip)
        end
      end
    else
      error("Unexpected status " .. status .. " trying to verify version compatibility with the server " .. ip)
    end
  end
end

-- A wrapper class around the login process
-- Allows to advance the login process bit by bit via calling progress
local LoginRoutine = class(function(self, tcpClient, ip, port)
  self.tcpClient = tcpClient
  self.routine = coroutine.create(login)
  self.ip = ip
  self.port = port
end)

-- returns false and the current progress of the login process as a string message while in progress
-- returns true and a result table {loggedIn = val, message = "msg"} when finishing and on further queries
function LoginRoutine:progress()
  if coroutine.status(self.routine) == "dead" then
    return true, self.result
  else
    local success, status = coroutine.resume(self.routine, self.tcpClient, self.ip, self.port)
    if success then
      if type(status) == "table" then
        self.result = status
        if self.result.loggedIn == false then
          self.tcpClient:resetNetwork()
        end
        return true, status
      else
        self.status = status
        return false, status
      end
    else
      GAME.crashTrace = debug.traceback(self.routine)
      error(status)
    end
  end
end


return LoginRoutine