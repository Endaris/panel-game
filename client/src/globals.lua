local consts = require("common.engine.consts")
score_mode = consts.SCOREMODE_TA

GARBAGE_TRANSIT_TIME = 45 -- the amount of time the garbage attack animation plays before getting to the telegraph
GARBAGE_TELEGRAPH_TIME = 45 -- the amount of time the garbage stays in the telegraph after getting there from the attack animation
GARBAGE_DELAY_LAND_TIME = 60 -- this is the amount of time after garbage leaves the telegraph before it can land on the opponent
						  -- a higher value allows less rollback to happen and makes lag have less of an impact on the game
						  -- technically this was 0 in classic games, but we are using this value to make rollback less noticable and match PA history
MAX_LAG = 155 + GARBAGE_TELEGRAPH_TIME + GARBAGE_TRANSIT_TIME -- maximum amount of lag before net games abort
NAME_LENGTH_LIMIT = 16

themes = {} -- initialized in theme.lua

THEME_DIRECTORY_PATH = "themes/"