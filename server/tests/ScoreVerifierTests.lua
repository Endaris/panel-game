local ScoreVerifier = require("server.ScoreVerifier")
local ReplayV3 = require("common.data.ReplayV3")
local FileIO = require("server.FileIO")
local tableUtils = require("common.lib.tableUtils")

local replayPath = FileIO.combinePath("server", "tests", "replays")

local function cleanUpRecoveryDirectory()
  items = FileIO.getDirectoryItems("ScoreVerifier")
  for i, item in ipairs(items) do
    os.remove(FileIO.combinePath("ScoreVerifier", item))
  end
end

local function testRecovery()
  local items = FileIO.getDirectoryItems(replayPath)

  for i, item in ipairs(items) do
    FileIO.copyItem(FileIO.combinePath(replayPath, item), FileIO.combinePath("ScoreVerifier", item))
  end
  
  ScoreVerifier:recoverQueueFromFiles()

  assert(ScoreVerifier.todo:len() == 3)
  for i = ScoreVerifier.todo.first, ScoreVerifier.todo.last do
    assert(ScoreVerifier.todo[i].publicId == 5912)
    assert(ScoreVerifier.todo[i].verifiedScore == nil)
    assert(ScoreVerifier.todo[i].claimedScore and tonumber(ScoreVerifier.todo[i].claimedScore))
    assert(ScoreVerifier.todo[i].replay)
    assert(tonumber(ScoreVerifier.todo[i].claimedScore) == ScoreVerifier.todo[i].replay.metadata.stacks[1].analytics.score)
  end

  ScoreVerifier.todo:clear()
  cleanUpRecoveryDirectory()
end

local function testQueueing()
  local jsonContent = FileIO.readJson(FileIO.combinePath(replayPath, "v049-2026-04-11-02-21-02-Devdaris55ne5-L10-timeattack_5912.json"))
  local replay = ReplayV3.createFromTable(jsonContent, true)
  ScoreVerifier:queueReplay(replay, 5912, 21599)

  assert(ScoreVerifier.todo:len() == 1)
  local first = ScoreVerifier.todo.first
  assert(ScoreVerifier.todo[first].claimedScore == 21599)
  assert(ScoreVerifier.todo[first].publicId == 5912)
  assert(ScoreVerifier.todo[first].verifiedScore == nil)
  assert(ScoreVerifier.todo[first].replay == replay)
  assert(FileIO.fileExists(ScoreVerifier.todo[first].filePath))

  ScoreVerifier.todo:clear()
  cleanUpRecoveryDirectory()
end

local function testVerification()
  local jsonContent = FileIO.readJson(FileIO.combinePath(replayPath,"v049-2026-04-11-02-21-02-Devdaris55ne5-L10-timeattack_5912.json"))
  local replay = ReplayV3.createFromTable(jsonContent, true)
  ScoreVerifier:queueReplay(replay, 5912, 21599)

  while ScoreVerifier.todo:len() > 0 or ScoreVerifier.current ~= nil do
    ScoreVerifier:step()
  end

  assert(ScoreVerifier.todo:len() == 0)
  assert(ScoreVerifier.done:len() == 1)
  local first = ScoreVerifier.done.first
  assert(ScoreVerifier.done[first].claimedScore == 21599)
  assert(ScoreVerifier.done[first].publicId == 5912)
  assert(ScoreVerifier.done[first].replay == replay)
  assert(ScoreVerifier.done[first].verifiedScore == 21599)
  -- file cleanup is the responsibility of whoever clears out the entry from the done table, so this still ought to be here
  assert(FileIO.fileExists(ScoreVerifier.done[first].filePath))

  ScoreVerifier.todo:clear()
  ScoreVerifier.done:clear()
  cleanUpRecoveryDirectory()
end

testRecovery()
testQueueing()
testVerification()