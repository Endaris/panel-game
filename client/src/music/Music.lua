local class = require("common.lib.class")
local musicThread = love.thread.newThread("client/src/music/PlayMusicThread.lua")
local FileUtils = require("client.src.FileUtils")
local logger = require("common.lib.logger")

local function playSource(source)
  if musicThread:isRunning() then
    musicThread:wait()
  end
  musicThread:start(source)
end

---@class Music
---@operator call:Music
---@field package mainDecoder love.Decoder
---@field package main love.SoundData looping source of the music
---@field package start love.SoundData? start source of the music
---@field package paused boolean if the music is currently paused
---@field package queueableSource love.Source
---@field package timeStarted number in seconds for love.timer.getTime
---@field package buffersize integer
---@field path string?
---@field mainFilename string?
---@field startFilename string?

-- construct a music object with a looping `main` music and an optional `start` played as the intro
---@class Music
---@overload fun(main: love.Decoder, start: love.SoundData?): Music
local Music = class(
---@param music Music
---@param mainDecoder love.Decoder
---@param startData love.SoundData?
function(music, mainDecoder, startData)
  music.mainDecoder = mainDecoder
  music.start = startData
  music.queueableSource = love.audio.newQueueableSource(mainDecoder:getSampleRate(), mainDecoder:getBitDepth(), mainDecoder:getChannelCount(), 8)

  music.timeStarted = 0
  music.paused = false
end)

Music.TYPE = "Music"
Music.buffersize = 4096

function Music:buffer()
  local freeBufferCount = self.queueableSource:getFreeBufferCount()
  for i = 1, freeBufferCount do
    local chunk = self.mainDecoder:decode()
    if not chunk then
      self.mainDecoder:seek(0)
      chunk = self.mainDecoder:decode()
    end
    self.queueableSource:queue(chunk)
  end
end

-- starts playing the music if it was not already playing
function Music:play()
  if not self.queueableSource:isPlaying() and not self.paused then
    if self.start then
      self.queueableSource:queue(self.start)
    end
    self:buffer()
  end

  logger.debug("playing " .. (self.path or "Unknown") .. "/" .. (self.mainFilename or "Unknown"))

  self.timeStarted = love.timer.getTime()
  playSource(self.queueableSource)
  self.paused = false
end

---@return boolean? # if the music is currently playing
function Music:isPlaying()
  return self.queueableSource:isPlaying()
end

-- stops the music and resets it (whether it was playing or not)
function Music:stop()
  self.paused = false
  self.queueableSource:stop()
  self.mainDecoder:seek(0)
end

-- pauses the music
function Music:pause()
  self.paused = true
  self.queueableSource:pause()
end

---@return boolean # if the music is currently paused
function Music:isPaused()
  return self.paused
end

---@param volume number sets the volume of the source to a specific number
function Music:setVolume(volume)
  self.queueableSource:setVolume(volume)
end

---@return number volume
function Music:getVolume()
  return self.queueableSource:getVolume()
end

-- update the music to advance the timer
-- this is important to try and (roughly) get the transition from start to main right
function Music:update()
  self:buffer()
end

---@param path string
---@param name string
---@return Music?
function Music.load(path, name)
  local startData
  local startName = FileUtils.getSoundFileName(name .. "_start", path)
  local mainName = FileUtils.getSoundFileName(name, path)

  if not mainName then
    return
  end

  if startName then
    startData = FileUtils.loadSoundDataFromSupportedExtensions(path, startName)
  end

  local mainDecoder = love.sound.newDecoder(mainName, Music.buffersize)

  if startData then
    if mainDecoder:getSampleRate() ~= startData:getSampleRate() or mainDecoder:getBitDepth() ~= startData:getBitDepth() or mainDecoder:getChannelCount() ~= startData:getChannelCount() then
      error("Failed to load music " .. name .. " for " .. path .. ":\n"
      .. "Sample rate, bit depth or channel count are different between " .. startName .. " and " .. mainName)
    end
  end

  if mainDecoder:getDuration() < 3 then
    error("Failed to load music " .. mainName .. " for " .. path .. ":\n"
    .. "The looping portion of music has to be at least 3 seconds long")
  end

  local m = Music(mainDecoder, startData)
  m.path = path
  m.mainFilename = mainName
  m.startFilename = startName
  return m
end

return Music