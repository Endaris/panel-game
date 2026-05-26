local logger = require("common.lib.logger")
local sqlite3 = require("lsqlite3")

---@class SqliteDB
---@field exec function
---@field errmsg function
---@field prepare fun(self: SqliteDB, statement: string): PreparedStatement
---@field last_insert_rowid function

---@class PreparedStatement
---@field bind fun(self: PreparedStatement, n: integer, value: any): integer Binds value to statement parameter n. If the type of value is string it is bound as text. If the type of value is number, then with Lua prior to 5.3 it is bound as a double, with Lua 5.3 it is bound as an integer or double depending on its subtype using lua_isinteger. If value is a boolean then it is bound as 0 for false or 1 for true. If value is nil or missing, any previous binding is removed. 
---@field bind_values fun(self: PreparedStatement, ...: any): integer Binds values to statement parameters in order
---@field step fun(self: PreparedStatement) executes the prepared statement; reset needs to be called before it can be used again
---@field reset fun(self: PreparedStatement): integer resets the statement, so that it is ready to be re-executed. Any statement variables that had values bound to them using the stmt:bind*() functions retain their values.
---@field nrows fun(self:PreparedStatement): fun() Returns an function that iterates over the names and values of the result set of the statement. Each iteration returns a table with the names and values for the current row. 
---@field rows fun(self:PreparedStatement): fun() Returns an function that iterates over the values of the result set of the statement. Each iteration returns an array with the values for the current row.

---@alias BanID integer
---@alias DB_Ban {banID: BanID, reason: string, completionTime: integer}
---@alias DB_Player {publicPlayerID: integer, privatePlayerID: integer, username: string, lastLoginTime: integer}

---@class ServerDB
---@field db SqliteDB
---@field statements table<string, PreparedStatement>
local PADatabase = { statements = {} }

function PADatabase:initialize(path)
  self.db = sqlite3.open(path) -- "PADatabase.sqlite3"
  self:createTables()
  self:createPreparedStatements()
  return self
end

function PADatabase:createTables()
  self.db:exec[[
    PRAGMA foreign_keys = ON;
    
    CREATE TABLE IF NOT EXISTS Player(
      publicPlayerID INTEGER PRIMARY KEY AUTOINCREMENT,
      privatePlayerID INTEGER NOT NULL UNIQUE,
      username TEXT NOT NULL,
      lastLoginTime TIME TIMESTAMP DEFAULT (strftime('%s', 'now'))
    );
    
    CREATE TABLE IF NOT EXISTS Game(
      gameID INTEGER PRIMARY KEY AUTOINCREMENT,
      ranked BOOLEAN NOT NULL CHECK (ranked IN (0, 1)),
      timePlayed TIME TIMESTAMP NOT NULL DEFAULT (strftime('%s', 'now'))
    );
    
    INSERT OR IGNORE INTO Game(gameID, ranked) VALUES (0, 1); -- Placeholder game for imported Elo history
    
    CREATE TABLE IF NOT EXISTS PlayerGameResult(
      publicPlayerID INTEGER NOT NULL,
      gameID INTEGER NOT NULL,
      level INTEGER,
      placement INTEGER NOT NULL,
      FOREIGN KEY(publicPlayerID) REFERENCES Player(publicPlayerID),
      FOREIGN KEY(gameID) REFERENCES Game(gameID)
    );
    
    CREATE TABLE IF NOT EXISTS PlayerELOHistory(
      publicPlayerID INTEGER,
      rating REAL NOT NULL,
      gameID INTEGER NOT NULL,
      FOREIGN KEY(gameID) REFERENCES Game(gameID)
    );
    
    CREATE TABLE IF NOT EXISTS PlayerMessageList(
      messageID INTEGER PRIMARY KEY NOT NULL,
      publicPlayerID INTEGER NOT NULL,
      message TEXT NOT NULL,
      messageSeen TIME TIMESTAMP,
      FOREIGN KEY(publicPlayerID) REFERENCES Player(publicPlayerID)
    );
    
    CREATE TABLE IF NOT EXISTS IPID(
      ip TEXT NOT NULL,
      publicPlayerID INTEGER NOT NULL,
      PRIMARY KEY(ip, publicPlayerID),
      FOREIGN KEY(publicPlayerID) REFERENCES Player(publicPlayerID)
    );
    
    CREATE TABLE IF NOT EXISTS PlayerBanList(
      banID INTEGER PRIMARY KEY NOT NULL,
      ip TEXT, 
      publicPlayerID INTEGER,
      reason TEXT NOT NULL,
      completionTime INTEGER,
      banSeen TIME TIMESTAMP,
      FOREIGN KEY(publicPlayerID) REFERENCES Player(publicPlayerID)
    );

    CREATE TABLE IF NOT EXISTS GameModes(
      ID INTEGER PRIMARY KEY AUTOINCREMENT,
      GameModeID TEXT NOT NULL UNIQUE
    );

    INSERT OR IGNORE GameModes(GameModeID)
    VALUES ('TWO_PLAYER_VS'), ('TWO_PLAYER_TIME_ATTACK'), ('ONE_PLAYER_TIME_ATTACK')
    ;
    ]]
end

function PADatabase:createPreparedStatements()
  ---@class ServerDB # for intellisense F12 elsewhere
  self = self
  self.statements.getPlayerData = assert(self.db:prepare("SELECT * FROM PLAYER ORDER BY publicPlayerID"))
  self.statements.insertNewPlayer = assert(self.db:prepare("INSERT OR IGNORE INTO Player(privatePlayerID, username) VALUES (?, ?)"))
  self.statements.selectPlayerByPrivateId = assert(self.db:prepare("SELECT * FROM Player WHERE privatePlayerID = ?"))
  self.statements.updateUserNameByPrivateId = assert(self.db:prepare("UPDATE Player SET username = ? WHERE privatePlayerID = ?"))
  self.statements.insertPlayerEloUpdateByPrivateId = assert(self.db:prepare("INSERT INTO PlayerELOHistory(publicPlayerID, rating, gameID) VALUES ((SELECT publicPlayerID FROM Player WHERE privatePlayerID = ?), ?, ?)"))
  self.statements.getPlayerCount = assert(self.db:prepare("SELECT COUNT(*) FROM Player"))
  self.statements.insertGame = assert(self.db:prepare("INSERT INTO Game(ranked) VALUES (?)"))
  self.statements.insertPlayerGameResult = assert(self.db:prepare("INSERT INTO PlayerGameResult(publicPlayerID, gameID, level, placement) VALUES ((SELECT publicPlayerID FROM Player WHERE privatePlayerID = ?), ?, ?, ?)"))
  self.statements.selectUnseenMessagesByPublicId = assert(self.db:prepare("SELECT messageID, message FROM PlayerMessageList WHERE publicPlayerID = ? AND messageSeen IS NULL"))
  self.statements.updatePlayerMessageSeen = assert(self.db:prepare("UPDATE PlayerMessageList SET messageSeen = strftime('%s', 'now') WHERE messageID = ?"))
  self.statements.insertIpBan = assert(self.db:prepare("INSERT INTO PlayerBanList(ip, reason, completionTime) VALUES (?, ?, ?)"))
  self.statements.insertIPID = assert(self.db:prepare("INSERT OR IGNORE INTO IPID(ip, publicPlayerID) VALUES (?, ?)"))
  self.statements.selectPublicIDsByIP = assert(self.db:prepare("SELECT publicPlayerID FROM IPID WHERE ip = ?"))
  self.statements.selectIPBans = assert(self.db:prepare("SELECT banID, reason, completionTime FROM PlayerBanList WHERE ip = ?"))
  self.statements.selectIDBans = assert(self.db:prepare("SELECT banID, reason, completionTime FROM PlayerBanList WHERE publicPlayerID = ?"))
  self.statements.selectUnseenBansByPublicId = assert(self.db:prepare("SELECT banID, reason FROM PlayerBanList WHERE publicPlayerID = ? AND banSeen IS NULL"))
  self.statements.updatePlayerBanSeen = assert(self.db:prepare("UPDATE PlayerBanList SET banSeen = strftime('%s', 'now') WHERE banID = ?"))
end

---@return DB_Player[]?
function PADatabase:getPlayerData()
  local players = {}
  
  for row in self.statements.getPlayerData:nrows() do
    players[#players+1] = row
  end

  if self.statements.selectPlayerByPrivateId:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return nil
  end

  return players
end

-- Inserts a new player into the database, ignores the statement if the ID is already used.
---@param privatePlayerID privateUserId
---@param username string
---@return boolean # if the player was successfully inserted
function PADatabase:insertNewPlayer(privatePlayerID, username)
  self.statements.insertNewPlayer:bind_values(privatePlayerID, username)
  self.statements.insertNewPlayer:step()
  if self.statements.insertNewPlayer:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return false
  end
  return true
end

-- Retrieves the player from the privatePlayerID
---@param privatePlayerID privateUserId
---@return DB_Player?
function PADatabase:getPlayerFromPrivateID(privatePlayerID)
  assert(privatePlayerID ~= nil)
  self.statements.selectPlayerByPrivateId:bind_values(privatePlayerID)
  local player = nil
  for row in self.statements.selectPlayerByPrivateId:nrows() do
    player = row
    break
  end
  if self.statements.selectPlayerByPrivateId:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return nil
  end
  return player
end

-- Updates the username of a player in the database based on their privatePlayerID.
---@param privatePlayerID privateUserId
---@param username string
---@return boolean success if the update of the name was successful
function PADatabase:updatePlayerUsername(privatePlayerID, username)
  self.statements.updateUserNameByPrivateId:bind_values(username, privatePlayerID)
  self.statements.updateUserNameByPrivateId:step()
  if self.statements.updateUserNameByPrivateId:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return false
  end
  return true
end

-- Inserts a change of a Player's elo.
---@param privatePlayerID privateUserId
---@param rating number
---@param gameID integer
---@return boolean success if the rating change was successfully inserted
function PADatabase:insertPlayerELOChange(privatePlayerID, rating, gameID)
  self.statements.insertPlayerEloUpdateByPrivateId:bind_values(privatePlayerID, rating or 1500, gameID)
  self.statements.insertPlayerEloUpdateByPrivateId:step()
  if self.statements.insertPlayerEloUpdateByPrivateId:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return false
  end
  return true
end

-- Returns the amount of players in the Player database.
---@return integer?
function PADatabase:getPlayerRecordCount()
  local result = nil
  for row in self.statements.getPlayerCount:rows() do
    result = row[1]
    break
  end
  if self.statements.getPlayerCount:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return nil
  end
  return result
end

---@param ranked boolean if the game is ranked
---@return integer? gameID
function PADatabase:insertGame(ranked)
  self.statements.insertGame:bind_values(ranked and 1 or 0)
  self.statements.insertGame:step()
  if self.statements.insertGame:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return nil
  end
  return self.db:last_insert_rowid()
end

-- Inserts the results of a game.
---@param privatePlayerID privateUserId
---@param gameID integer
---@param level integer? The level preset the player used, can be nil
---@param placement integer The placement for the player with the user id amongst all players in that game \n
--- placement 1 marks the winner
---@return boolean success
function PADatabase:insertPlayerGameResult(privatePlayerID, gameID, level, placement)
  self.statements.insertPlayerGameResult:bind_values(privatePlayerID, gameID, level, placement)
  self.statements.insertPlayerGameResult:step()
  if self.statements.insertPlayerGameResult:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return false
  end
  return true
end

-- Retrieves player messages that the player has not seen yet.
---@param publicPlayerID integer
---@return table<integer, string> messages
function PADatabase:getPlayerMessages(publicPlayerID)
  self.statements.selectUnseenMessagesByPublicId:bind_values(publicPlayerID)
  local playerMessages = {}
  for row in self.statements.selectUnseenMessagesByPublicId:nrows() do
    playerMessages[row.messageID] = row.message
  end
  if self.statements.selectUnseenMessagesByPublicId:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return {}
  end
  return playerMessages
end

-- Marks a message as seen by a player.
---@param messageID integer
---@return boolean success
function PADatabase:playerMessageSeen(messageID)
  self.statements.updatePlayerMessageSeen:bind_values(messageID)
  self.statements.updatePlayerMessageSeen:step()
  if self.statements.updatePlayerMessageSeen:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return false
  end
  return true
end

-- Bans an IP address
---@param ip string
---@param reason string
---@param completionTime integer
---@return DB_Ban?
function PADatabase:insertBan(ip, reason, completionTime)
  self.statements.insertBan:bind_values(ip, reason, completionTime)
  self.statements.insertBan:step()
  if self.statements.insertBan:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return
  end
  return {banID = self.db:last_insert_rowid(), reason = reason, completionTime = completionTime}
end

-- Maps an IP address to a publicPlayerID.
---@param ip string
---@param publicPlayerID integer
---@return boolean success
function PADatabase:insertIPID(ip, publicPlayerID)
  self.statements.insertIPID:bind_values(ip, publicPlayerID)
  self.statements.insertIPID:step()
  if self.statements.insertIPID:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return false
  end
  return true
end

---@param ip string
---@return integer[] # all publicPlayerIDs that have been used with the given IP address
function PADatabase:getIPIDS(ip)
  self.statements.selectPublicIDsByIP:bind_values(ip)
  local publicPlayerIDs = {}
  for row in self.statements.selectPublicIDsByIP:nrows() do
    publicPlayerIDs[#publicPlayerIDs+1] = row.publicPlayerID
  end
  if self.statements.selectPublicIDsByIP:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return {}
  end
  return publicPlayerIDs
end

-- Selects all bans associated with the ip given.
---@param ip string
---@return DB_Ban[]
function PADatabase:getIPBans(ip)
  self.statements.selectIPBans:bind_values(ip)
  local bans = {}
  for row in self.statements.selectIPBans:nrows() do
    bans[#bans+1] = {banID = row.banID, reason = row.reason, completionTime = row.completionTime}
  end
  if self.statements.selectIPBans:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return {}
  end
  return bans
end

-- Selects all bans associated with the publicPlayerID given.
---@param publicPlayerID integer
---@return DB_Ban[]
function PADatabase:getIDBans(publicPlayerID)
  self.statements.selectIDBans:bind_values(publicPlayerID)
  local bans = {}
  for row in self.statements.selectIDBans:nrows() do
    bans[#bans+1] = {banID = row.banID, reason = row.reason, completionTime = row.completionTime}
  end
  if self.statements.selectIDBans:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return {}
  end
  return bans
end

-- Checks if a logging in player is banned based off their IP.
---@param ip string
---@return DB_Ban?
function PADatabase:getBanByIP(ip)
  -- all ids associated with the information given
  local publicPlayerIDs = {}
  if ip then
    publicPlayerIDs = self:getIPIDS(ip)
  end

  local bans = {}
  local ipBans = self:getIPBans(ip)
  for banID, ban in ipairs(ipBans) do
    bans[banID] = ban
  end

  for _, id in pairs(publicPlayerIDs) do
    for banID, ban in ipairs(self:getIDBans(id)) do
      bans[banID] = ban
    end
  end

  local longestBan = nil
  for _, ban in pairs(bans) do
    if (os.time() < ban.completionTime) and ((not longestBan) or (ban.completionTime > longestBan.completionTime)) then
      longestBan = ban
    end
  end
  return longestBan
end

---@param publicPlayerID PublicPlayerID
function PADatabase:getBanByPublicID(publicPlayerID)
  local bans = self:getIDBans(publicPlayerID)

  local longestBan = nil
  for _, ban in ipairs(bans) do
    if (os.time() < ban.completionTime) and ((not longestBan) or (ban.completionTime > longestBan.completionTime)) then
      longestBan = ban
    end
  end
  return longestBan
end

-- Retrieves player messages that the player has not seen yet.
---@param publicPlayerID integer
---@return table<BanID, string> # reasons for each ban, mapped by BanID
function PADatabase:getPlayerUnseenBans(publicPlayerID)
  self.statements.selectUnseenBansByPublicId:bind_values(publicPlayerID)
  local banReasons = {}
  for row in self.statements.selectUnseenBansByPublicId:nrows() do
    banReasons[row.banID] = row.reason
  end
  if self.statements.selectUnseenBansByPublicId:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return {}
  end
  return banReasons
end

-- Marks a ban as seen by a player.
---@param banID integer
---@return boolean success
function PADatabase:playerBanSeen(banID)
  self.statements.updatePlayerBanSeen:bind_values(banID)
  self.statements.updatePlayerBanSeen:step()
  if self.statements.updatePlayerBanSeen:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return false
  end
  return true
end

-- Stop statements from being committed until commitTransaction is called
function PADatabase:beginTransaction()
  if self.db:exec("BEGIN;") ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return false
  end
  return true
end

-- Commit all statements that were run since the start of beginTransaction
function PADatabase:commitTransaction()
  if self.db:exec("COMMIT;") ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return false
  end
  return true
end

return PADatabase