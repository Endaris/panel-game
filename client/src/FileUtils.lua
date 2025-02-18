local logger = require("common.lib.logger")
local Replay = require("common.data.Replay")
local tableUtils = require("common.lib.tableUtils")
local system = require("client.src.system")

local PREFIX_OF_IGNORED_DIRECTORIES = "__"

-- Collection of functions for file operations
local fileUtils = {}

fileUtils.SUPPORTED_IMAGE_FORMATS = {".png", ".jpg", ".jpeg"}
fileUtils.SUPPORTED_SOUND_FORMATS = {".mp3", ".ogg", ".wav", ".it", ".flac"}

-- returns the directory items with a default filter and an optional filetype filter
-- by default, filters out everything starting with __ and Mac's .DS_Store file
-- optionally the result can be filtered to return only "file" or "directory" items
---@param path string
---@param fileType ("file" | "directory")?
function fileUtils.getFilteredDirectoryItems(path, fileType)
  local results = {}

  local directoryList = love.filesystem.getDirectoryItems(path)
  for _, file in ipairs(directoryList) do

    local startOfFile = string.sub(file, 0, string.len(PREFIX_OF_IGNORED_DIRECTORIES))
   -- macOS sometimes puts these files in folders without warning, they are never useful for PA, so filter them.
    if startOfFile ~= PREFIX_OF_IGNORED_DIRECTORIES and file ~= ".DS_Store" then
      if not fileType or love.filesystem.getInfo(path .. "/" .. file, fileType) then
        results[#results+1] = file
      end
    end
  end

  return results
end

function fileUtils.getFileNameWithoutExtension(filename)
  return filename:gsub("%..*", "")
end

-- copies a file from the given source to the given destination
function fileUtils.copyFile(source, destination)
  local success
  local source_file, err = love.filesystem.read(source)
  success, err = love.filesystem.write(destination, source_file)
  return success, err
end

-- copies a file from the given source to the given destination
function fileUtils.recursiveCopy(source, destination, yields)
  local lfs = love.filesystem
  local names = lfs.getDirectoryItems(source)
  local temp
  for i, name in ipairs(names) do
    local info = lfs.getInfo(source .. "/" .. name)
    if info and info.type == "directory" then
      logger.trace("calling recursive_copy(source" .. "/" .. name .. ", " .. destination .. "/" .. name .. ")")
      fileUtils.recursiveCopy(source .. "/" .. name, destination .. "/" .. name, yields)
    elseif info and info.type == "file" then
      local destination_info = lfs.getInfo(destination)
      if not destination_info or destination_info.type ~= "directory" then
        love.filesystem.createDirectory(destination)
      end
      logger.trace("copying file:  " .. source .. "/" .. name .. " to " .. destination .. "/" .. name)

      local success, message = fileUtils.copyFile(source .. "/" .. name, destination .. "/" .. name)

      if not success then
        logger.warn(message)
      end
    else
      logger.warn("name:  " .. name .. " isn't a directory or file?")
    end
  end

  if yields then
    coroutine.yield("Copied\n" .. source .. "\nto\n" .. destination)
  end
end

-- Deletes any file matching the target name from the file tree recursively
function fileUtils.recursiveRemoveFiles(folder, targetName)
  local lfs = love.filesystem
  local filesTable = lfs.getDirectoryItems(folder)
  for _, fileName in ipairs(filesTable) do
    local file = folder .. "/" .. fileName
    local info = lfs.getInfo(file)
    if info then
      if info.type == "directory" then
        fileUtils.recursiveRemoveFiles(file, targetName)
      elseif info.type == "file" and fileName == targetName then
        love.filesystem.remove(file)
      end
    end
  end
end

-- returns the table for the deserialized json at the specified file path
---@param file string
---@return table? # nil if the file could not be read or deserialization failed
function fileUtils.readJsonFile(file)
  if not love.filesystem.getInfo(file, "file") then
    logger.debug("No file at specified path " .. file)
    return nil
  else
    local fileContent, info = love.filesystem.read(file)
    if type(info) == "string" then
      -- info is the number of read bytes if successful, otherwise an error string
      -- thus, if it is of type string, that indicates an error
      logger.warn("Could not read file at path " .. file)
      return nil
    else
      local value, _, errorMsg = json.decode(fileContent)
      if errorMsg then
        logger.error("Error reading " .. file .. ":\n" .. errorMsg .. ":\n" .. fileContent)
        return nil
      else
        ---@cast value table
        return value
      end
    end
  end
end

--returns a source, or nil if it could not find a file
---@param path_and_filename string
---@param streamed boolean?
---@return love.Source?
function fileUtils.loadSoundFromSupportExtensions(path_and_filename, streamed)
  for k, extension in ipairs(fileUtils.SUPPORTED_SOUND_FORMATS) do
    if love.filesystem.getInfo(path_and_filename .. extension) then
      return love.audio.newSource(path_and_filename .. extension, streamed and "stream" or "static")
    end
  end
  return nil
end

---@param path string
---@param filename string
---@return love.SoundData?
---@return string? exactFilename
function fileUtils.loadSoundDataFromSupportedExtensions(path, filename)
  for k, extension in ipairs(fileUtils.SUPPORTED_SOUND_FORMATS) do
    local fullPath = path .. "/" .. filename .. extension
    local info = love.filesystem.getInfo(fullPath)
    if info then
      local buffersize = 2048
      local decoder = love.sound.newDecoder(fullPath, buffersize)
      local sampleRate = decoder:getSampleRate()
      local chunks = {}
      -- interestingly enough, getDuration seems to return a "sensible", meaning to say one that likely does NOT consider jumps after reaching the end
      local duration = decoder:getDuration()
      local sampleLimit = duration * sampleRate
      local channelCount = decoder:getChannelCount()
      local chunk = decoder:decode()
      -- basically limiting decoding to files that were encoded to less than 0.2% of their real size (I think...a conservative limit anyway)
      local chunkLimit = math.ceil(info.size / buffersize) * 500
      local totalSampleCount = 0
      while chunk and #chunks <= chunkLimit and ((totalSampleCount < sampleLimit) or (sampleLimit < 0)) do
        totalSampleCount = totalSampleCount + chunk:getSampleCount()
        chunks[#chunks + 1] = chunk
        chunk = decoder:decode()
      end

      if chunk and #chunks > chunkLimit then
        error("Failed to load " .. fullPath ..
              "\ndata seems to loop infinitely")
      end

      local soundData = love.sound.newSoundData(totalSampleCount, sampleRate, decoder:getBitDepth(), channelCount)
      local position = 0
      if system.meetsLoveVersionRequirement(12, 0) then
        for i, chunk in ipairs(chunks) do
          local sampleCount = chunk:getSampleCount()
          if sampleLimit > 0 and position + sampleCount > sampleLimit then
            sampleCount = sampleLimit - position
          end
          soundData:copyFrom(chunk, 0, sampleCount, position)
          position = position + sampleCount
        end
      else
        for i, chunk in ipairs(chunks) do
          for j = 0, chunk:getSampleCount() - 1 do
            if position < sampleLimit or sampleLimit < 0 then
              for channel = 1, channelCount do
                local sample = chunk:getSample(j, channel)
                soundData:setSample(position, channel, sample)
              end
              position = position + 1
            end
          end
        end
      end

      return soundData, filename .. extension
    end
  end
end

-- returns a new sound effect if it can be found, else returns nil
---@param sound_name string the file name without extension we're looking for
---@param dirs_to_check string[] the directories that are searched for the file
---@param streamed boolean? true if the source should be loaded as a stream, false/nil if static
---@return love.Source?
function fileUtils.findSound(sound_name, dirs_to_check, streamed)
  streamed = streamed or false
  local found_source
  for k, dir in ipairs(dirs_to_check) do
    found_source = fileUtils.loadSoundFromSupportExtensions(dir .. sound_name, streamed)
    if found_source then
      return found_source
    end
  end
  return nil
end

function fileUtils.soundFileExists(soundName, path)
  for _, extension in pairs(fileUtils.SUPPORTED_SOUND_FORMATS) do
    if love.filesystem.getInfo(path .. "/" .. soundName .. extension, "file") then
      return true
    end
  end

  return false
end

function fileUtils.saveTextureToFile(texture, filePath, format)
  local loveMajor = love.getVersion()

  local imageData
  if loveMajor >= 12 then
    imageData = love.graphics.readbackTexture(texture)
  else
    -- this code branch is untested but the function is also not used in production at the moment
    if texture:typeOf("Canvas") then
      imageData = texture:newImageData()
    else
      local canvas = love.graphics.newCanvas(texture:getDimensions())
      local currentCanvas = love.graphics.getCanvas()
      love.graphics.setCanvas(canvas)
      love.graphics.draw(texture)
      love.graphics.setCanvas(currentCanvas)
      imageData = canvas:newImageData()
    end
  end

  local data = imageData:encode(format)
  love.filesystem.write(filePath .. "." .. format, data)
end

---@param replay Replay
function fileUtils.saveReplay(replay)
  local path = replay:generatePath("/")
  local filename = replay:generateFileName()
  -- TODO: This is for legacy support of the replay browser only;
  -- as Replay is a common.data object, client should not use it to write client specific fields
  Replay.lastPath = path
  fileUtils.writeJson(path, filename .. ".json", replay)
end

---@param files string[]
---@param pattern string
---@param validExtensions string[]
---@param separator string?
---@return string[] # files filtered down to only strings matching the specified pattern, separator and valid extension list
function fileUtils.getMatchingFiles(files, pattern, validExtensions, separator)
  separator = separator or ""
  local stringLen = string.len(pattern)
  local matchedFiles = tableUtils.filter(files,
  function(file)
    local startIndex, endIndex = string.find(file, pattern, nil, true)
    if not startIndex then
      return false
    elseif startIndex > 1 then
      -- this means the name is prefixed with something else
      return false
    else
      local goodExtension
      -- this check is doubly good because it enforces lower case extensions even on windows
      for i, extension in ipairs(validExtensions) do
        local length = extension:len()
        if file:sub(-length) == extension then
          goodExtension = extension
          break
        end
      end
      if not goodExtension then
        return false
      else
        -- now check for actual exact matching:
        -- first cut off the matching part
        local middlePart = file:sub(stringLen + 1)
        -- and then the extension
        middlePart = middlePart:sub(1, - goodExtension:len() - 1)
        if middlePart:len() == 0 then
          -- this is just the exact pattern + file extension
          return true
        else
          local sepLen = separator:len()
          if middlePart:sub(1, sepLen) ~= separator then
            return false
          else
            local numberPart = middlePart:sub(sepLen + 1)
            -- we need to string.match on top of casting tonumber because of Lua accepting scientific notation strings as numbers
            if string.match(numberPart, "%d+") == numberPart and tonumber(numberPart) then
              -- there are really only digits that form a number in the number part
              return true
            else
              return false
            end
          end
        end
      end
    end
  end)

  return matchedFiles
end

---@param path string
---@param data string
function fileUtils.write(path, filename, data)
  love.filesystem.createDirectory(path)
  local success, message = love.filesystem.write(path .. "/" .. filename, data)
  if not success then
    error("Failed to write to " .. path .. " : " .. message)
  end
end

---@param path string
---@param filename string
---@param tab table
---@param encodeArgs ({indent: boolean, keyorder: string[], level: integer} | nil)
function fileUtils.writeJson(path, filename, tab, encodeArgs)
  local encoded = json.encode(tab, encodeArgs)
  ---@cast encoded string # json.encode always returns a string if the second argument does not contain the buffer field
  fileUtils.write(path, filename, encoded)
end

return fileUtils