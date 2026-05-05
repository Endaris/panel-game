local RandomGenerator = require("common.lib.RandomGenerator")

local function testStateProgression(seed)
  local rng = RandomGenerator.newFromSeed(seed)
  local loveRng = love.math.newRandomGenerator(seed)

  local lState = rng:getState()
  local rState = loveRng:getState()
  -- if this fails, the wanghash is likely going wrong with the shifts
  assert(lState == rState)


  for i = 1, 10 do
    local r = rng:random()
    local lr = loveRng:random()
    rState = rng:getState()
    lState = loveRng:getState()
    assert(rState == lState)
    assert(r == lr)
  end
end

local function testRandomRange(seed)
  local rng = RandomGenerator.newFromSeed(seed)
  local loveRng = love.math.newRandomGenerator(seed)

  for i = 1, 100 do
    local r = rng:random(3, 9)
    local lr = loveRng:random(3, 9)
    assert(r == lr)
    r = rng:random(1, 6)
    lr = loveRng:random(1, 6)
    assert(r == lr)
  end
end

local numbers = { 25, 16049, 362384 }

local function testState()
  for i = 1, #numbers do
    testStateProgression(numbers[i])
  end
end

local function testRange()
  for i = 1, #numbers do
    testRandomRange(numbers[i])
  end
end

testState()
testRange()