-- this is an incomplete reimplementation of love's RandomGenerator
-- missing features:
--  - cannot call functions on the class itself, you NEED to create an object
--  - randomNormal is not implemented
--  - does not account for potential big endianness

-- not sure if these ffi type shenanigans are properly representable via annotations
---@diagnostic disable: param-type-mismatch, inject-field, return-type-mismatch, assign-type-mismatch


local class = require("common.lib.class")
local bit = require("bit")
local ffi = require("ffi")

local tonumber = tonumber
local floor = math.floor

ffi.cdef[[
  typedef union
	{
		uint64_t b64;
		struct
		{
//#ifdef LOVE_BIG_ENDIAN
      //uint32_t high;
			//uint32_t low;
//#else
      uint32_t low;
			uint32_t high;
//#endif
		} b32;
	} Seed;
]]

ffi.cdef[[
  typedef union {
    uint64_t i;
    double d;
  } rng;
]]

-- A RandomGenerator that seeks to replicate the functionality of love's RandomGenerator for use in the server side
---@class RandomGenerator
---@operator call():RandomGenerator
---@field seed ffi.cdata*
---@field rngState ffi.cdata*
local RandomGenerator = class(
---@param self RandomGenerator
function(self)
  local seed = ffi.new("Seed")
  seed.b32.low = 0xCBBF7A44;
	seed.b32.high = 0x0139408D;
  self:__setSeed(seed)
end)

---@param seed integer
---@return RandomGenerator
function RandomGenerator.newFromSeed(seed)
  local rng = RandomGenerator()
  rng:setSeed(seed)
  return rng
end

---@param low integer
---@param high integer
---@return RandomGenerator
function RandomGenerator.newFromLowHigh(low, high)
  local rng = RandomGenerator()
  local seed = ffi.new("Seed")
  seed.low.b32 = low
  seed.high.b32 = high
  rng:__setSeed(seed)
  return rng
end

--https://web.archive.org/web/20110807030012/http://www.cris.com/%7ETtwang/tech/inthash.htm
---@param key ffi.cdata* | integer
local function wangHash64(key)
  key = bit.lshift(key, 21) - key - 1
  key = bit.bxor(key, (bit.rshift(key, 24)))
  key = (key + (bit.lshift(key, 3)) + (bit.lshift(key, 8))) -- key * 265
  key = bit.bxor(key, (bit.rshift(key, 14)));
  key = (key + (bit.lshift(key, 2))) + (bit.lshift(key, 4)); -- key * 21
  key = bit.bxor(key, (bit.rshift(key, 28)));
  key = key + (bit.lshift(key, 31));
  return key;
end

---@return integer
function RandomGenerator:getSeed()
  return tonumber(self.seed.b64)
end

---@return string
function RandomGenerator:getState()
  return "0x" .. bit.tohex(self.rngState.b64, 16)
end

---@param num1 number?
---@param num2 number?
---@return number
function RandomGenerator:random(num1, num2)
  local rand = self:__random()
  local rng = ffi.new("rng")
  rng.i = bit.bor(bit.lshift(0x3FFULL, 52), (bit.rshift(rand, 12)))
  if not num1 then
    return rng.d - 1.0
  elseif not num2 then
    return floor((rng.d - 1.0) * num1) + 1
  else
    return floor((rng.d - 1.0) * (num2 - num1 + 1)) + num1
  end
end

---@return ffi.cdata*
function RandomGenerator:__random()
  self.rngState.b64 = bit.bxor(self.rngState.b64, bit.rshift(self.rngState.b64, 12))
  self.rngState.b64 = bit.bxor(self.rngState.b64, bit.lshift(self.rngState.b64, 25))
  self.rngState.b64 = bit.bxor(self.rngState.b64, bit.rshift(self.rngState.b64, 27))
  return self.rngState.b64 * 2685821657736338717ULL
end

function RandomGenerator:randomNormal()
  error("Not implemented")
end

---@param seed integer
function RandomGenerator:setSeed(seed)
  local boxed = ffi.new("Seed")
  boxed.b64 = seed
  self:__setSeed(boxed)
end

---@param seed ffi.cdata*
function RandomGenerator:__setSeed(seed)
  self.seed = seed

  local rngState = ffi.new("Seed")

  repeat
    rngState.b64 = wangHash64(seed.b64)
  until seed ~= 0

  self.rngState = rngState
end

---@param state string
function RandomGenerator:setState(state)
  local high = state:sub(1, 10)
  local low = "0x" .. state:sub(11)
  local boxed = ffi.new("Seed")
  boxed.b32.low = bit.tobit(low)
  boxed.b32.high = bit.tobit(high)
  self.rngState = boxed
end


return RandomGenerator
