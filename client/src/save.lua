local inputManager = require("common.lib.inputManager")
local fileUtils = require("client.src.FileUtils")
local logger = require("common.lib.logger")

-- the save.lua file contains the read/write functions

local sep = package.config:sub(1, 1) --determines os directory separator (i.e. "/" or "\")

local save = {}

-- writes to the "keys.txt" file
function write_key_file()
  pcall(
    function()
      love.filesystem.write("keysV3.json", json.encode(inputManager:getSaveKeyMap()))
    end
  )
end

-- reads the "keys.txt" file
function save.read_key_file()
  local filename
  local migrateInputs = false

  if love.filesystem.getInfo("keysV3.json", "file") then
    filename = "keysV3.json"
  else
    filename = "keysV2.txt"
    migrateInputs = true
  end

  if not love.filesystem.getInfo(filename, "file") then
    return inputManager.inputConfigurations
  else
    local inputConfigs = fileUtils.readJsonFile(filename)

    if migrateInputs then
      -- migrate old input configs
      inputConfigs = inputManager:migrateInputConfigs(inputConfigs)
    end

    return inputConfigs
  end
end

-- reads the .txt file of the given path and filename
function save.read_txt_file(path_and_filename)
  local s
  s = love.filesystem.read(path_and_filename)
  if not s then
    s = "Failed to read file " .. path_and_filename
  else
    s = s:gsub("\r\n?", "\n")
  end
  return s or "Failed to read file"
end

-- writes to the "user_id.txt" file of the directory of the connected ip
function write_user_id_file(userID, serverIP)
  pcall(
    function()
      love.filesystem.createDirectory("servers/" .. serverIP)
      love.filesystem.write("servers/" .. serverIP .. "/user_id.txt", tostring(userID))
    end
  )
end

-- reads the "user_id.txt" file of the directory of the connected ip
function read_user_id_file(serverIP)
  local userID
  pcall(
    function()
      userID = love.filesystem.read("servers/" .. serverIP .. "/user_id.txt")
      userID = userID:match("^%s*(.-)%s*$")
    end
  )
  return userID
end

function readAttackFile(path)
  if love.filesystem.getInfo(path, "file") then
    local jsonData = love.filesystem.read(path)
    local trainingConf, position, errorMsg = json.decode(jsonData)
    if trainingConf then
      if not trainingConf.name or type(trainingConf.name) ~= "string" then
        local filenameOnly = path:match('%' .. sep .. '?(.*)$')
        if filenameOnly ~= nil then
          trainingConf.name = fileUtils.getFileNameWithoutExtension(filenameOnly)
        end
      end
      return trainingConf
    else
      error("Error deserializing " .. path .. ": " .. errorMsg .. " at position " .. position)
    end
  end
end

function readAttackFiles(path)
  local results = {}
  local lfs = love.filesystem
  local raw_dir_list = fileUtils.getFilteredDirectoryItems(path)
  for _, v in ipairs(raw_dir_list) do
    local current_path = path .. "/" .. v
    if lfs.getInfo(current_path) then
      if lfs.getInfo(current_path).type == "directory" then
        readAttackFiles(current_path)
      else
        local training_conf = readAttackFile(current_path)
        if training_conf ~= nil then
          results[#results+1] = training_conf
        end
      end
    end
  end

  return results
end

function saveJSONToPath(data, state, path)
  love.filesystem.write(path, json.encode(data, state))
end

function print_list(t)
  for i, v in ipairs(t) do
    print(v)
  end
end

return save