local tableUtils = require("common.lib.tableUtils")
local consts = require("common.engine.consts")
local StackReplayTestingUtils = require("common.tests.engine.StackReplayTestingUtils")
local Replay = require("common.data.Replay")
local GameModes = require("common.engine.GameModes")
local ReplayPlayer = require("common.data.ReplayPlayer")


local function endlessSaveTest()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10)
  local puzzleString = Puzzle.toPuzzleString(match.stacks[1].panels):sub(-36)
  assert(puzzleString == "002040054133025661353423461141644526")
  match.stacks[1]:receiveConfirmedInput(string.rep(match.stacks[1]:idleInput(), 909))
  local replay = match:createNewReplay()
  StackReplayTestingUtils:fullySimulateMatch(match)

  assert(match ~= nil)
  assert(match.stackInteraction == GameModes.StackInteractions.NONE)
  assert(match.timeLimit == nil)
  assert(tableUtils.length(match.matchWinConditions) == 0)
  assert(match.panelSource.seed == 1)
  assert(match.stacks[1].game_over_clock == 908)

  Replay.finalizeReplay(match, replay)
  local replayJSON = json.encode(replay)

  assert(replay ~= nil)
  assert(replay.players[1].settings.inputs == "A909")
  assert(replayJSON ~= nil)
  assert(type(replayJSON) == "string")
  StackReplayTestingUtils:cleanup(match)
end

endlessSaveTest()

assert(ReplayPlayer.compressInputString("") == "")

local replayUncompressed1 = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEEEEEEEEEEEEEEEEEEEAAAAAAAAAAAAAAAAAAAAAAAAQAAAAABBBBBBBAAQAAAAAAAAIIIIAAAAggggggggggggggggggggggggkkkgiiiiiiiiiiiiiiiiiiigwgghBBBBBBJJJIYAAAAAAAAAAAABBBBBBBBBBBBBBBAAAAAAAAAAACCCCCAAQAAAAAAAAAAIIIIQAAAAAAAAAAAAAAAAAAAAAAAAAIIIIIAAAAAAAAAAAEEEAAAAAAAEEEAAAAAAEEEAAAAAAAAAAAAAAAAAAIIIIIAAAAAAAAAAAAAAACCCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEEEEEFBBBBAQAAACCCCCKIIIAAQAAAAAAEEEEAAAAAEEFBBBBBBBBBBBBBBQAAACCCCCCKKIIIIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAABBBBBBBBBBRAAAAACCCCCCCCCCCCCCCCKKKIAAAAAAIIIAAAAQAAAAAIIIAAAAAAIIAAAAAAIIIAAAAAQAAAAEEEEEEAABBBBBRAAAAAEEEEEEAAQAAAAAACCCCCCCAAAAAAAIIIAAQAAAAEEEgggggggkkgggggAAEEAAAAAAAEEAAAAAAAAABBBBAAAAAAABBAAAAAABBBBRBAAAEEEEEGCCCAAAAQAAACCCCSCCCCCCCCCKKIIAAAAAAIIIAAAAAAIIAAAAAIIIIAAAQAAAAAEEEAAAAAAAAEEEEEBBBBBBAAAAAAABBBBAAAAAAAQAAAAAAAAACCCCCCCCCCCCCGGGEEEEAQAAAAABBAAAAAAAAABBBBBBJJJJIIAAAAAAAAAQAAAAEEEEEAQAAAAAAAAAAAAAAACCCCAAQAABBBBBBAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCAAAAAAAAAAAAAAAAAAAAAAAAAEEEEAAAAAAAAEEEEEAAAAAAAQAAAABBBAAAQAAABBBAAAAAAAAAAAAAAQAAABBBBAAAAAAAAACCCCCCAAAAAAAACCCKIIAAAAAAIIIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIIIIIAAAAAAAAAAAAAAQAAAAAEAAAAAAAACCCCCCCKKIIIAAQAABBBBBBBBBBBBBBBFEEEEEAAQAAAACCCCAQAAAACCCCCSCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCSCAAABBBBBBBBBBBBBBBBBAAACCCCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIIIIIAAAAAAAAAAAAAAAQAAAAAABBBBBBAAQAAAACCCCSAAAAAAAACCCCCAAAAAAACCCCAAQAAAAAACCCCCCCCCAAAAQABBBBAAAAQAABBAAAAQAAABBBBRBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABBBBBBBBBBAAAAAAAAAAAAAQAAAACCCCAAAAAAACCCCAAAAAAAACCCAAAAAAQAAAABBBAQAAAAAABAAAAAAAAAAAAAAACCCCCCCCCCCCCAAAAABBBBBBAQAAAAAAAAAAAAABBBBBAAAAAAAAAAAAAAAAAAAAEEEEAAAAAAAEEEEEAABBBBBAQAAACCCCCSCAAAAEEEEAAAAAEEEAAAAQAAAABBBBJJJJIIQAAAAAAAACCCCCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQACCCCCCCCCCCKKKKIIAAAAAAAAAAAAAAAABBBBBBBBBBBBBBBAAAAEEEEEAAAAAAAAAAAAAAAAAAAAAAAAQCCCCCCCCCCCCCCCKKIJJBBBBAAAAAIIIIAAAAAQAAAAAEEEEAAAAAAAAAAAAIIIIAAAAAAAIIAAAAAAAAAIIIAAAQAAACCCCCAAAAQABBBBAAAQAACCCCCCCCCCCCAAAAQABBBAAAAQAABBBAQAAAAAEEEAAAAAAAEEAAAAAAAAAAAAAAAAEEEAAAAABBBBBBBBBBBRBBBBCCCCCCCAAAAAAAEEEEEEEGCCCCCCCCCCCCCCCAAAQAABBBAAAAQAABBBBRAAAACCCCCCCCCCCCCCAAAABBBBBAAAAAAAQAAACCCCSAABBBBBJJIIYICCCCCCSCAAAAAIJBBBBBBJJIIAAAAAIIAAAAAAAAAAAAEEEEEAAAAAAQAAAAAAAAAAAAAAAAAAAAAEEEEAAAAAQAAAAAAEEEAAAAAABBBBBRAAAEEEEEGCCCCCQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIIIIIAAAAAAAAAAAAQAAAAAAAAAAAAAQAABBBBBRBBBFEEEEEAAAAAAAAAAAAAAAAAAACCCCCAAAQAAABBBBAAQAAAAAABBBBBRAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCKKIIIAAAAAAAAAAAAAAAAAAAAIIIIIIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCKKIIAAAAAAIIIAAAAAAIIAAAAAIIIAAQAAAAAEEAAAAAAEAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIIIIAAAAAIIAAQAAAAAEEEAAAAAAEEEEFBBBBBBQAAACCCCSCCAAAAAAAAABBBAAAAQAAABBBBRBACCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAQABBBBAAAAQAABBAAAAAQABBAAAAQABBBBBBRBBBFFFFFFEEGGCCCAAAAAAACCCCAAAAQAAAAAEEEEAAQAAAAAAAAAEEEEAAAAAAAAAAAAAAAAAAAAABBBBBBBBBBBBBBBJAAAAAAAIIIIAAAAAQAAAAAEEEAAAAAAAAAAAAAQAAAAAAAEEEEEEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAEEEEEGGCCCAAAAACCCCAAAAQABBBBBRAAACCCCAAAAAACCCAAAQAAABBBBRBBBBBJIIIAQAAAAAAAAABBBBBBBBBBBBBRAACCCCCCCCCCCCCCCAAABBBBBBAAAAAAAAAAAAAABBAAAAAAAAEEEEEAAAAAAEEAAAQAAAAAAEEEEEFBBBBBBBBBBBBRAAACCCCAAQAAACCCAQAAAAAAACCCCCCCKKKIIAAAAAAAAAAAAAAAAQAAAAAAAAAAQAAAAAAAAQAAAAAAAAQAAAAAQAABBBBBBBBBBBBBBBBBJJJJIAQAAAAACCSCCCCCCCCCCCCKKKIIIAAAAAAAIIIAAAAAAAIIIAAAAAAIIAAAAAAAAAAABBBBBBQAAAAAAAABBBRBBBBAAACCCCAAQAAAAAACCCCCCCKKIIAAAAAIIIAAQAAAAAEEAAAAAAEEAAAAAAQAAABBBBBJJJIIAAAQAAAABBBRBBBEEEEEEAAAAQAAAAAAACCCCCQAAAABBBRBAAAAAEEEEEEAAAAAAAAABBBBBBBBBBBBBRBBBAACCCCAAAAAACCCAAAAAAAQABBBAAAAAQABBBAAQAABBBBBBBDDCCCCCCCCCCCCCAEEEEEEAABBBBBBAAAAAAABBBBBRAAAAAAEEEEEEEEGAAAAAAAAAAAAAAAAAEEEEEAAAACCCCCCAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABBBBBBBBBBBBBBBJJIIIIKKCCCCAAQAAAACCCCCCCCCCCCCCCKKIIIAAAAAAAAIIIIIAAAAAAAAAAAAAQAAAEEEEAAAAAAAAAAABBBBBAAAAAAAAAAAAAAIIIIIAQAAAAAAAAAAAAAQAAAAAAAA"
local replayCompressed1 = "A152E19A24Q1A5B7A2Q1A8I4A4g24k3g1i19g1w1g2h1B6J3I1Y1A12B15A11C5A2Q1A10I4Q1A25I5A11E3A7E3A6E3A18I5A15C3A34E5F1B4A1Q1A3C5K1I3A2Q1A6E4A5E2F1B14Q1A3C6K2I4A40Q1A4B10R1A5C16K3I1A6I3A4Q1A5I3A6I2A6I3A5Q1A4E6A2B5R1A5E6A2Q1A6C7A7I3A2Q1A4E3g7k2g5A2E2A7E2A9B4A7B2A6B4R1B1A3E5G1C3A4Q1A3C4S1C9K2I2A6I3A6I2A5I4A3Q1A5E3A8E5B6A7B4A7Q1A9C13G3E4A1Q1A5B2A9B6J4I2A9Q1A4E5A1Q1A15C4A2Q1A2B6A27C6A25E4A8E5A7Q1A4B3A3Q1A3B3A14Q1A3B4A9C6A8C3K1I2A6I3A37I5A14Q1A5E1A8C7K2I3A2Q1A2B15F1E5A2Q1A4C4A1Q1A4C5S1C1A41C12S1C1A3B17A3C4A34I5A15Q1A6B6A2Q1A4C4S1A8C5A7C4A2Q1A6C9A4Q1A1B4A4Q1A2B2A4Q1A3B4R1B1A108B10A13Q1A4C4A7C4A8C3A6Q1A4B3A1Q1A6B1A15C13A5B6A1Q1A13B5A20E4A7E5A2B5A1Q1A3C5S1C1A4E4A5E3A4Q1A4B4J4I2Q1A8C5A56Q1A1C11K4I2A16B15A4E5A24Q1C15K2I1J2B4A5I4A5Q1A5E4A12I4A7I2A9I3A3Q1A3C5A4Q1A1B4A3Q1A2C12A4Q1A1B3A4Q1A2B3A1Q1A5E3A7E2A16E3A5B11R1B4C7A7E7G1C15A3Q1A2B3A4Q1A2B4R1A4C14A4B5A7Q1A3C4S1A2B5J2I2Y1I1C6S1C1A5I1J1B6J2I2A5I2A12E5A6Q1A21E4A5Q1A6E3A6B5R1A3E5G1C5Q1A55I5A12Q1A13Q1A2B5R1B3F1E5A19C5A3Q1A3B4A2Q1A6B5R1A78C6K2I3A20I6A51C5K2I2A6I3A6I2A5I3A2Q1A5E2A6E1A4Q1A65I4A5I2A2Q1A5E3A6E4F1B6Q1A3C4S1C2A9B3A4Q1A3B4R1B1A1C16A29Q1A10Q1A1B4A4Q1A2B2A5Q1A1B2A4Q1A1B6R1B3F6E2G2C3A7C4A4Q1A5E4A2Q1A9E4A21B15J1A7I4A5Q1A5E3A13Q1A7E6A51Q1A6E5G2C3A5C4A4Q1A1B5R1A3C4A6C3A3Q1A3B4R1B5J1I3A1Q1A9B13R1A2C15A3B6A14B2A8E5A6E2A3Q1A6E5F1B12R1A3C4A2Q1A3C3A1Q1A7C7K3I2A16Q1A10Q1A8Q1A8Q1A5Q1A2B17J4I1A1Q1A5C2S1C12K3I3A7I3A7I3A6I2A11B6Q1A8B3R1B4A3C4A2Q1A6C7K2I2A5I3A2Q1A5E2A6E2A6Q1A3B5J3I2A3Q1A4B3R1B3E6A4Q1A7C5Q1A4B3R1B1A5E6A9B13R1B3A2C4A6C3A7Q1A1B3A5Q1A1B3A2Q1A2B7D2C13A1E6A2B6A7B5R1A6E8G1A17E5A4C6A2Q1A42B15J2I4K2C4A2Q1A4C15K2I3A8I5A13Q1A3E4A11B5A14I5A1Q1A13Q1A8"
local replayUncompressed2 = "AAAAAAAAAAAAAAAAAAAAAAEEEEEEEEEEEEEEEEEEEGGGGCCKKKKIIIAAggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggghhhhhhhpoooophhhhhhpooooggggggooooooogggggggggggggggggggggggggggggggwggggggkkkkkggggkk1kkkggggghhhhhhllkkkkggggkk1kkmiiiiiqqoophggAACCCCCQABBBRBBBAAAAAAAAACCCCCCAAAACCSCAABBRBBBBEEEEEEGCCCSCCCCCCCCCCCCCCCSABBBBRBBAAAAAAAAAIIIIIAAAAAAAABBBBBRAAACCCCGEEEEEAAAEEEUEEEAAAAEEEEEEAAAAEEEEEEEEEEEEEEEEUEAABBBBBBBBBBBBBJJZIIKCCCCQAAACCSCCCCAAAAAAIIIIIIIIIIIIIIAACCCCCCCAAAAAAAAIIIIYIJBEEEEEEEEEEEEEEEEABBBBBBBBBBBBBBBBBBAACCCCSCCAAAAABBBJJJJJJJIAAAAAAQAAAAAACCCCCAAAAACCCCCCAAAQAAAAAABBBBBRBAAAAAAAAAIIIIIIAAAAAIIIIIKKCCCCCIJJJBBBBBBBAEGEEUEAABBRBBBAAAACCCCCCAIIIIYIBBBBRBBAAAACCCCCCAAAACCCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAEEEEEEAAAAEEEEFBBRBBBAAACCCCCCQEEEEUEEEBBBBBBJIIIIIAAAAAAAAIIIIIIIIAAAAAAAIIIIIIIIAAABBBBBBBRAAAAAAAACCCCSCAAAAAAAAIIIAAAQAAAAAAAAAAAAAAQAAABBRBBBBAAAAEEEEEAAAAAEEEEEAABBBFFFEEEEEEEEEEEEQAIIYIIKKCCCCCCCCCCCCCCCAAABBBBBBBAAAAAAIIIIYIIAAAEEEEEEAAAQAAACCCCSCAABBRBBBBBABBBBBBBBBBBBBBJJJJIIKCCCSCCAAAAAAAAAACCCCCCAAAACCCCCCAAAAAAAAAA"
local replayCompressed2 = "A22E19G4C2K4I3A2g67h7p1o4p1h6p1o4g6o7g31w1g6k5g4k2(1)k3g5h6l2k4g4k2(1)k2m1i5q2o2p1h1g2A2C5Q1A1B3R1B3A9C6A4C2S1C1A2B2R1B4E6G1C3S1C15S1A1B4R1B2A9I5A8B5R1A3C4G1E5A3E3U1E3A4E6A4E16U1E1A2B13J2Z1I2K1C4Q1A3C2S1C4A6I14A2C7A8I4Y1I1J1B1E16A1B18A2C4S1C2A5B3J7I1A6Q1A6C5A5C6A3Q1A6B5R1B1A9I6A5I5K2C5I1J3B7A1E1G1E2U1E1A2B2R1B3A4C6A1I4Y1I1B4R1B2A4C6A4C18A15E6A4E4F1B2R1B3A3C6Q1E4U1E3B6J1I5A8I8A7I8A3B7R1A8C4S1C1A8I3A3Q1A14Q1A3B2R1B4A4E5A5E5A2B3F3E12Q1A1I2Y1I2K2C15A3B7A6I4Y1I2A3E6A3Q1A3C4S1C1A2B2R1B5A1B14J4I2K1C3S1C2A10C6A4C6A10"

assert(replayCompressed1 == ReplayPlayer.compressInputString(replayUncompressed1))
assert(replayCompressed2 == ReplayPlayer.compressInputString(replayUncompressed2))
assert(replayUncompressed1 == ReplayPlayer.decompressInputString(replayCompressed1))
assert(replayUncompressed2 == ReplayPlayer.decompressInputString(replayCompressed2))

local latinUncompressed1 = "ĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀāāāāāāāāāāāāāāāāāāāāāāāāāāāāāĀĀĀĀĀĀĀĀĀĀńńńńłłłłłłĀĀĀĀĀĀĀĀĀĀĀĀĺĺĸĸĸĪĪĨĨĨĨĀĀĀĀĀĀĀĀĀĀĀāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāĀĀĀĀĀĀĀĀĀĀĀĢĢĢĬĬĪĪĨĨĨĦĚĚĚĚĚĀĀĀĀĀĀĀĀĀĀĀĶĶĶĶĶłńńńńńńńńńńńńńńńŅŅŃŃŃŃŃŃōōōōřřťŧŧŧũũũũũũśśřřŗŗŗřśśőőőőőőőőőŏŏŏŁŁĿŋŋŋŋŋōŅŅŅŇŇŅŅŃŃŁŁŁŃŅŅŇŇŇŇŇŅŃķķķķķĹĹĻįįįĹ"
local latinCompressed1 = "Ā255ā29Ā10ń4ł6Ā12ĺ2ĸ3Ī2Ĩ4Ā11ā34Ā11Ģ3Ĭ2Ī2Ĩ3Ħ1Ě5Ā11Ķ5ł1ń15Ņ2Ń6ō4ř2ť1ŧ3ũ6ś2ř2ŗ3ř1ś2ő9ŏ3Ł2Ŀ1ŋ5ō1Ņ3Ň2Ņ2Ń2Ł3Ń1Ņ2Ň5Ņ1Ń1ķ5Ĺ2Ļ1į3Ĺ1"
assert(latinCompressed1 == ReplayPlayer.compressInputString(latinUncompressed1))
assert(latinUncompressed1 == ReplayPlayer.decompressInputString(latinCompressed1))


local latinCompressed2 = "Ā96Ğ1Ĝ3Ğ4Ġ17Ā62Ĩ7Ī10Ĩ1Ĝ3Ě3Ĝ2Ğ2Ġ2Ģ3Ĥ6Ā34Ħ3Ĩ2Ī1Ĭ5Ā37Ğ2Ġ5Ā40İ5Į5Ā53Ć3Ĉ4Ċ6Ā81Ĕ2Ė3Ę3Ā43Ę3Ė6Ā34ļ3ĺ3ĸ3Ā16ā74Ā22ŀ6ł5Ā38Ġ4Ğ4Ā28Ĩ4Ī4Ĭ2Ā47Ĭ2Ī8Ā27Ĭ5Ī8Ā42Ī4Ā5Ī4Ā5Ī3Ā5Ī3Ā80Ď3Đ2Ā22Ć2Ą5Ā69Ģ3Ġ2Ğ1Ĝ2Ě4Ā29Ē4Đ2Ď6Ā41Ē5Đ2Ď5Ā20Ą3Ă5Ā11ā21Ā23Ķ1Ĵ2Ĳ6Ā63Ĵ2Ķ1ĸ1ĺ7Ā39ĺ3ļ9Ā82Ċ2Ĉ7Ā24Ē2Ĕ5Ġ2Ā45Ģ3Ġ6Ā21ĺ6ĸ6Ā81Ğ11Ġ4Ā22Ĕ5Ē6Ā16Ė2Ĕ6Ā51Ē4Ĕ5Ā62Ĝ4Ğ2Ġ4Ā52Ģ2Ĕ4Ā36Ĥ5Ģ5Ā38Ĝ5Ğ1Ġ3Ā23Ģ6Ġ4Ā23Ę5Ė4Ĕ2Ā16ā161"
local latinUncompressed2 = "ĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĞĜĜĜĞĞĞĞĠĠĠĠĠĠĠĠĠĠĠĠĠĠĠĠĠĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĨĨĨĨĨĨĨĪĪĪĪĪĪĪĪĪĪĨĜĜĜĚĚĚĜĜĞĞĠĠĢĢĢĤĤĤĤĤĤĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĦĦĦĨĨĪĬĬĬĬĬĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĞĞĠĠĠĠĠĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀİİİİİĮĮĮĮĮĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĆĆĆĈĈĈĈĊĊĊĊĊĊĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĔĔĖĖĖĘĘĘĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĘĘĘĖĖĖĖĖĖĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀļļļĺĺĺĸĸĸĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀŀŀŀŀŀŀłłłłłĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĠĠĠĠĞĞĞĞĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĨĨĨĨĪĪĪĪĬĬĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĬĬĪĪĪĪĪĪĪĪĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĬĬĬĬĬĪĪĪĪĪĪĪĪĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĪĪĪĪĀĀĀĀĀĪĪĪĪĀĀĀĀĀĪĪĪĀĀĀĀĀĪĪĪĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĎĎĎĐĐĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĆĆĄĄĄĄĄĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĢĢĢĠĠĞĜĜĚĚĚĚĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĒĒĒĒĐĐĎĎĎĎĎĎĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĒĒĒĒĒĐĐĎĎĎĎĎĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĄĄĄĂĂĂĂĂĀĀĀĀĀĀĀĀĀĀĀāāāāāāāāāāāāāāāāāāāāāĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĶĴĴĲĲĲĲĲĲĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĴĴĶĸĺĺĺĺĺĺĺĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĺĺĺļļļļļļļļļĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĊĊĈĈĈĈĈĈĈĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĒĒĔĔĔĔĔĠĠĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĢĢĢĠĠĠĠĠĠĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĺĺĺĺĺĺĸĸĸĸĸĸĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĞĞĞĞĞĞĞĞĞĞĞĠĠĠĠĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĔĔĔĔĔĒĒĒĒĒĒĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĖĖĔĔĔĔĔĔĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĒĒĒĒĔĔĔĔĔĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĜĜĜĜĞĞĠĠĠĠĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĢĢĔĔĔĔĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĤĤĤĤĤĢĢĢĢĢĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĜĜĜĜĜĞĠĠĠĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĢĢĢĢĢĢĠĠĠĠĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĘĘĘĘĘĖĖĖĖĔĔĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀĀāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāāā"
assert(latinCompressed2 == ReplayPlayer.compressInputString(latinUncompressed2))
assert(latinUncompressed2 == ReplayPlayer.decompressInputString(latinCompressed2))