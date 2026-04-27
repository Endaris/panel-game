local FileIO = require("server.FileIO")
local Queue = require("common.lib.Queue")
local ReplayV3 = require("common.data.ReplayV3")
local Match = require("common.engine.Match")
local tableUtils = require("common.lib.tableUtils")

FileIO.makeLocalDirectory("ScoreVerifier")

---@class ScoreVerifier.WorkItem
---@field replay ReplayV3
---@field filePath string
---@field publicId PublicPlayerID
---@field claimedScore integer
---@field verifiedScore integer?

---@class ScoreVerifier
---@field todo Queue<ScoreVerifier.WorkItem>
---@field current ScoreVerifier.WorkItem?
---@field match Match
---@field stack Stack
---@field expectedDuration integer
---@field steps integer
---@field done Queue<ScoreVerifier.WorkItem>
local ScoreVerifier = {
  todo = Queue(),
  current = nil,
  done = Queue(),
}

---@param replay ReplayV3
function ScoreVerifier:queueReplay(replay, publicPlayerId, score)
  local foundPlayer = false
  for _, stackMetadata in ipairs(replay.metadata.stacks) do
    ---@cast stackMetadata StackMetadata
    if stackMetadata.publicId == publicPlayerId then
      stackMetadata.analytics = stackMetadata.analytics or {}
      stackMetadata.analytics.score = score
      foundPlayer = true
    end
  end

  if foundPlayer then
    local filePath = FileIO.saveReplayForVerification(replay, publicPlayerId)
    self.todo:push({replay = replay, publicId = publicPlayerId, filePath = filePath, claimedScore = score})
  else
    -- TODO: Probably save the replay elsewhere?
    -- there's nothing actionable here but it would be good to have the data for posteriority and troubleshooting if something goes wrong
  end
end

function ScoreVerifier:recoverQueueFromFiles()
  local items = FileIO.getDirectoryItems(FileIO.combinePath(".", "ScoreVerifier"))

  for i, item in ipairs(items) do
    local path = FileIO.combinePath(".", "ScoreVerifier", item)
    local jsonContent = FileIO.readJson(path)
    local publicPlayerIdString = string.gsub(item, "(%S+_(%d+)%.json)", "%2", 1)
    local publicPlayerId = tonumber(publicPlayerIdString)
    if jsonContent and publicPlayerId then
      local replay = ReplayV3.createFromTable(jsonContent, true)
      if replay then
        local claimedScore
        for _, stackMetadata in ipairs(replay.metadata.stacks) do
          ---@cast stackMetadata StackMetadata
          if stackMetadata.publicId == publicPlayerId and stackMetadata.analytics then
            claimedScore = stackMetadata.analytics.score
          end
        end
        if publicPlayerId and claimedScore then
          self.todo:push({replay = replay, publicId = publicPlayerId, filepath = path, claimedScore = claimedScore})
        end
      end
    end
  end
end

---@param workItem ScoreVerifier.WorkItem
function ScoreVerifier:__setup(workItem)
  self.current = workItem
  local stackMetadata = tableUtils.first(workItem.replay.metadata.stacks, function(s) return s.publicId == workItem.publicId end)
  self.match = Match.createFromReplay(workItem.replay)
  self.stack = self.match.stacks[stackMetadata.stackIndex]
  self.match:setAlwaysSaveRollbacks(false)
  self.match:start()
  for _, stack in ipairs(self.match.stacks) do
    -- only one step at a time
    stack:setMaxRunsPerFrame(1)
  end

  local expectedDuration
  -- the input counts may differ between players as when losing locally, the opponent keeps playing until simulating your loss
  --  we want the higher of the two as additional scoring might happen for the living player while the game over was in transit
  --  the replay may also store a duration as metadata but it chooses the lower number which makes sense for VS but not as much for score based game modes
  for _, stack in ipairs(self.match.stacks) do
    if stack.TYPE == "Stack" then
      ---@cast stack Stack
      if expectedDuration then
        expectedDuration = math.max(expectedDuration, #stack.confirmedInput)
      else
        expectedDuration = #stack.confirmedInput
      end
    end
  end

  self.expectedDuration = expectedDuration
  self.steps = 0
end

function ScoreVerifier:__step()
  if self.match:hasEnded() then
    self:__finish()
    self:__cleanupCurrent()
  else
    if self.steps <= self.expectedDuration then
      self.match:run()
      self.steps = self.steps + 1
    else
      -- there's a problem with the replay
      self:__markForReview()
      self:__cleanupCurrent()
    end
  end
end

function ScoreVerifier:__finish()
  self.current.verifiedScore = self.stack.score
  self.done:push(self.current)
end

function ScoreVerifier:__markForReview()
  -- TODO: move the replay into a different directory
end

function ScoreVerifier:__cleanupCurrent()
  for _, stack in ipairs(self.match.stacks) do
    if stack.TYPE == "Stack" then
      ---@cast stack Stack
      stack:deinit()
    end
  end

  self.stack = nil
  self.match = nil
  self.expectedDuration = nil
  self.steps = nil
  self.current = nil
end

function ScoreVerifier:step()
  if self.current then
    self:__step()
  else
    if self.todo:len() > 0 then
      local nextItem = self.todo:pop()
      self:__setup(nextItem)
    end
  end  
end

return ScoreVerifier