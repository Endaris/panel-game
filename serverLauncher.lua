local util = require("common.lib.util")
util.addToCPath("./common/lib/??")
util.addToCPath("./server/lib/??")
local logger = require("common.lib.logger")

if arg[1] == "debug" then
  -- for debugging in visual studio code
  if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    -- VS Code / VS Codium
    require("lldebugger").start()
  elseif pcall(function() require("mobdebug") end) then
    -- ZeroBrane
    -- afaik there is no good way to detect whether the game was started with zerobrane other than trying the require and succeeding
    require("mobdebug").start()
    require('mobdebug').coro()
  end
  logger.setLogLevel(logger.levels.DEBUG)
else
  logger.setLogLevel(logger.levels.INFO)
end

-- We must launch the server from the root directory so all the requires are the right path relatively.
require("server.server_globals")
require("server.tests.LoginTests")
require("server.tests.ServerTests")
require("server.tests.LeaderboardTests")
require("server.tests.RoomTests")
require("server.tests.ScoreVerifierTests")

local Server = require("server.server")
local Persistence = require("server.Persistence")

-- so that seeds don't repeat after each server restart
math.randomseed(os.time())

Persistence.initialize(Persistence.modes.FILE, "PADatabase.sqlite3", "players.txt")
local server = Server(Persistence)
server:start()

while true do
  server:update()
end