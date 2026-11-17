-- Locomotion: idle, walk and run for R6, imitating the user's house style, their R6 movement
-- system ("idle v2", "walk v3", "run v4"). Measured with `lune run study ... --keys=`,
-- then rebuilt as our own key poses: angles plus slides, no IK.
--
--   local clips = Locomotion.build()          -- name -> { clip, baked, meta }
--
-- What the reference does, and these clips keep:
--   walk  0.833 s cycle: legs swing -38..+32 and the passing leg rides 0.5 stud up into the torso
--         (R6 has no knee), arms swing about 25 each way and slide 0.25 stud along the swing, the
--         torso leans 8-11, bobs 0.1-0.33 down and twists 9 against the stride, the head counters
--   run   0.633 s cycle: legs to -58/+80 riding up to 0.9 stud, the forward arm swings to 120 and
--         slides 0.8 stud, the torso leans 18-24 and drops 0.3-0.46
--   idle  1.883 s: nearly still (a breath of 1-3 degrees), legs slid 0.24 forward under the root
-- Walk and run are half cycles plus their mirror (the reference is symmetric). Fidelity against
-- the reference: walk within 4.8 degrees, run 3.9, idle 1.2.
-- Also climb, jump, fall, three landings and a wall run, picked the same way (reference first):
--   Climb, Jump, Fall, Land, LandShort, LandLong  The movement system's "Climbing", "jump", "fall", "Normal Land",
--         "Short", "Long" (landing tiers by fall height: under 4 studs, 4-15, over 15)
--   WallRunRight / WallRunLeft  the movement system has none, so the Creator Store "R6 Parkour Animations"
--         (asset 15259391918, free to use with credit) WallRunR: a sprint cycle with the torso tilted
--         25 degrees away from the wall; the left one is its mirror
-- Keys were chosen with `lune run study --fit=4` (6 for the long Climb and Fall loops): the fewest
-- keys that rebuild the reference within that many degrees, with continuous angles.
-- Runtime (which clip, how fast, the blends): R6Locomotion; the wall run itself: R6WallRun.

local R6Clip = require(script.Parent.R6Clip)

local Locomotion = {}

local WALK = {
	[0] = {
		Torso = { lean = 8, twist = 8.7, tilt = 0.4, pos = { forward = 0.1, up = -0.25, right = 0.02 } },
		Head = { tilt = 0.8, nod = 1.4, turn = -8, pos = { up = 0.02 } },
		RightArm = { raise = 24.9, spread = 12.1, swing = 23, pos = { forward = 0.23, up = -0.28, right = 0.01 } },
		LeftArm = { raise = -19, spread = 12.3, swing = -22.5, pos = { forward = -0.25, up = -0.24, right = 0.08 } },
		RightLeg = { raise = -36.1, spread = 1, swing = -11.7, pos = { forward = -0.15, up = -0.21, right = 0.03 } },
		LeftLeg = { raise = 32.1, spread = -0.6, swing = 4.4, pos = { forward = 0.43, up = 0.14, right = 0.03 } },
	},
	[6] = {
		Torso = { lean = 9.5, twist = 6.2, tilt = 0.5, pos = { forward = 0.17, up = -0.33, right = 0.02 } },
		Head = { tilt = 0.7, nod = 0.4, turn = -6.1, pos = { up = 0.02 } },
		RightArm = { raise = 20.4, spread = 8.1, swing = 8.5, pos = { forward = 0.06, up = -0.29, right = 0.01 } },
		LeftArm = { raise = -13.6, spread = 10.1, swing = -6.2, pos = { forward = -0.07, up = -0.19, right = 0.09 } },
		RightLeg = { raise = -53.8, spread = 3.9, swing = -10.5, pos = { forward = 0.79, up = -0.08, right = 0.1 } },
		LeftLeg = { raise = 7.4, spread = 1.1, swing = 2.4, pos = { forward = 0.63, up = 0.44, right = 0.05 } },
	},
	[12] = {
		Torso = { lean = 11, twist = 0.5, tilt = 0.2, pos = { forward = 0.25, up = -0.22 } },
		Head = { tilt = 0.1, nod = -2.6, turn = -0.4, pos = { up = 0.02 } },
		RightArm = { raise = 8.2, spread = 6.8, swing = -6.9, pos = { forward = -0.15, up = -0.26, right = -0.02 } },
		LeftArm = { raise = 3, spread = 10.6, swing = 16.9, pos = { forward = 0.13, up = -0.13, right = 0.07 } },
		RightLeg = { raise = -17, spread = 3.2, swing = -3.8, pos = { forward = 0.97, up = 0.49, right = -0.02 } },
		LeftLeg = { raise = -25.1, spread = 2.9, swing = -3.9, pos = { forward = 0.6, right = -0.01 } },
	},
	[18] = {
		Torso = { lean = 9.8, twist = -5.4, tilt = -0.3, pos = { forward = 0.19, up = -0.17, right = -0.01 } },
		Head = { tilt = -0.5, nod = -2.2, turn = 5.6, pos = { up = 0.02 } },
		RightArm = { raise = -6.8, spread = 9.4, swing = -19.2, pos = { forward = -0.29, up = -0.22, right = -0.06 } },
		LeftArm = { raise = 17.9, spread = 14.1, swing = 29.8, pos = { forward = 0.26, up = -0.16, right = 0.04 } },
		RightLeg = { raise = 16.1, spread = 0.9, swing = 1.8, pos = { forward = 0.74, up = 0.34, right = -0.06 } },
		LeftLeg = { raise = -37.8, spread = 2.3, swing = -9.4, pos = { forward = 0.11, up = -0.35, right = -0.04 } },
	},
	[24] = {
		Torso = { lean = 8.1, twist = -8.6, tilt = -0.4, pos = { forward = 0.1, up = -0.24, right = -0.02 } },
		Head = { tilt = -0.7, nod = 1.1, turn = 8.9, pos = { up = 0.02 } },
		RightArm = { raise = -18.2, spread = 12.2, swing = -23.4, pos = { forward = -0.27, up = -0.24, right = -0.08 } },
		LeftArm = { raise = 24.7, spread = 12.8, swing = 24.9, pos = { forward = 0.24, up = -0.26 } },
		RightLeg = { raise = 34.5, spread = -0.6, swing = 4.3, pos = { forward = 0.39, up = 0.08, right = -0.03 } },
		LeftLeg = { raise = -32.4, spread = 0.9, swing = -11.5, pos = { forward = -0.27, up = -0.2 } },
	},
}

local RUN = {
	[0] = {
		Torso = { lean = 17.8, twist = -19.4, tilt = -4.6, pos = { forward = 0.32, up = -0.34, right = -0.03 } },
		Head = { tilt = -1.4, nod = -5.3, turn = 18.4 },
		RightArm = { raise = -32.5, spread = 30.7, swing = -11.5, pos = { forward = -0.56, up = -0.06, right = -0.06 } },
		LeftArm = { raise = 47.4, spread = 126.2, swing = 124.5, pos = { forward = 0.32, up = -0.52, right = -0.09 } },
		RightLeg = { raise = 57.9, spread = 2.8, swing = 20.8, pos = { forward = 1.01, up = 0.4, right = -0.24 } },
		LeftLeg = { raise = -74.5, spread = -5.6, swing = -13, pos = { forward = -0.48, up = -0.22, right = 0.17 } },
	},
	[3] = {
		Torso = { lean = 18.8, twist = -17.2, tilt = -4.3, pos = { forward = 0.26, up = -0.44, right = -0.03 } },
		Head = { tilt = -1.2, nod = -7.4, turn = 16 },
		RightArm = { raise = -30.6, spread = 36.2, swing = -15.9, pos = { forward = -0.41, up = -0.1, right = -0.07 } },
		LeftArm = { raise = 39.1, spread = 132.7, swing = 132.2, pos = { forward = 0.33, up = -0.69, right = -0.1 } },
		RightLeg = { raise = 36.5, spread = 1.6, swing = 17.2, pos = { forward = 0.88, up = 0.55, right = -0.18 } },
		LeftLeg = { raise = -80.3, spread = -7.8, swing = -8.6, pos = { forward = -0.07, up = -0.15, right = 0.03 } },
	},
	[6] = {
		Torso = { lean = 21.2, twist = -11, tilt = -3.3, pos = { forward = 0.26, up = -0.43, right = -0.02 } },
		Head = { tilt = -0.6, nod = -10.6, turn = 9.8 },
		RightArm = { raise = -15.4, spread = 30.1, swing = -9, pos = { forward = -0.16, up = -0.23, right = -0.07 } },
		LeftArm = { raise = 49.7, spread = 118.3, swing = 122.4, pos = { forward = -0.03, up = -0.65, right = -0.07 } },
		RightLeg = { raise = 8.1, spread = 0.8, swing = 10.3, pos = { forward = 0.48, up = 0.43, right = -0.05 } },
		LeftLeg = { raise = -70.9, spread = -2.3, swing = -8.1, pos = { forward = 0.6, up = 0.03, right = -0.1 } },
	},
	[9] = {
		Torso = { lean = 23.2, twist = -2, tilt = -0.9, pos = { forward = 0.31, up = -0.33 } },
		Head = { tilt = 0.3, nod = -12.6, turn = 1.4 },
		RightArm = { raise = 10.6, spread = 21.4, swing = 6.7, pos = { forward = 0.15, up = -0.31, right = -0.04 } },
		LeftArm = { raise = 60.1, spread = 53.4, swing = 58.6, pos = { forward = -0.59, up = -0.44, right = -0.02 } },
		RightLeg = { raise = -9.1, spread = -0.1, swing = 1.9, pos = { forward = -0.03 } },
		LeftLeg = { raise = -47.5, spread = 0.2, swing = -2, pos = { forward = 1.12, up = 0.38, right = -0.04 } },
	},
	[12] = {
		Torso = { lean = 24.3, twist = 7.6, tilt = 2.2, pos = { forward = 0.33, up = -0.29, right = 0.01 } },
		Head = { tilt = 1.1, nod = -12.8, turn = -7.3 },
		RightArm = { raise = 41.9, spread = 36.8, swing = 40.2, pos = { forward = 0.34, up = -0.23, right = 0.03 } },
		LeftArm = { raise = 38.7, spread = 25.5, swing = 23.6, pos = { forward = -0.82, up = -0.25, right = -0.01 } },
		RightLeg = { raise = -23.9, spread = -1, swing = -6.5, pos = { forward = -0.37, up = -0.18, right = -0.07 } },
		LeftLeg = { raise = -14.7, spread = 1, swing = 6.6, pos = { forward = 1.08, up = 0.85, right = 0.11 } },
	},
	[15] = {
		Torso = { lean = 22.3, twist = 15.3, tilt = 4.3, pos = { forward = 0.34, up = -0.29, right = 0.02 } },
		Head = { tilt = 1.6, nod = -10, turn = -14.4 },
		RightArm = { raise = 53.9, spread = 82, swing = 88.1, pos = { forward = 0.37, up = -0.23, right = 0.09 } },
		LeftArm = { raise = 6.9, spread = 22.7, swing = 7.8, pos = { forward = -0.78, up = -0.12 } },
		RightLeg = { raise = -45.2, spread = -2.2, swing = -12.6, pos = { forward = -0.55, up = -0.2, right = -0.16 } },
		LeftLeg = { raise = 27.5, spread = 1.7, swing = 14.9, pos = { forward = 0.96, up = 0.89, right = 0.18 } },
	},
	[18] = {
		Torso = { lean = 18.5, twist = 19.1, tilt = 4.6, pos = { forward = 0.33, up = -0.32, right = 0.03 } },
		Head = { tilt = 1.4, nod = -5.8, turn = -18.1 },
		RightArm = { raise = 50.3, spread = 119.1, swing = 118.9, pos = { forward = 0.32, up = -0.44, right = 0.09 } },
		LeftArm = { raise = -26.8, spread = 27.6, swing = -7.2, pos = { forward = -0.62, up = -0.06, right = 0.05 } },
		RightLeg = { raise = -69, spread = -4.3, swing = -14, pos = { forward = -0.55, up = -0.22, right = -0.19 } },
		LeftLeg = { raise = 56.6, spread = 2.8, swing = 20.4, pos = { forward = 1.01, up = 0.47, right = 0.23 } },
	},
}

local IDLE = {
	[0] = {
		Torso = { lean = 0.4, pos = { forward = 0.01, up = -0.04, right = 0.03 } },
		Head = { tilt = 0.1, nod = 1.6, turn = 0.5, pos = { up = 0.02 } },
		RightArm = { raise = 0.1, spread = 2.3, swing = -6.9, pos = { forward = -0.08, up = -0.07, right = -0.04 } },
		LeftArm = { raise = 0.1, spread = 2.3, swing = -6.9, pos = { forward = -0.08, up = -0.07, right = 0.04 } },
		RightLeg = { raise = -7.1, spread = 3.8, swing = -3.9, pos = { forward = 0.24, up = 0.05, right = 0.01 } },
		LeftLeg = { raise = -7.2, spread = 3.5, swing = -4.4, pos = { forward = 0.24, up = 0.04, right = -0.01 } },
	},
	[28] = {
		Torso = { lean = 0.7, pos = { forward = 0.01, up = -0.06, right = 0.03 } },
		Head = { tilt = 0.1, nod = 3, turn = 0.5, pos = { up = 0.02 } },
		RightArm = { raise = -1.2, spread = 2.5, swing = -4.6, pos = { forward = -0.08, up = -0.08, right = -0.04 } },
		LeftArm = { raise = 0.2, spread = 2.4, swing = -3.9, pos = { forward = -0.08, up = -0.1, right = 0.05 } },
		RightLeg = { raise = -9.3, spread = 3.9, swing = -4.1, pos = { forward = 0.32, up = 0.06, right = 0.01 } },
		LeftLeg = { raise = -9.4, spread = 3.5, swing = -4.6, pos = { forward = 0.32, up = 0.06, right = -0.01 } },
	},
	[57] = {
		Torso = { lean = 1.2, pos = { forward = 0.01, up = -0.06, right = 0.03 } },
		Head = { tilt = 0.1, nod = 2.3, turn = 0.5, pos = { up = 0.02 } },
		RightArm = { raise = -1.5, spread = 2.5, swing = -4.6, pos = { forward = -0.08, up = -0.08, right = -0.04 } },
		LeftArm = { raise = -0.3, spread = 2.4, swing = -1.6, pos = { forward = -0.08, up = -0.09, right = 0.04 } },
		RightLeg = { raise = -8.1, spread = 3.8, swing = -4, pos = { forward = 0.31, up = 0.06, right = 0.01 } },
		LeftLeg = { raise = -8.1, spread = 3.4, swing = -4.5, pos = { forward = 0.31, up = 0.06, right = -0.01 } },
	},
	[85] = {
		Torso = { lean = 1, pos = { forward = 0.01, up = -0.03, right = 0.03 } },
		Head = { tilt = 0.1, nod = 1.1, turn = 0.5, pos = { up = 0.02 } },
		RightArm = { raise = -0.4, spread = 2.4, swing = -6.6, pos = { forward = -0.08, up = -0.07, right = -0.04 } },
		LeftArm = { raise = -0.4, spread = 2.4, swing = -4.1, pos = { forward = -0.08, up = -0.06, right = 0.03 } },
		RightLeg = { raise = -5.9, spread = 3.7, swing = -3.9, pos = { forward = 0.23, up = 0.05, right = 0.01 } },
		LeftLeg = { raise = -6, spread = 3.4, swing = -4.4, pos = { forward = 0.23, up = 0.05, right = -0.01 } },
	},
}

-- reference climbing, 2.167 s loop
local CLIMB = {
	[0] = {
		Torso = { pos = { forward = -0.15, up = -0.01 } },
		Head = { nod = -36.8 },
		RightArm = { raise = 153.8, spread = -45, swing = 1.4, pos = { forward = 0.43, up = 0.15 } },
		LeftArm = { raise = 158.2, spread = -34.7, swing = -0.6, pos = { forward = 0.43, up = -0.63, right = 0.33 } },
		RightLeg = { raise = -20.3, pos = { forward = 0.58, up = 0.08 } },
		LeftLeg = { raise = 19.8, pos = { forward = 0.55, up = 0.97 } },
	},
	[7] = {
		Torso = { twist = 1, pos = { forward = -0.15, up = -0.01 } },
		Head = { nod = -34.2 },
		RightArm = { raise = 156.2, spread = -42.5, swing = 3.8, pos = { forward = 0.45, up = -0.13 } },
		LeftArm = { raise = 158.2, spread = -34.4, swing = -0.6, pos = { forward = 0.42, up = -0.56, right = 0.33 } },
		RightLeg = { raise = -21.4, pos = { forward = 0.6, up = 0.26 } },
		LeftLeg = { raise = 13.5, pos = { forward = 0.55, up = 0.82 } },
	},
	[16] = {
		Torso = { twist = 4.6, pos = { forward = -0.12, up = -0.01 } },
		Head = { nod = -32.2 },
		RightArm = { raise = 157.9, spread = -38.4, swing = 5.1, pos = { forward = 0.48, up = -0.59 } },
		LeftArm = { raise = 158.2, spread = -33.4, swing = -0.6, pos = { forward = 0.41, up = -0.33, right = 0.33 } },
		RightLeg = { raise = -25.1, pos = { forward = 0.69, up = 0.87 } },
		LeftLeg = { raise = -5.8, pos = { forward = 0.56, up = 0.36 } },
	},
	[26] = {
		Torso = { twist = 0.5, pos = { forward = -0.15, up = -0.01 } },
		Head = { nod = -35.5 },
		RightArm = { raise = 154, spread = -37.6, swing = 1.6, pos = { forward = 0.48, up = -0.61 } },
		LeftArm = { raise = 158.2, spread = -32.2, swing = -0.6, pos = { forward = 0.39, up = -0.08, right = 0.33 } },
		RightLeg = { raise = 11.9, pos = { forward = 0.53, up = 0.95 } },
		LeftLeg = { raise = -19.8, pos = { forward = 0.57, up = 0.03 } },
	},
	[33] = {
		Torso = { twist = -0.1, pos = { forward = -0.15, up = -0.01 } },
		Head = { nod = -36.3 },
		RightArm = { raise = 153.8, spread = -37.8, swing = 1.4, pos = { forward = 0.48, up = -0.59 } },
		LeftArm = { raise = 158.2, spread = -31.9, swing = -0.6, pos = { forward = 0.38, up = -0.01, right = 0.33 } },
		RightLeg = { raise = 21.2, pos = { forward = 0.49, up = 0.98 } },
		LeftLeg = { raise = -19.3, pos = { forward = 0.59, up = 0.15 } },
	},
	[44] = {
		Torso = { twist = -2.8, pos = { forward = -0.1, up = -0.01 } },
		Head = { nod = -31.6 },
		RightArm = { raise = 153.8, spread = -40.7, swing = 1.4, pos = { forward = 0.46, up = -0.29 } },
		LeftArm = { raise = 161, spread = -32.1, swing = 1.3, pos = { forward = 0.41, up = -0.33, right = 0.33 } },
		RightLeg = { raise = 1.9, pos = { forward = 0.53, up = 0.56 } },
		LeftLeg = { raise = -16.1, pos = { forward = 0.67, up = 0.88 } },
	},
	[55] = {
		Torso = { twist = -1.9, pos = { forward = -0.12, up = -0.01 } },
		Head = { nod = -34.5 },
		RightArm = { raise = 153.8, spread = -44.2, swing = 1.4, pos = { forward = 0.43, up = 0.07 } },
		LeftArm = { raise = 160.3, spread = -33.6, swing = 0.9, pos = { forward = 0.43, up = -0.59, right = 0.33 } },
		RightLeg = { raise = -20.1, pos = { forward = 0.57, up = 0.08 } },
		LeftLeg = { raise = 17.8, pos = { forward = 0.56, up = 0.97 } },
	},
	[64] = {
		Torso = { pos = { forward = -0.15, up = -0.01 } },
		Head = { nod = -36.7 },
		RightArm = { raise = 154.1, spread = -44.6, swing = 1.7, pos = { forward = 0.43, up = 0.11 } },
		LeftArm = { raise = 158.3, spread = -34.6, swing = -0.5, pos = { forward = 0.43, up = -0.62, right = 0.33 } },
		RightLeg = { raise = -21.6, pos = { forward = 0.61, up = 0.29 } },
		LeftLeg = { raise = 16.4, pos = { forward = 0.55, up = 0.89 } },
	},
	[73] = {
		Torso = { twist = 3, pos = { forward = -0.13, up = -0.01 } },
		Head = { nod = -32.6 },
		RightArm = { raise = 159.8, spread = -39.3, swing = 6.9, pos = { forward = 0.48, up = -0.54 } },
		LeftArm = { raise = 158.2, spread = -34.4, swing = -0.6, pos = { forward = 0.42, up = -0.56, right = 0.33 } },
		RightLeg = { raise = -24.3, pos = { forward = 0.67, up = 0.74 } },
		LeftLeg = { raise = 1.9, pos = { forward = 0.56, up = 0.54 } },
	},
	[79] = {
		Torso = { twist = 4.6, pos = { forward = -0.12, up = -0.01 } },
		Head = { nod = -32.2 },
		RightArm = { raise = 157.9, spread = -38.4, swing = 5.1, pos = { forward = 0.48, up = -0.59 } },
		LeftArm = { raise = 158.2, spread = -33.7, swing = -0.6, pos = { forward = 0.41, up = -0.4, right = 0.33 } },
		RightLeg = { raise = -25.1, pos = { forward = 0.69, up = 0.87 } },
		LeftLeg = { raise = -9.4, pos = { forward = 0.57, up = 0.27 } },
	},
	[89] = {
		Torso = { twist = 0.5, pos = { forward = -0.15, up = -0.01 } },
		Head = { nod = -35.5 },
		RightArm = { raise = 154, spread = -37.6, swing = 1.6, pos = { forward = 0.48, up = -0.61 } },
		LeftArm = { raise = 158.2, spread = -32.3, swing = -0.6, pos = { forward = 0.39, up = -0.09, right = 0.33 } },
		RightLeg = { raise = 11.9, pos = { forward = 0.53, up = 0.95 } },
		LeftLeg = { raise = -19.8, pos = { forward = 0.57, up = 0.03 } },
	},
	[96] = {
		Torso = { twist = -0.1, pos = { forward = -0.15, up = -0.01 } },
		Head = { nod = -36.3 },
		RightArm = { raise = 153.8, spread = -37.8, swing = 1.4, pos = { forward = 0.48, up = -0.59 } },
		LeftArm = { raise = 158.2, spread = -31.9, swing = -0.6, pos = { forward = 0.38, up = -0.01, right = 0.33 } },
		RightLeg = { raise = 21.2, pos = { forward = 0.49, up = 0.98 } },
		LeftLeg = { raise = -19.3, pos = { forward = 0.59, up = 0.15 } },
	},
	[107] = {
		Torso = { twist = -2.8, pos = { forward = -0.1, up = -0.01 } },
		Head = { nod = -31.6 },
		RightArm = { raise = 153.8, spread = -40.1, swing = 1.4, pos = { forward = 0.46, up = -0.36 } },
		LeftArm = { raise = 161, spread = -32.1, swing = 1.3, pos = { forward = 0.41, up = -0.33, right = 0.33 } },
		RightLeg = { raise = 11.4, pos = { forward = 0.51, up = 0.76 } },
		LeftLeg = { raise = -16.1, pos = { forward = 0.67, up = 0.88 } },
	},
	[120] = {
		Torso = { twist = -1.6, pos = { forward = -0.12, up = -0.01 } },
		Head = { nod = -34.4 },
		RightArm = { raise = 153.8, spread = -43.8, swing = 1.4, pos = { forward = 0.44, up = 0.03 } },
		LeftArm = { raise = 159.7, spread = -33.9, swing = 0.5, pos = { forward = 0.43, up = -0.6, right = 0.33 } },
		RightLeg = { raise = -12.1, pos = { forward = 0.56, up = 0.26 } },
		LeftLeg = { raise = 11.7, pos = { forward = 0.58, up = 0.95 } },
	},
	[130] = {
		Torso = { pos = { forward = -0.15, up = -0.01 } },
		Head = { nod = -36.8 },
		RightArm = { raise = 153.8, spread = -45, swing = 1.4, pos = { forward = 0.43, up = 0.15 } },
		LeftArm = { raise = 158.2, spread = -34.7, swing = -0.6, pos = { forward = 0.43, up = -0.63, right = 0.33 } },
		RightLeg = { raise = -20.3, pos = { forward = 0.58, up = 0.08 } },
		LeftLeg = { raise = 19.8, pos = { forward = 0.55, up = 0.97 } },
	},
}

-- reference jump, 0.433 s
local JUMP = {
	[0] = {
		Torso = { lean = 8.5, twist = 3, tilt = -1.7, pos = { forward = -0.09, up = 0.07 } },
		Head = { nod = 3.4 },
		RightArm = { raise = 8.8, spread = 11.2, swing = 9.3, pos = { forward = 0.05, up = -0.24, right = 0.04 } },
		LeftArm = { raise = 8.8, spread = 11.2, swing = 9.3, pos = { forward = 0.05, up = -0.24, right = -0.04 } },
		RightLeg = { raise = 0.4, spread = 2.4, swing = -8.2, pos = { forward = 0.29, up = 0.03, right = 0.03 } },
		LeftLeg = { raise = -2.9, spread = 6.3, swing = -4.2, pos = { forward = 0.3, up = 0.02 } },
	},
	[2] = {
		Torso = { lean = 13.4, twist = 2, tilt = -1.4, pos = { forward = -0.11, up = 0.13 } },
		Head = { tilt = 1.5, nod = 13.9, turn = -1.8 },
		RightArm = { raise = 10.3, spread = 6.5, swing = 6.1, pos = { forward = 0.12, up = -0.27, right = 0.03 } },
		LeftArm = { raise = 10.3, spread = 6.5, swing = 6.1, pos = { forward = 0.12, up = -0.27, right = -0.03 } },
		RightLeg = { raise = 10.7, spread = 1.6, swing = -5.2, pos = { forward = 0.23, up = -0.36, right = 0.01 } },
		LeftLeg = { raise = 2.8, spread = 6, swing = 1.4, pos = { forward = 0.26, up = -0.27, right = -0.02 } },
	},
	[4] = {
		Torso = { lean = 16.9, twist = 0.6, tilt = -1.2, pos = { forward = -0.13, up = 0.17 } },
		Head = { tilt = 1.6, nod = 20.5, turn = -1.6 },
		RightArm = { raise = 12.9, spread = 6.1, swing = 4.1, pos = { forward = 0.18, up = -0.29, right = 0.03 } },
		LeftArm = { raise = 12.9, spread = 6.1, swing = 4.1, pos = { forward = 0.18, up = -0.29, right = -0.03 } },
		RightLeg = { raise = 15.6, spread = -0.5, swing = -5.1, pos = { forward = 0.3, up = -0.58, right = 0.01 } },
		LeftLeg = { raise = 9.7, spread = 3.6, swing = 3, pos = { forward = 0.35, up = -0.54, right = -0.03 } },
	},
	[6] = {
		Torso = { lean = 16.8, twist = -0.5, tilt = -0.9, pos = { forward = -0.12, up = 0.18 } },
		Head = { tilt = 1.6, nod = 25, turn = -1.5 },
		RightArm = { raise = 18.2, spread = 6.4, swing = 2.8, pos = { forward = 0.14, up = -0.25, right = 0.03 } },
		LeftArm = { raise = 18.2, spread = 6.4, swing = 2.8, pos = { forward = 0.14, up = -0.25, right = -0.03 } },
		RightLeg = { raise = 10.9, spread = -0.8, swing = -5, pos = { forward = 0.3, up = -0.47, right = 0.01 } },
		LeftLeg = { raise = 7.4, spread = 2.3, swing = 2.9, pos = { forward = 0.38, up = -0.38, right = -0.02 } },
	},
	[8] = {
		Torso = { lean = 15.5, twist = -1.6, tilt = -0.8, pos = { forward = -0.1, up = 0.18 } },
		Head = { tilt = 1.6, nod = 27.1, turn = -1.4 },
		RightArm = { raise = 28.7, spread = 8.8, swing = 1, pos = { forward = 0.14, up = -0.25, right = 0.03 } },
		LeftArm = { raise = 28.7, spread = 8.8, swing = 1, pos = { forward = 0.14, up = -0.25, right = -0.03 } },
		RightLeg = { raise = 5.3, spread = 1, swing = -1.8, pos = { forward = 0.34, up = -0.07, right = 0.01 } },
		LeftLeg = { raise = 3.4, spread = 2.6, swing = -4.1, pos = { forward = 0.35, up = -0.01 } },
	},
	[10] = {
		Torso = { lean = 12.7, twist = -3, tilt = -0.5, pos = { forward = -0.08, up = 0.18 } },
		Head = { tilt = 1.7, nod = 28.6, turn = -1.3 },
		RightArm = { raise = 28.5, spread = 14.1, swing = 1.3, pos = { forward = 0.19, up = -0.16, right = 0.08 } },
		LeftArm = { raise = 28.5, spread = 14.1, swing = 1.3, pos = { forward = 0.19, up = -0.16, right = -0.08 } },
		RightLeg = { raise = 0.8, spread = 1.4, swing = 0.2, pos = { forward = 0.43, up = 0.3, right = 0.01 } },
		LeftLeg = { raise = 1, spread = 5.6, swing = -4.4, pos = { forward = 0.37, up = 0.36, right = 0.01 } },
	},
	[14] = {
		Torso = { lean = 6.3, twist = -2.6, tilt = -0.1, pos = { forward = -0.04, up = 0.17 } },
		Head = { tilt = 1.6, nod = 22.3, turn = -1.5 },
		RightArm = { raise = 19.3, spread = 32.1, swing = 11.8, pos = { forward = 0.13, up = -0.22, right = 0.14 } },
		LeftArm = { raise = 19.3, spread = 32.1, swing = 11.8, pos = { forward = 0.13, up = -0.22, right = -0.14 } },
		RightLeg = { raise = 1.1, spread = 3.1, swing = -4.1, pos = { forward = 0.57, up = 0.8, right = -0.03 } },
		LeftLeg = { raise = 7, spread = 9.2, swing = -7.9, pos = { forward = 0.46, up = 0.54, right = 0.02 } },
	},
	[16] = {
		Torso = { lean = 3.3, twist = -1.1, tilt = 0.2, pos = { forward = -0.04, up = 0.17 } },
		Head = { tilt = 1.5, nod = 15.2, turn = -1.7 },
		RightArm = { raise = 15.5, spread = 39.2, swing = 11.8, pos = { forward = 0.09, up = -0.28, right = 0.22 } },
		LeftArm = { raise = 15.5, spread = 39.2, swing = 11.8, pos = { forward = 0.09, up = -0.28, right = -0.22 } },
		RightLeg = { raise = 0.4, spread = 2.8, swing = -3.5, pos = { forward = 0.59, up = 0.88, right = -0.02 } },
		LeftLeg = { raise = 2.9, spread = 8.2, swing = -4.4, pos = { forward = 0.6, up = 0.63, right = 0.02 } },
	},
	[18] = {
		Torso = { lean = 1, twist = 1.6, tilt = 0.2, pos = { forward = -0.08, up = 0.17, right = 0.01 } },
		Head = { tilt = 0.8, nod = 7.4, turn = -1.9 },
		RightArm = { raise = 17.8, spread = 49.2, swing = 7.1, pos = { forward = 0.09, up = -0.28, right = 0.22 } },
		LeftArm = { raise = 17.8, spread = 49.2, swing = 7.1, pos = { forward = 0.09, up = -0.28, right = -0.22 } },
		RightLeg = { raise = -1.2, spread = 3.3, swing = -2.9, pos = { forward = 0.6, up = 0.86, right = -0.01 } },
		LeftLeg = { raise = 2, spread = 6, swing = -0.1, pos = { forward = 0.64, up = 0.69, right = 0.03 } },
	},
	[20] = {
		Torso = { lean = -1.1, twist = 2, tilt = -0.1, pos = { forward = -0.12, up = 0.17, right = 0.01 } },
		Head = { tilt = -0.8, nod = 3.6, turn = -1 },
		RightArm = { raise = 10.1, spread = 58.4, swing = 2.9, pos = { forward = -0.04, up = -0.21, right = 0.26 } },
		LeftArm = { raise = 10.1, spread = 58.4, swing = 2.9, pos = { forward = -0.04, up = -0.21, right = -0.26 } },
		RightLeg = { raise = -3.3, spread = 4.1, swing = -0.5, pos = { forward = 0.61, up = 0.79, right = -0.03 } },
		LeftLeg = { spread = 4.7, swing = -0.3, pos = { forward = 0.61, up = 0.7, right = 0.03 } },
	},
	[22] = {
		Torso = { lean = -2.6, twist = 1.6, pos = { forward = -0.14, up = 0.17, right = 0.01 } },
		Head = { tilt = -0.8, nod = 5.2, turn = -1.1 },
		RightArm = { raise = 5, spread = 64.9, swing = -1.6, pos = { forward = -0.03, up = -0.27, right = 0.2 } },
		LeftArm = { raise = 5, spread = 64.9, swing = -1.6, pos = { forward = -0.03, up = -0.27, right = -0.2 } },
		RightLeg = { raise = -5.1, spread = 4.7, swing = -0.7, pos = { forward = 0.57, up = 0.67, right = -0.03 } },
		LeftLeg = { raise = -4.2, spread = 4.7, swing = -0.6, pos = { forward = 0.57, up = 0.64, right = 0.02 } },
	},
	[26] = {
		Torso = { lean = -5.1, twist = -1, pos = { forward = -0.16, up = 0.13, right = 0.01 } },
		Head = { tilt = -0.8, nod = 14.5, turn = -1.2 },
		RightArm = { raise = 1.6, spread = 62.5, swing = -7.9, pos = { forward = -0.01, up = -0.2, right = 0.15 } },
		LeftArm = { raise = 1.6, spread = 62.5, swing = -7.9, pos = { forward = -0.01, up = -0.2, right = -0.15 } },
		RightLeg = { raise = -12.1, spread = 6.6, swing = -1.3, pos = { forward = 0.49, up = 0.33 } },
		LeftLeg = { raise = -12.1, spread = 4.8, swing = -1.3, pos = { forward = 0.51, up = 0.42, right = 0.01 } },
	},
}

-- reference fall, 1.35 s loop
local FALL = {
	[0] = {
		Torso = { lean = -5.1, twist = -1, pos = { forward = -0.16, up = 0.13, right = 0.01 } },
		Head = { tilt = -0.8, nod = 14.5, turn = -1.2 },
		RightArm = { raise = 1.6, spread = 62.5, swing = -7.9, pos = { forward = -0.01, up = -0.2, right = 0.15 } },
		LeftArm = { raise = 3.6, spread = 73.6, swing = -4.1, pos = { up = -0.46, right = -0.2 } },
		RightLeg = { raise = -12.1, spread = 6.6, swing = -1.3, pos = { forward = 0.49, up = 0.33 } },
		LeftLeg = { raise = -12.1, spread = 4.8, swing = -1.3, pos = { forward = 0.51, up = 0.42, right = 0.01 } },
	},
	[2] = {
		Torso = { lean = -5.8, twist = -1.7, tilt = 0.5, pos = { forward = -0.17, up = 0.13, right = 0.01 } },
		Head = { tilt = -0.9, nod = 17.4, turn = -1.2 },
		RightArm = { raise = 6.2, spread = 59.6, swing = -5, pos = { forward = -0.01, up = -0.21, right = 0.17 } },
		LeftArm = { raise = 4.6, spread = 79.6, swing = -7.2, pos = { up = -0.5, right = -0.2 } },
		RightLeg = { raise = -6.5, spread = 10.3, swing = -4.4, pos = { forward = 0.17, up = 0.21 } },
		LeftLeg = { raise = -2.9, spread = 4.7, swing = -0.5, pos = { forward = 0.43, up = 0.42, right = 0.01 } },
	},
	[8] = {
		Torso = { lean = -5.6, twist = -0.3, tilt = 0.5, pos = { forward = -0.15, up = 0.07, right = 0.01 } },
		Head = { tilt = -0.8, nod = 2.8, turn = -1 },
		RightArm = { raise = 21.6, spread = 57.3, swing = 12.4, pos = { forward = 0.01, up = -0.2, right = 0.16 } },
		LeftArm = { raise = 3.8, spread = 73.7, swing = -11, pos = { forward = -0.07, up = -0.5, right = -0.18 } },
		RightLeg = { raise = -45.9, spread = 6.8, swing = -0.9, pos = { forward = 0.61, up = -0.2 } },
		LeftLeg = { raise = 18.1, spread = 4.9, swing = 1.3, pos = { forward = -0.01, up = 0.17, right = -0.01 } },
	},
	[10] = {
		Torso = { lean = -5.4, twist = 1, tilt = -0.3, pos = { forward = -0.12, up = 0.06, right = 0.01 } },
		Head = { tilt = -0.8, nod = 2.3, turn = -1 },
		RightArm = { raise = 27.2, spread = 61.9, swing = 14.2, pos = { forward = 0.01, up = -0.2, right = 0.16 } },
		LeftArm = { raise = 5.1, spread = 67.6, swing = -4.3, pos = { forward = -0.07, up = -0.49, right = -0.18 } },
		RightLeg = { raise = -55.7, spread = 4.5, swing = -3, pos = { forward = 0.77, up = -0.3, right = -0.01 } },
		LeftLeg = { raise = 7.1, spread = 4.7, swing = 0.3, pos = { forward = 0.04, up = 0.03, right = -0.02 } },
	},
	[14] = {
		Torso = { lean = -4.7, twist = 2.5, tilt = -1.7, pos = { forward = -0.1, up = 0.07 } },
		Head = { tilt = -0.8, nod = 12.2, turn = -1.2 },
		RightArm = { raise = 21.4, spread = 71.2, swing = 4.5, pos = { forward = 0.04, up = -0.19, right = 0.16 } },
		LeftArm = { raise = 6.1, spread = 68.6, swing = 9, pos = { forward = -0.02, up = -0.44, right = -0.21 } },
		RightLeg = { raise = -36.4, spread = 2.4, swing = -6.1, pos = { forward = 1.17, up = 0.2, right = 0.06 } },
		LeftLeg = { raise = -16.3, spread = 4.5, swing = -1.6, pos = { forward = -0.02, up = 0.02, right = -0.02 } },
	},
	[18] = {
		Torso = { lean = -4.3, twist = 3.2, tilt = -2.5, pos = { forward = -0.11, up = 0.09 } },
		Head = { tilt = -0.8, nod = 11.2, turn = -1.1 },
		RightArm = { raise = 11.8, spread = 67.6, swing = -15.7, pos = { forward = 0.03, up = -0.19, right = 0.16 } },
		LeftArm = { raise = 3.6, spread = 79.2, swing = 10.2, pos = { forward = 0.03, up = -0.42, right = -0.24 } },
		RightLeg = { raise = 3, spread = 2.6, swing = -3.8, pos = { forward = 0.6, up = 0.39, right = 0.01 } },
		LeftLeg = { raise = -41.4, spread = 5.9, swing = -4.2, pos = { forward = 0.44, right = -0.03 } },
	},
	[20] = {
		Torso = { lean = -5.2, twist = 2.7, tilt = -2.4, pos = { forward = -0.1, up = 0.12 } },
		Head = { tilt = -0.8, nod = 14, turn = -1.2 },
		RightArm = { raise = 8.5, spread = 62, swing = -19.6, pos = { forward = 0.03, up = -0.19, right = 0.16 } },
		LeftArm = { raise = 3.1, spread = 81, swing = 6.6, pos = { forward = 0.03, up = -0.43, right = -0.24 } },
		RightLeg = { raise = 13.8, spread = 4, swing = -7.3, pos = { forward = 0.27, up = 0.25 } },
		LeftLeg = { raise = -40.7, spread = 5.8, swing = -4.1, pos = { forward = 0.51, up = 0.02, right = -0.03 } },
	},
	[22] = {
		Torso = { lean = -6.5, twist = 1, tilt = -1.9, pos = { forward = -0.08, up = 0.12 } },
		Head = { tilt = -0.8, nod = 8.7, turn = -1.1 },
		RightArm = { raise = 8.5, spread = 55.4, swing = -17.8, pos = { forward = 0.02, up = -0.19, right = 0.16 } },
		LeftArm = { raise = 2.7, spread = 79.6, swing = -1.5, pos = { forward = 0.02, up = -0.37, right = -0.25 } },
		RightLeg = { raise = 16.9, spread = 6.8, swing = -1.5, pos = { forward = 0.05, up = 0.09, right = -0.02 } },
		LeftLeg = { raise = -37, spread = 5.6, swing = -3.6, pos = { forward = 0.56, up = 0.12, right = -0.02 } },
	},
	[26] = {
		Torso = { lean = -6.4, twist = -1.9, tilt = -0.7, pos = { forward = -0.08, up = 0.1, right = 0.01 } },
		Head = { tilt = -0.8, nod = 1.8, turn = -1 },
		RightArm = { raise = 12.9, spread = 56.1, swing = -0.8, pos = { forward = 0.01, up = -0.2, right = 0.16 } },
		LeftArm = { raise = -0.8, spread = 68.8, swing = -15.1, pos = { forward = -0.07, up = -0.34, right = -0.23 } },
		RightLeg = { raise = -6, spread = 5.4, swing = -2.8, pos = { forward = 0.09, up = 0.1, right = -0.02 } },
		LeftLeg = { raise = -7.9, spread = 4.5, swing = -0.9, pos = { forward = 0.61, up = 0.39 } },
	},
	[28] = {
		Torso = { lean = -5.9, twist = -2.4, tilt = -0.3, pos = { forward = -0.08, up = 0.08, right = 0.01 } },
		Head = { tilt = -0.8, nod = 1.2, turn = -1 },
		RightArm = { raise = 12.6, spread = 61.7, swing = 5.8, pos = { forward = 0.09, up = -0.18, right = 0.15 } },
		LeftArm = { raise = -1.2, spread = 64, swing = -16.7, pos = { forward = -0.06, up = -0.36, right = -0.23 } },
		RightLeg = { raise = -25.5, spread = 1.9, swing = 0.9, pos = { forward = 0.3, up = 0.07, right = -0.02 } },
		LeftLeg = { raise = 6.7, spread = 4.6, swing = 0.3, pos = { forward = 0.48, up = 0.56, right = 0.02 } },
	},
	[30] = {
		Torso = { lean = -5.3, twist = -2.9, pos = { forward = -0.08, up = 0.07, right = 0.01 } },
		Head = { tilt = -0.8, nod = 1.3, turn = -1 },
		RightArm = { raise = 14, spread = 69.1, swing = 11.7, pos = { forward = 0.07, up = -0.18, right = 0.15 } },
		LeftArm = { raise = -0.2, spread = 60.1, swing = -14.4, pos = { forward = -0.07, up = -0.37, right = -0.22 } },
		RightLeg = { raise = -42.8, spread = 3.4, swing = -0.8, pos = { forward = 0.63, up = 0.01, right = -0.02 } },
		LeftLeg = { raise = 12.7, spread = 4.7, swing = 0.7, pos = { forward = 0.35, up = 0.58, right = 0.02 } },
	},
	[33] = {
		Torso = { lean = -4.3, twist = -2.6, tilt = -0.3, pos = { forward = -0.09, up = 0.07, right = 0.01 } },
		Head = { tilt = -0.8, nod = 8.5, turn = -1.1 },
		RightArm = { raise = 12.4, spread = 78.5, swing = 9.7, pos = { forward = 0.05, up = -0.19, right = 0.15 } },
		LeftArm = { raise = 6.3, spread = 61.2, swing = -6.3, pos = { forward = -0.02, up = -0.39, right = -0.21 } },
		RightLeg = { raise = -51.1, spread = 5.8, swing = -3.1, pos = { forward = 0.99, up = 0.06, right = -0.02 } },
		LeftLeg = { raise = 15.5, spread = 4.8, swing = 1, pos = { forward = 0.19, up = 0.41, right = 0.01 } },
	},
	[36] = {
		Torso = { lean = -4.2, twist = -0.7, tilt = -0.8, pos = { forward = -0.12, up = 0.09 } },
		Head = { tilt = -0.8, nod = 14.5, turn = -1.2 },
		RightArm = { raise = 8.2, spread = 79.8, swing = -2.1, pos = { forward = 0.03, up = -0.19, right = 0.15 } },
		LeftArm = { raise = 12.6, spread = 67.7, swing = 7.2, pos = { forward = 0.05, up = -0.41, right = -0.21 } },
		RightLeg = { raise = -36.3, spread = 6, swing = -2.4, pos = { forward = 1.1, up = 0.19, right = -0.02 } },
		LeftLeg = { raise = 8.1, spread = 4.7, swing = 0.4, pos = { up = 0.12, right = -0.02 } },
	},
	[39] = {
		Torso = { lean = -4.5, twist = 0.3, tilt = -0.2, pos = { forward = -0.15, up = 0.12 } },
		Head = { tilt = -0.8, nod = 15.3, turn = -1.2 },
		RightArm = { raise = 2.3, spread = 73.5, swing = -12.6, pos = { up = -0.2, right = 0.15 } },
		LeftArm = { raise = 16.5, spread = 79.4, swing = 23.5, pos = { forward = 0.02, up = -0.44, right = -0.21 } },
		RightLeg = { raise = -15, spread = 6.1, swing = -1, pos = { forward = 1.04, up = 0.34, right = -0.02 } },
		LeftLeg = { raise = -14.4, spread = 4.8, swing = -1.5, pos = { forward = 0.02, up = 0.04, right = -0.02 } },
	},
	[43] = {
		Torso = { lean = -5.6, twist = -2.3, tilt = 0.1, pos = { forward = -0.14, up = 0.13, right = 0.01 } },
		Head = { tilt = -0.8, nod = 7.3, turn = -1.1 },
		RightArm = { raise = 3.8, spread = 66.4, swing = -2.7, pos = { forward = -0.01, up = -0.2, right = 0.15 } },
		LeftArm = { raise = 9.2, spread = 89.6, swing = 13, pos = { forward = 0.01, up = -0.46, right = -0.25 } },
		RightLeg = { raise = -0.5, spread = 6.5, swing = 0.1, pos = { forward = 0.57, up = 0.21, right = 0.01 } },
		LeftLeg = { raise = -41, spread = 7.3, swing = -4.3, pos = { forward = 0.35, up = 0.07, right = -0.02 } },
	},
	[46] = {
		Torso = { lean = -5.3, twist = -2.8, tilt = 0.1, pos = { forward = -0.12, up = 0.11, right = 0.01 } },
		Head = { tilt = -0.8, nod = 1.6, turn = -1 },
		RightArm = { raise = 8.9, spread = 62.9, swing = 8.1, pos = { forward = 0.02, up = -0.2, right = 0.15 } },
		LeftArm = { raise = 8.2, spread = 86.4, swing = -3.7, pos = { forward = 0.03, up = -0.38, right = -0.28 } },
		RightLeg = { raise = 1.1, spread = 6.5, swing = 0.2, pos = { forward = 0.21, up = 0.09, right = 0.03 } },
		LeftLeg = { raise = -55.3, spread = 11, swing = -7.8, pos = { forward = 0.85, up = 0.08, right = -0.01 } },
	},
	[50] = {
		Torso = { lean = -3.5, twist = -0.3, tilt = -0.4, pos = { forward = -0.12, up = 0.09, right = 0.01 } },
		Head = { tilt = -0.8, nod = 1.8, turn = -1 },
		RightArm = { raise = 11.3, spread = 66.7, swing = 12.2, pos = { forward = 0.04, up = -0.19, right = 0.15 } },
		LeftArm = { raise = 6.5, spread = 80.7, swing = -15.4, pos = { forward = -0.1, up = -0.41, right = -0.24 } },
		RightLeg = { raise = -6.3, spread = 6.5, swing = -0.6, pos = { forward = -0.01, up = 0.11, right = 0.03 } },
		LeftLeg = { raise = -34.1, spread = 7.4, swing = -3.1, pos = { forward = 1.15, up = 0.5, right = 0.04 } },
	},
	[54] = {
		Torso = { lean = -2.4, twist = 1.1, tilt = -1.1, pos = { forward = -0.13, up = 0.11 } },
		Head = { tilt = -0.8, nod = 10.5, turn = -1.1 },
		RightArm = { raise = 10.7, spread = 73.3, swing = 10.8, pos = { forward = 0.03, up = -0.19, right = 0.15 } },
		LeftArm = { raise = 5.2, spread = 66.6, swing = -17.2, pos = { forward = -0.1, up = -0.42, right = -0.23 } },
		RightLeg = { raise = -22.2, spread = 7, swing = -2.5, pos = { forward = 0.2, up = 0.11, right = 0.03 } },
		LeftLeg = { raise = 6.4, spread = 6, swing = 1.5, pos = { forward = 0.8, up = 0.52, right = 0.03 } },
	},
	[56] = {
		Torso = { lean = -3.1, twist = 0.8, tilt = -1.1, pos = { forward = -0.12, up = 0.11 } },
		Head = { tilt = -0.8, nod = 12.2, turn = -1.2 },
		RightArm = { raise = 10.1, spread = 75.8, swing = 9.2, pos = { forward = 0.03, up = -0.19, right = 0.15 } },
		LeftArm = { raise = 7, spread = 62.2, swing = -15.5, pos = { forward = -0.09, up = -0.42, right = -0.23 } },
		RightLeg = { raise = -30.1, spread = 5.1, swing = -3.8, pos = { forward = 0.37, up = 0.11, right = 0.03 } },
		LeftLeg = { raise = 18.2, spread = 6.1, swing = 2.7, pos = { forward = 0.38, up = 0.28 } },
	},
	[58] = {
		Torso = { lean = -4, twist = -0.2, tilt = -0.7, pos = { forward = -0.12, up = 0.11 } },
		Head = { tilt = -0.8, nod = 11.9, turn = -1.2 },
		RightArm = { raise = 9.2, spread = 77.5, swing = 6.3, pos = { forward = 0.03, up = -0.19, right = 0.15 } },
		LeftArm = { raise = 10.5, spread = 58.8, swing = -14.3, pos = { forward = -0.03, up = -0.41, right = -0.23 } },
		RightLeg = { raise = -39.2, spread = 4.6, swing = -4.8, pos = { forward = 0.61, up = 0.1, right = 0.04 } },
		LeftLeg = { raise = 19, spread = 6, swing = 2.7, pos = { forward = 0.17, up = 0.12, right = -0.02 } },
	},
	[60] = {
		Torso = { lean = -4.4, twist = -1.6, tilt = -0.1, pos = { forward = -0.12, up = 0.09, right = -0.01 } },
		Head = { tilt = -0.8, nod = 9.6, turn = -1.1 },
		RightArm = { raise = 8, spread = 77.3, swing = 2.2, pos = { forward = 0.02, up = -0.2, right = 0.15 } },
		LeftArm = { raise = 14.8, spread = 58.4, swing = -8.9, pos = { forward = 0.03, up = -0.4, right = -0.24 } },
		RightLeg = { raise = -45.9, spread = 5.4, swing = -5.5, pos = { forward = 0.86, up = 0.12, right = 0.04 } },
		LeftLeg = { raise = 18.2, spread = 5.9, swing = 2.5, pos = { forward = -0.02, up = 0.08, right = -0.03 } },
	},
	[62] = {
		Torso = { lean = -4.5, twist = -2.9, tilt = 0.4, pos = { forward = -0.12, up = 0.07, right = -0.01 } },
		Head = { tilt = -0.8, nod = 5.7, turn = -1.1 },
		RightArm = { raise = 7.2, spread = 74.6, swing = -0.2, pos = { forward = 0.02, up = -0.2, right = 0.15 } },
		LeftArm = { raise = 18.2, spread = 63.9, swing = -0.1, pos = { forward = 0.03, up = -0.4, right = -0.24 } },
		RightLeg = { raise = -48.8, spread = 5.8, swing = -6, pos = { forward = 1.04, up = 0.15, right = 0.05 } },
		LeftLeg = { raise = 4.5, spread = 5.5, swing = 1, pos = { forward = 0.03, up = 0.12, right = -0.02 } },
	},
	[65] = {
		Torso = { lean = -3.9, twist = -2.7, tilt = 0.7, pos = { forward = -0.13, up = 0.07 } },
		Head = { tilt = -0.8, nod = 0.1, turn = -1 },
		RightArm = { raise = 5.9, spread = 65.4, swing = -3.1, pos = { forward = 0.01, up = -0.2, right = 0.15 } },
		LeftArm = { raise = 19.5, spread = 73.5, swing = 8.6, pos = { forward = 0.02, up = -0.41, right = -0.23 } },
		RightLeg = { raise = -39.1, spread = 5.2, swing = -4.6, pos = { forward = 1.19, up = 0.37, right = 0.03 } },
		LeftLeg = { raise = -13.6, spread = 5.5, swing = -0.8, pos = { forward = 0.11, up = 0.16, right = -0.02 } },
	},
	[70] = {
		Torso = { lean = -2.4, twist = -0.4, pos = { forward = -0.13, up = 0.13 } },
		Head = { tilt = -0.8, nod = -1.3, turn = -1 },
		RightArm = { raise = 6.6, spread = 58.3, swing = 0.2, pos = { forward = 0.01, up = -0.2, right = 0.15 } },
		LeftArm = { raise = 14.2, spread = 79.7, swing = 2.1, pos = { forward = 0.01, up = -0.43, right = -0.22 } },
		RightLeg = { raise = -17.5, spread = 4.6, swing = -2.4, pos = { forward = 1.11, up = 0.49, right = 0.02 } },
		LeftLeg = { raise = -37.9, spread = 6.5, swing = -3.8, pos = { forward = 0.51, up = 0.15, right = -0.02 } },
	},
	[75] = {
		Torso = { lean = -2.8, twist = -0.1, tilt = -0.7, pos = { forward = -0.16, up = 0.13 } },
		Head = { tilt = -0.8, nod = 12.8, turn = -1.2 },
		RightArm = { raise = 8.9, spread = 68.5, swing = 8.1, pos = { up = -0.2, right = 0.15 } },
		LeftArm = { raise = 8.1, spread = 75.5, swing = -11, pos = { forward = 0.01, up = -0.44, right = -0.21 } },
		RightLeg = { raise = 4.5, spread = 4.9, swing = -0.4, pos = { forward = 0.66, up = 0.57 } },
		LeftLeg = { raise = -28.6, spread = 5.7, swing = -2.7, pos = { forward = 0.73, up = 0.47, right = 0.01 } },
	},
	[78] = {
		Torso = { lean = -3.9, twist = -0.5, tilt = -0.4, pos = { forward = -0.17, up = 0.14 } },
		Head = { tilt = -0.9, nod = 17.5, turn = -1.2 },
		RightArm = { raise = 6.6, spread = 68.4, swing = 2.3, pos = { forward = -0.01, up = -0.2, right = 0.15 } },
		LeftArm = { raise = 4.8, spread = 70.7, swing = -9, pos = { up = -0.45, right = -0.21 } },
		RightLeg = { raise = 8.3, spread = 5.2, swing = 0.1, pos = { forward = 0.32, up = 0.38, right = 0.01 } },
		LeftLeg = { raise = -15.7, spread = 5, swing = -1.5, pos = { forward = 0.53, up = 0.48, right = 0.01 } },
	},
	[81] = {
		Torso = { lean = -5.1, twist = -1, pos = { forward = -0.16, up = 0.13, right = 0.01 } },
		Head = { tilt = -0.8, nod = 14.5, turn = -1.2 },
		RightArm = { raise = 1.6, spread = 62.5, swing = -7.9, pos = { forward = -0.01, up = -0.2, right = 0.15 } },
		LeftArm = { raise = 3.6, spread = 73.6, swing = -4.1, pos = { up = -0.46, right = -0.2 } },
		RightLeg = { raise = -12.1, spread = 6.6, swing = -1.3, pos = { forward = 0.49, up = 0.33 } },
		LeftLeg = { raise = -12.1, spread = 4.8, swing = -1.3, pos = { forward = 0.51, up = 0.42, right = 0.01 } },
	},
}

-- reference Normal Land, 0.167 s
local LAND = {
	[0] = {
		Torso = { lean = 14.9, twist = -3.7, tilt = -0.5, pos = { forward = 0.32, up = -0.91 } },
		Head = { tilt = -0.4, nod = 26.6, turn = 3.8 },
		RightLeg = { raise = -31.7, spread = 3.2, swing = -1.2, pos = { forward = 0.79, up = 0.33, right = 0.18 } },
		LeftLeg = { raise = 24, spread = 4, swing = 3.9, pos = { forward = 0.71, up = 1.03, right = -0.12 } },
	},
	[10] = {
		Torso = { lean = 33.2, twist = -4.3, tilt = -1.9, pos = { forward = 0.39, up = -0.88 } },
		Head = { tilt = -0.5, nod = 9.8, turn = 4 },
		RightLeg = { raise = -16.9, spread = 1.9, swing = -0.5, pos = { forward = 0.85, up = 0.46, right = 0.17 } },
		LeftLeg = { raise = 44.2, spread = 7.6, swing = 5.8, pos = { forward = 0.65, up = 1.15, right = -0.12 } },
	},
}

-- reference Short, 0.467 s
local LAND_SHORT = {
	[0] = {
		Torso = { pos = { up = -0.09 } },
		Head = { nod = 17.2 },
		RightArm = { raise = -13.9, spread = 55.2, swing = -37.4, pos = { forward = -0.01, up = -0.04, right = 0.24 } },
		LeftArm = { raise = -33.2, spread = 49.7, swing = -5.6, pos = { forward = -0.19, up = -0.11, right = -0.15 } },
		RightLeg = { raise = 0.7, spread = 6.7, swing = -1.9, pos = { forward = 0.46, up = 0.13 } },
		LeftLeg = { raise = 15.1, spread = -1.4, swing = -1.6, pos = { forward = 0.54, up = 0.01, right = -0.03 } },
	},
	[1] = {
		Torso = { lean = 1.1, pos = { forward = 0.01, up = -0.26 } },
		Head = { nod = 17.8 },
		RightArm = { raise = -10.4, spread = 55.8, swing = -24.7, pos = { forward = 0.03, up = -0.09, right = 0.25 } },
		LeftArm = { raise = -27.2, spread = 47.9, swing = 0.6, pos = { forward = -0.12, up = -0.18, right = -0.14 } },
		RightLeg = { raise = -9.1, spread = 7.4, swing = -3.6, pos = { forward = 0.83, up = 0.29, right = -0.01 } },
		LeftLeg = { raise = 7.8, spread = -1.3, swing = -1.5, pos = { forward = 0.81, up = 0.25, right = -0.04 } },
	},
	[3] = {
		Torso = { lean = 3.9, pos = { forward = 0.04, up = -0.64 } },
		Head = { nod = 19.4 },
		RightArm = { raise = -1, spread = 57.4, swing = 7.7, pos = { forward = 0.14, up = -0.22, right = 0.28 } },
		LeftArm = { raise = -11.2, spread = 43.1, swing = 17.6, pos = { forward = 0.07, up = -0.33, right = -0.08 } },
		RightLeg = { raise = -16.6, spread = 9.2, swing = -6.7, pos = { forward = 1.13, up = 0.64, right = -0.03 } },
		LeftLeg = { raise = 5.3, spread = -1.2, swing = -2, pos = { forward = 0.94, up = 0.68, right = -0.06 } },
	},
	[4] = {
		Torso = { lean = 8, pos = { forward = 0.09, up = -0.99 } },
		Head = { nod = 21.9 },
		RightArm = { raise = 10.1, spread = 59, swing = 42.9, pos = { forward = 0.28, up = -0.35, right = 0.26 } },
		LeftArm = { raise = 7.2, spread = 38, swing = 38, pos = { forward = 0.22, up = -0.45, right = 0.02 } },
		RightLeg = { raise = -13.9, spread = 10.6, swing = -9.6, pos = { forward = 1.08, up = 1.05, right = -0.07 } },
		LeftLeg = { raise = 13.2, spread = -1.2, swing = -3.4, pos = { forward = 0.7, up = 1.05, right = -0.07 } },
	},
	[5] = {
		Torso = { lean = 12.9, pos = { forward = 0.15, up = -1.13 } },
		Head = { nod = 24.9 },
		RightArm = { raise = 18.9, spread = 60.1, swing = 66.9, pos = { forward = 0.35, up = -0.43, right = 0.21 } },
		LeftArm = { raise = 21.6, spread = 34.7, swing = 55, pos = { forward = 0.28, up = -0.5, right = 0.1 } },
		RightLeg = { raise = -7.1, spread = 10, swing = -10.6, pos = { forward = 0.89, up = 1.27, right = -0.1 } },
		LeftLeg = { raise = 21.6, spread = -1, swing = -5.3, pos = { forward = 0.44, up = 1.17, right = -0.06 } },
	},
	[6] = {
		Torso = { lean = 18.4, pos = { forward = 0.21, up = -1.15 } },
		Head = { nod = 28.1 },
		RightArm = { raise = 24.4, spread = 60.4, swing = 76.3, pos = { forward = 0.37, up = -0.45, right = 0.17 } },
		LeftArm = { raise = 29.9, spread = 33.8, swing = 66.1, pos = { forward = 0.27, up = -0.5, right = 0.14 } },
		RightLeg = { raise = -2, spread = 8.5, swing = -10, pos = { forward = 0.77, up = 1.33, right = -0.09 } },
		LeftLeg = { raise = 26.6, spread = -0.7, swing = -7.1, pos = { forward = 0.31, up = 1.19, right = -0.05 } },
	},
	[11] = {
		Torso = { lean = 39.6, pos = { forward = 0.42, up = -1.18 } },
		Head = { nod = 37.8 },
		RightArm = { raise = 31.2, spread = 59.3, swing = 80.6, pos = { forward = 0.35, up = -0.44, right = 0.02 } },
		LeftArm = { raise = 39.5, spread = 37.9, swing = 82.4, pos = { forward = 0.22, up = -0.46, right = 0.22 } },
		RightLeg = { raise = 15.8, spread = 3.9, swing = -7.8, pos = { forward = 0.39, up = 1.4, right = -0.05 } },
		LeftLeg = { raise = 43.6, spread = -2, swing = -13.1, pos = { forward = -0.02, up = 1.11, right = -0.01 } },
	},
	[15] = {
		Torso = { lean = 41.8, pos = { forward = 0.43, up = -1.08 } },
		Head = { nod = 35.5 },
		RightArm = { raise = 33.3, spread = 58.1, swing = 82.6, pos = { forward = 0.33, up = -0.44, right = -0.05 } },
		LeftArm = { raise = 42.1, spread = 42.5, swing = 88.1, pos = { forward = 0.21, up = -0.43, right = 0.26 } },
		RightLeg = { raise = 12.7, spread = 4.3, swing = -6.5, pos = { forward = 0.54, up = 1.31, right = -0.05 } },
		LeftLeg = { raise = 39.4, swing = -11.5, pos = { forward = 0.12, up = 1.11, right = -0.01 } },
	},
	[20] = {
		Torso = { lean = 40.3, pos = { forward = 0.42, up = -0.84 } },
		Head = { nod = 20.6 },
		RightArm = { raise = 42.6, spread = 63.3, swing = 100.6, pos = { forward = 0.28, up = -0.51 } },
		LeftArm = { raise = 50.7, spread = 57.3, swing = 105.6, pos = { forward = 0.14, up = -0.48, right = 0.23 } },
		RightLeg = { raise = 6.5, spread = 4.9, swing = -4.7, pos = { forward = 0.78, up = 1.08, right = -0.04 } },
		LeftLeg = { raise = 30.2, spread = 3.1, swing = -8.6, pos = { forward = 0.41, up = 1.01, right = -0.01 } },
	},
	[23] = {
		Torso = { lean = 32.8, pos = { forward = 0.35, up = -0.7 } },
		Head = { nod = 12.6 },
		RightArm = { raise = 39.9, spread = 50.9, swing = 91, pos = { forward = 0.14, up = -0.45, right = 0.06 } },
		LeftArm = { raise = 47.1, spread = 49.2, swing = 94, pos = { forward = -0.02, up = -0.43, right = 0.13 } },
		RightLeg = { raise = -3.8, spread = 5.7, swing = -4, pos = { forward = 0.98, up = 0.86, right = -0.04 } },
		LeftLeg = { raise = 17.4, spread = 5.4, swing = -7.2, pos = { forward = 0.68, up = 0.91 } },
	},
	[26] = {
		Torso = { lean = 21.8, pos = { forward = 0.24, up = -0.55 } },
		Head = { nod = 4.7 },
		RightArm = { raise = 22.1, spread = 28.1, swing = 67.1, pos = { forward = -0.17, up = -0.26, right = 0.23 } },
		LeftArm = { raise = 27.4, spread = 24.2, swing = 54.9, pos = { forward = -0.31, up = -0.26, right = -0.13 } },
		RightLeg = { raise = -17, spread = 6.4, swing = -3.3, pos = { forward = 1.13, up = 0.54, right = -0.04 } },
		LeftLeg = { raise = 0.8, spread = 7.6, swing = -6.1, pos = { forward = 0.97, up = 0.68 } },
	},
	[28] = {
		Torso = { lean = 20.7, pos = { forward = 0.23, up = -0.53 } },
		Head = { nod = 4 },
		RightArm = { raise = 17.8, spread = 25.9, swing = 63.9, pos = { forward = -0.2, up = -0.24, right = 0.23 } },
		LeftArm = { raise = 21.6, spread = 21.4, swing = 49.7, pos = { forward = -0.31, up = -0.23, right = -0.13 } },
		RightLeg = { raise = -18.3, spread = 6.4, swing = -3.3, pos = { forward = 1.13, up = 0.5, right = -0.04 } },
		LeftLeg = { raise = -0.8, spread = 7.8, swing = -6, pos = { forward = 1, up = 0.65 } },
	},
}

-- reference Long, 0.667 s
local LAND_LONG = {
	[0] = {
		Torso = { lean = -13.9, pos = { up = -0.09 } },
		Head = { nod = 17.2 },
		RightArm = { raise = -13.9, spread = 55.2, swing = -37.4, pos = { forward = -0.01, up = -0.04, right = 0.24 } },
		LeftArm = { raise = -33.2, spread = 49.7, swing = -5.6, pos = { forward = -0.19, up = -0.11, right = -0.15 } },
		RightLeg = { raise = 0.7, spread = 6.7, swing = -1.9, pos = { forward = 0.46, up = 0.13 } },
		LeftLeg = { raise = 15.1, spread = -1.4, swing = -1.6, pos = { forward = 0.54, up = 0.01, right = -0.03 } },
	},
	[1] = {
		Torso = { lean = -14.3, pos = { forward = 0.01, up = -0.26 } },
		Head = { nod = 17.8 },
		RightArm = { raise = -10.4, spread = 55.8, swing = -24.7, pos = { forward = 0.03, up = -0.09, right = 0.25 } },
		LeftArm = { raise = -27.2, spread = 47.9, swing = 0.6, pos = { forward = -0.12, up = -0.18, right = -0.14 } },
		RightLeg = { raise = -9.1, spread = 7.4, swing = -3.6, pos = { forward = 0.83, up = 0.29, right = -0.01 } },
		LeftLeg = { raise = 7.8, spread = -1.3, swing = -1.5, pos = { forward = 0.81, up = 0.25, right = -0.04 } },
	},
	[3] = {
		Torso = { lean = 3.9, pos = { forward = 0.04, up = -0.64 } },
		Head = { nod = 19.4 },
		RightArm = { raise = -1, spread = 57.4, swing = 7.7, pos = { forward = 0.14, up = -0.22, right = 0.28 } },
		LeftArm = { raise = -11.2, spread = 43.1, swing = 17.6, pos = { forward = 0.07, up = -0.33, right = -0.08 } },
		RightLeg = { raise = -16.6, spread = 9.2, swing = -6.7, pos = { forward = 1.13, up = 0.64, right = -0.03 } },
		LeftLeg = { raise = 5.3, spread = -1.2, swing = -2, pos = { forward = 0.94, up = 0.68, right = -0.06 } },
	},
	[4] = {
		Torso = { lean = 8, pos = { forward = 0.09, up = -0.99 } },
		Head = { nod = 21.9 },
		RightArm = { raise = 10.1, spread = 59, swing = 42.9, pos = { forward = 0.28, up = -0.35, right = 0.26 } },
		LeftArm = { raise = 7.2, spread = 38, swing = 38, pos = { forward = 0.22, up = -0.45, right = 0.02 } },
		RightLeg = { raise = -13.9, spread = 10.6, swing = -9.6, pos = { forward = 1.08, up = 1.05, right = -0.07 } },
		LeftLeg = { raise = 13.2, spread = -1.2, swing = -3.4, pos = { forward = 0.7, up = 1.05, right = -0.07 } },
	},
	[5] = {
		Torso = { lean = 12.9, pos = { forward = 0.15, up = -1.13 } },
		Head = { nod = 24.9 },
		RightArm = { raise = 18.9, spread = 60.1, swing = 66.9, pos = { forward = 0.35, up = -0.43, right = 0.21 } },
		LeftArm = { raise = 21.6, spread = 34.7, swing = 55, pos = { forward = 0.28, up = -0.5, right = 0.1 } },
		RightLeg = { raise = -7.1, spread = 10, swing = -10.6, pos = { forward = 0.89, up = 1.27, right = -0.1 } },
		LeftLeg = { raise = 21.6, spread = -1, swing = -5.3, pos = { forward = 0.44, up = 1.17, right = -0.06 } },
	},
	[6] = {
		Torso = { lean = 18.4, pos = { forward = 0.21, up = -1.15 } },
		Head = { nod = 28.1 },
		RightArm = { raise = 24.4, spread = 60.4, swing = 76.3, pos = { forward = 0.37, up = -0.45, right = 0.17 } },
		LeftArm = { raise = 29.9, spread = 33.8, swing = 66.1, pos = { forward = 0.27, up = -0.5, right = 0.14 } },
		RightLeg = { raise = -2, spread = 8.5, swing = -10, pos = { forward = 0.77, up = 1.33, right = -0.09 } },
		LeftLeg = { raise = 26.6, spread = -0.7, swing = -7.1, pos = { forward = 0.31, up = 1.19, right = -0.05 } },
	},
	[11] = {
		Torso = { lean = 39.6, pos = { forward = 0.42, up = -1.18 } },
		Head = { nod = 37.8 },
		RightArm = { raise = 31.2, spread = 59.3, swing = 80.6, pos = { forward = 0.35, up = -0.44, right = 0.02 } },
		LeftArm = { raise = 39.5, spread = 37.9, swing = 82.4, pos = { forward = 0.22, up = -0.46, right = 0.22 } },
		RightLeg = { raise = 15.8, spread = 3.9, swing = -7.8, pos = { forward = 0.39, up = 1.4, right = -0.05 } },
		LeftLeg = { raise = 43.6, spread = -2, swing = -13.1, pos = { forward = -0.02, up = 1.11, right = -0.01 } },
	},
	[25] = {
		Torso = { lean = 56.7, pos = { forward = 0.43, up = -1.17 } },
		Head = { nod = 38.4 },
		RightArm = { raise = 31.9, spread = 58.8, swing = 81, pos = { forward = 0.34, up = -0.44, right = -0.01 } },
		LeftArm = { raise = 40.4, spread = 39.3, swing = 84.4, pos = { forward = 0.22, up = -0.45, right = 0.23 } },
		RightLeg = { raise = 22.8, spread = 3.9, swing = -7, pos = { forward = 0.32, up = 1.58, right = -0.07 } },
		LeftLeg = { raise = 53.8, spread = -2.2, swing = -13.6, pos = { forward = -0.08, up = 1.15 } },
	},
	[27] = {
		Torso = { lean = 50.8, pos = { forward = 0.43, up = -1.09 } },
		Head = { nod = 35.5 },
		RightArm = { raise = 33.3, spread = 58.1, swing = 82.6, pos = { forward = 0.33, up = -0.44, right = -0.05 } },
		LeftArm = { raise = 42.1, spread = 42.5, swing = 88.1, pos = { forward = 0.21, up = -0.43, right = 0.26 } },
		RightLeg = { raise = 17.7, spread = 4.3, swing = -6.4, pos = { forward = 0.46, up = 1.43, right = -0.06 } },
		LeftLeg = { raise = 46.4, spread = -0.4, swing = -11.8, pos = { forward = 0.06, up = 1.12 } },
	},
	[32] = {
		Torso = { lean = 40.3, pos = { forward = 0.42, up = -0.84 } },
		Head = { nod = 20.6 },
		RightArm = { raise = 42.6, spread = 63.3, swing = 100.6, pos = { forward = 0.28, up = -0.51 } },
		LeftArm = { raise = 50.7, spread = 57.3, swing = 105.6, pos = { forward = 0.14, up = -0.48, right = 0.23 } },
		RightLeg = { raise = 6.5, spread = 4.9, swing = -4.7, pos = { forward = 0.78, up = 1.08, right = -0.04 } },
		LeftLeg = { raise = 30.2, spread = 3.1, swing = -8.6, pos = { forward = 0.41, up = 1.01, right = -0.01 } },
	},
	[35] = {
		Torso = { lean = 32.8, pos = { forward = 0.35, up = -0.7 } },
		Head = { nod = 12.6 },
		RightArm = { raise = 39.9, spread = 50.9, swing = 91, pos = { forward = 0.14, up = -0.45, right = 0.06 } },
		LeftArm = { raise = 47.1, spread = 49.2, swing = 94, pos = { forward = -0.02, up = -0.43, right = 0.13 } },
		RightLeg = { raise = -3.8, spread = 5.7, swing = -4, pos = { forward = 0.98, up = 0.86, right = -0.04 } },
		LeftLeg = { raise = 17.4, spread = 5.4, swing = -7.2, pos = { forward = 0.68, up = 0.91 } },
	},
	[38] = {
		Torso = { lean = 21.8, pos = { forward = 0.24, up = -0.55 } },
		Head = { nod = 4.7 },
		RightArm = { raise = 22.1, spread = 28.1, swing = 67.1, pos = { forward = -0.17, up = -0.26, right = 0.23 } },
		LeftArm = { raise = 27.4, spread = 24.2, swing = 54.9, pos = { forward = -0.31, up = -0.26, right = -0.13 } },
		RightLeg = { raise = -17, spread = 6.4, swing = -3.3, pos = { forward = 1.13, up = 0.54, right = -0.04 } },
		LeftLeg = { raise = 0.8, spread = 7.6, swing = -6.1, pos = { forward = 0.97, up = 0.68 } },
	},
	[40] = {
		Torso = { lean = 20.7, pos = { forward = 0.23, up = -0.53 } },
		Head = { nod = 4 },
		RightArm = { raise = 17.8, spread = 25.9, swing = 63.9, pos = { forward = -0.2, up = -0.24, right = 0.23 } },
		LeftArm = { raise = 21.6, spread = 21.4, swing = 49.7, pos = { forward = -0.31, up = -0.23, right = -0.13 } },
		RightLeg = { raise = -18.3, spread = 6.4, swing = -3.3, pos = { forward = 1.13, up = 0.5, right = -0.04 } },
		LeftLeg = { raise = -0.8, spread = 7.8, swing = -6, pos = { forward = 1, up = 0.65 } },
	},
}

-- R6 Parkour Animations (asset 15259391918) WallRunR, 0.6 s loop, wall on the right
local WALLRUN = {
	[0] = {
		Torso = { lean = 19.4, twist = -9.3, tilt = -24.7, pos = { up = -0.1, right = -0.03 } },
		Head = { tilt = 16.1, nod = -18.4, turn = 5.5 },
		RightArm = { raise = 139.4, spread = 16.9, swing = 12.8, pos = { forward = 0.37, up = 0.41, right = 0.08 } },
		LeftArm = { raise = 37.6, spread = 37.2, swing = 46.9, pos = { forward = 0.15, up = -0.16, right = 0.05 } },
		RightLeg = { raise = -15.1, spread = -0.7, swing = 9.3, pos = { forward = 1, up = 0.79, right = -0.12 } },
		LeftLeg = { raise = -70.1, spread = 4.1, swing = -12.5, pos = { forward = -0.27, up = -0.16, right = 0.04 } },
	},
	[1] = {
		Torso = { lean = 18.9, twist = -11, tilt = -23.7, pos = { forward = -0.02, up = -0.06, right = -0.02 } },
		Head = { tilt = 15.7, nod = -17.9, turn = 7.1 },
		RightArm = { raise = 139.4, spread = 15, swing = 12.8, pos = { forward = 0.37, up = 0.41, right = 0.08 } },
		LeftArm = { raise = 47, spread = 69.9, swing = 72.8, pos = { forward = 0.29, up = -0.29, right = 0.01 } },
		RightLeg = { raise = -6.1, spread = -0.7, swing = 10.2, pos = { forward = 0.97, up = 0.77, right = -0.14 } },
		LeftLeg = { raise = -73.4, spread = -0.4, swing = -10.4, pos = { forward = -0.29, up = -0.22, right = 0.04 } },
	},
	[2] = {
		Torso = { lean = 18.5, twist = -12.7, tilt = -22.8, pos = { forward = -0.03, up = -0.02, right = -0.01 } },
		Head = { tilt = 15.3, nod = -17.3, turn = 8.6 },
		RightArm = { raise = 139.4, spread = 13.1, swing = 12.8, pos = { forward = 0.37, up = 0.41, right = 0.08 } },
		LeftArm = { raise = 43.6, spread = 106.4, swing = 102.8, pos = { forward = 0.44, up = -0.41, right = -0.03 } },
		RightLeg = { raise = 2.9, spread = -0.6, swing = 11.1, pos = { forward = 0.94, up = 0.76, right = -0.15 } },
		LeftLeg = { raise = -76.7, spread = -6.4, swing = -6.8, pos = { forward = -0.31, up = -0.27, right = 0.04 } },
	},
	[3] = {
		Torso = { lean = 18.1, twist = -14.4, tilt = -21.8, pos = { forward = -0.05, up = 0.02, right = -0.01 } },
		Head = { tilt = 14.9, nod = -16.8, turn = 10.1 },
		RightArm = { raise = 139.4, spread = 11.2, swing = 12.8, pos = { forward = 0.37, up = 0.41, right = 0.08 } },
		LeftArm = { raise = 29.6, spread = 133.5, swing = 122.8, pos = { forward = 0.58, up = -0.53, right = -0.06 } },
		RightLeg = { raise = 11.9, spread = -0.4, swing = 12, pos = { forward = 0.91, up = 0.74, right = -0.17 } },
		LeftLeg = { raise = -79.8, spread = -15.4, swing = -0.1, pos = { forward = -0.33, up = -0.33, right = 0.04 } },
	},
	[6] = {
		Torso = { lean = 15.7, twist = -16.4, tilt = -19.9, pos = { up = 0.07, right = 0.01 } },
		Head = { tilt = 13.7, nod = -13.9, turn = 12 },
		RightArm = { raise = 139.4, spread = 5.6, swing = 12.8, pos = { forward = 0.37, up = 0.41, right = 0.08 } },
		LeftArm = { raise = 31.7, spread = 143.1, swing = 136.9, pos = { forward = 0.64, up = -0.46, right = -0.01 } },
		RightLeg = { raise = 38.8, spread = 1.6, swing = 15.6, pos = { forward = 0.86, up = 0.49, right = -0.2 } },
		LeftLeg = { raise = -79.6, spread = -7.8, swing = -8, pos = { forward = -0.14, up = -0.04, right = 0.02 } },
	},
	[9] = {
		Torso = { lean = 14.7, twist = -15, tilt = -18.9, pos = { forward = 0.08, up = 0.12, right = 0.02 } },
		Head = { tilt = 13.2, nod = -12, turn = 11.4 },
		RightArm = { raise = 139.4, swing = 12.8, pos = { forward = 0.37, up = 0.41, right = 0.08 } },
		LeftArm = { raise = 46.8, spread = 142, swing = 135.2, pos = { forward = 0.2, up = -0.61, right = 0.05 } },
		RightLeg = { raise = 45.2, spread = 2.9, swing = 15.1, pos = { forward = 0.7, up = 0.2, right = -0.14 } },
		LeftLeg = { raise = -86, spread = -31.7, swing = 16.3, pos = { forward = -0.03, up = -0.01, right = -0.07 } },
	},
	[12] = {
		Torso = { lean = 16.2, twist = -11.8, tilt = -19.6, pos = { forward = 0.14, up = 0.09, right = 0.03 } },
		Head = { tilt = 16.2, nod = -13.1, turn = 9 },
		RightArm = { raise = 139.4, spread = 10.5, swing = 12.8, pos = { forward = 0.4, up = 0.43, right = 0.09 } },
		LeftArm = { raise = 50.3, spread = 120.8, swing = 116.4, pos = { forward = 0.04, up = -0.63, right = 0.02 } },
		RightLeg = { raise = 27.8, spread = 3, swing = 12.6, pos = { forward = 0.4, up = -0.03, right = -0.08 } },
		LeftLeg = { raise = -70.4, spread = -15.2, swing = 4.3, pos = { forward = 0.39, up = 0.06, right = -0.1 } },
	},
	[14] = {
		Torso = { lean = 16.9, twist = -5.7, tilt = -20.3, pos = { forward = 0.14, up = 0.05, right = 0.04 } },
		Head = { tilt = 19.2, nod = -14.3, turn = 5 },
		RightArm = { raise = 139.4, spread = 17.5, swing = 12.8, pos = { forward = 0.41, up = 0.44, right = 0.1 } },
		LeftArm = { raise = 48.6, spread = 79, swing = 74, pos = { forward = 0.02, up = -0.5, right = 0.07 } },
		RightLeg = { raise = 4.2, spread = 1.8, swing = 5.8, pos = { forward = -0.19, up = -0.16, right = -0.03 } },
		LeftLeg = { raise = -60.1, spread = -10, swing = 5.1, pos = { forward = 0.62, up = 0.11, right = -0.05 } },
	},
	[15] = {
		Torso = { lean = 17.2, twist = -2.7, tilt = -20.6, pos = { forward = 0.14, up = 0.03, right = 0.04 } },
		Head = { tilt = 20.7, nod = -14.8, turn = 3 },
		RightArm = { raise = 139.4, spread = 21, swing = 12.8, pos = { forward = 0.42, up = 0.45, right = 0.11 } },
		LeftArm = { raise = 41.3, spread = 63, swing = 57.7, pos = { up = -0.44, right = 0.1 } },
		RightLeg = { raise = -7.6, spread = 2.3, swing = 2.5, pos = { forward = -0.49, up = -0.22 } },
		LeftLeg = { raise = -54.9, spread = -7.8, swing = 6, pos = { forward = 0.74, up = 0.14, right = -0.03 } },
	},
	[17] = {
		Torso = { lean = 18.7, twist = 5.3, tilt = -21, pos = { forward = 0.05, up = -0.06, right = 0.03 } },
		Head = { tilt = 23.7, nod = -15.3, turn = -7.9 },
		RightArm = { raise = 139.4, spread = 28.1, swing = 12.8, pos = { forward = 0.43, up = 0.46, right = 0.11 } },
		LeftArm = { raise = 26.2, spread = 23.2, swing = 25.8, pos = { forward = -0.04, up = -0.22, right = 0.06 } },
		RightLeg = { raise = -49.3, spread = 0.4, swing = -5.1, pos = { forward = -0.36, up = -0.18, right = -0.03 } },
		LeftLeg = { raise = -28.3, spread = -3, swing = 7.7, pos = { forward = 0.92, up = 0.57, right = 0.07 } },
	},
	[18] = {
		Torso = { lean = 19.4, twist = 9.3, tilt = -21.2, pos = { up = -0.1, right = 0.03 } },
		Head = { tilt = 25.3, nod = -15.3, turn = -13.4 },
		RightArm = { raise = 139.4, spread = 31.6, swing = 12.8, pos = { forward = 0.44, up = 0.47, right = 0.12 } },
		LeftArm = { raise = 13.6, spread = 9.4, swing = 16.7, pos = { forward = -0.07, up = -0.11, right = 0.04 } },
		RightLeg = { raise = -70.1, spread = 4.1, swing = -12.5, pos = { forward = -0.29, up = -0.17, right = -0.04 } },
		LeftLeg = { raise = -15.1, spread = -0.7, swing = 9.3, pos = { forward = 1, up = 0.79, right = 0.12 } },
	},
	[21] = {
		Torso = { lean = 17.6, twist = 12.9, tilt = -19.7, pos = { up = -0.01, right = 0.01 } },
		Head = { tilt = 21.5, nod = -17.6, turn = -10.1 },
		RightArm = { raise = 139.4, spread = 29.1, swing = 12.8, pos = { forward = 0.43, up = 0.46, right = 0.11 } },
		LeftArm = { raise = -21.4, spread = 32, swing = -20.3, pos = { forward = -0.03, up = -0.43, right = -0.04 } },
		RightLeg = { raise = -76.4, spread = -11.5, swing = -4, pos = { forward = -0.33, up = -0.33, right = -0.04 } },
		LeftLeg = { raise = 11.9, spread = -0.4, swing = 12, pos = { forward = 0.91, up = 0.74, right = 0.17 } },
	},
	[24] = {
		Torso = { lean = 15.7, twist = 16.4, tilt = -18.3, pos = { up = 0.07, right = -0.01 } },
		Head = { tilt = 20.5, nod = -14.5, turn = -12 },
		RightArm = { raise = 139.4, spread = 26.7, swing = 12.8, pos = { forward = 0.42, up = 0.45, right = 0.11 } },
		LeftArm = { raise = -13.3, spread = 47.2, swing = -39.6, pos = { forward = -0.03, up = -0.41, right = -0.18 } },
		RightLeg = { raise = -81.6, spread = -9.7, swing = -6.1, pos = { forward = -0.14, up = -0.04, right = -0.02 } },
		LeftLeg = { raise = 38.8, spread = 1.6, swing = 15.6, pos = { forward = 0.86, up = 0.49, right = 0.2 } },
	},
	[27] = {
		Torso = { lean = 14.7, twist = 15, tilt = -18.8, pos = { forward = 0.08, up = 0.12, right = -0.02 } },
		Head = { tilt = 19.8, nod = -13.4, turn = -11.4 },
		RightArm = { raise = 139.4, spread = 24.2, swing = 12.8, pos = { forward = 0.41, up = 0.44, right = 0.1 } },
		LeftArm = { raise = -13.8, spread = 39.1, swing = -41.3, pos = { forward = 0.06, up = -0.4, right = -0.13 } },
		RightLeg = { raise = -83.2, spread = -18.3, swing = 2.9, pos = { forward = -0.03, up = -0.01, right = 0.07 } },
		LeftLeg = { raise = 45.2, spread = 2.9, swing = 15.1, pos = { forward = 0.7, up = 0.2, right = 0.14 } },
	},
	[30] = {
		Torso = { lean = 16.2, twist = 11.8, tilt = -21.1, pos = { forward = 0.14, up = 0.09, right = -0.03 } },
		Head = { tilt = 22.3, nod = -14, turn = -9 },
		RightArm = { raise = 139.4, spread = 21.8, swing = 12.8, pos = { forward = 0.4, up = 0.43, right = 0.09 } },
		LeftArm = { raise = -14.4, spread = 23.2, swing = -23, pos = { forward = 0.07, up = -0.31, right = 0.03 } },
		RightLeg = { raise = -70.4, spread = -15.2, swing = 4.3, pos = { forward = 0.39, up = 0.06, right = 0.1 } },
		LeftLeg = { raise = 27.8, spread = 3, swing = 12.6, pos = { forward = 0.39, up = -0.02, right = 0.08 } },
	},
	[33] = {
		Torso = { lean = 17.2, twist = 2.7, tilt = -21.7, pos = { forward = 0.14, up = 0.03, right = -0.04 } },
		Head = { tilt = 20.7, nod = -14.8, turn = -3 },
		RightArm = { raise = 139.4, spread = 19.3, swing = 12.8, pos = { forward = 0.39, up = 0.42, right = 0.09 } },
		LeftArm = { raise = 12.7, spread = 6.7, swing = -16.1, pos = { forward = 0.24, up = -0.21, right = 0.04 } },
		RightLeg = { raise = -54.9, spread = -7.8, swing = 6, pos = { forward = 0.74, up = 0.14, right = 0.03 } },
		LeftLeg = { raise = -7.6, spread = 2.3, swing = 2.5, pos = { forward = -0.49, up = -0.2, right = 0.01 } },
	},
	[34] = {
		Torso = { lean = 18, twist = -1.3, tilt = -22.6, pos = { forward = 0.09, up = -0.02, right = -0.04 } },
		Head = { tilt = 20.7, nod = -16, turn = -0.2 },
		RightArm = { raise = 139.4, spread = 18.5, swing = 12.8, pos = { forward = 0.38, up = 0.41, right = 0.09 } },
		LeftArm = { raise = 24, spread = 12.6, swing = 1.7, pos = { forward = 0.21, up = -0.19, right = 0.04 } },
		RightLeg = { raise = -41.6, spread = -5.3, swing = 6.6, pos = { forward = 0.83, up = 0.35, right = -0.02 } },
		LeftLeg = { raise = -28.4, spread = 0.6, swing = -1.1, pos = { forward = -0.42, up = -0.19, right = 0.02 } },
	},
	[36] = {
		Torso = { lean = 19.4, twist = -9.3, tilt = -24.7, pos = { up = -0.1, right = -0.03 } },
		Head = { tilt = 20.4, nod = -18.4, turn = 5.5 },
		RightArm = { raise = 139.4, spread = 16.9, swing = 12.8, pos = { forward = 0.37, up = 0.41, right = 0.08 } },
		LeftArm = { raise = 37.6, spread = 37.2, swing = 46.9, pos = { forward = 0.15, up = -0.16, right = 0.05 } },
		RightLeg = { raise = -15.1, spread = -0.7, swing = 9.3, pos = { forward = 1, up = 0.79, right = -0.12 } },
		LeftLeg = { raise = -70.1, spread = 4.1, swing = -12.5, pos = { forward = -0.27, up = -0.16, right = 0.04 } },
	},
}


local function cycle(name, keys, total, ease)
	local c = R6Clip.new(name, { loop = true, priority = "Movement" })
	local half = total / 2
	for frame, pose in keys do
		c:key(frame, pose, ease)
		c:key(frame + half, R6Clip.mirror(pose), ease)
	end
	c:key(total, keys[0], ease)
	return c
end

function Locomotion.Walk()
	local c = cycle("Walk", WALK, 50, "linear")
	-- the feet: each sole touches down at the half cycles; between, one foot is in the air
	c.meta = { cycle = 50, speed = 14.5, stride = true }
	return c
end

function Locomotion.Run()
	local c = cycle("Run", RUN, 38, "linear")
	c.meta = { cycle = 38, speed = 27 / 1.3, stride = true, hop = true }
	return c
end

function Locomotion.Idle()
	local c = R6Clip.new("Idle", { loop = true, priority = "Idle" })
	for frame, pose in IDLE do
		c:key(frame, pose, "sineInOut")
	end
	c:key(113, IDLE[0], "sineInOut")
	c.meta = {}
	return c
end

-- A clip straight from fitted keys (the last key is the clip's end).
local function fromKeys(name, keys, opts)
	local c = R6Clip.new(name, { loop = opts.loop, priority = opts.priority or "Movement", budget = opts.budget })
	for frame, pose in keys do
		if opts.ground then
			-- the reference's soles dip up to 0.15 stud into the floor; slide them back up
			pose = R6Clip.merge(pose, { LeftLeg = { ground = true }, RightLeg = { ground = true } })
		end
		c:key(frame, pose, "linear")
	end
	c.meta = opts.meta or {}
	return c
end

function Locomotion.Climb()
	-- The movement system plays it at climbing speed / 12
	return fromKeys("Climb", CLIMB, { loop = true, meta = { airborne = true, speed = 12 } })
end

function Locomotion.Jump()
	return fromKeys("Jump", JUMP, { meta = { airborne = true } })
end

function Locomotion.Fall()
	-- the legs paddle past each other: a stride in the air
	return fromKeys("Fall", FALL, { loop = true, meta = { airborne = true, stride = true } })
end

local DEEP = { LeftLeg = 1.7, RightLeg = 1.7 }

-- Landings by fall height (the movement system's tiers): a quick dip, a fold with the arms thrown, a deep fold
function Locomotion.Land()
	return fromKeys("Land", LAND, { ground = true, meta = { stride = true, impact = true } })
end

function Locomotion.LandShort()
	-- The movement system's deep landings ride the legs 1.55-1.6 studs into the torso, past the usual 1.5,
	-- both legs at once for a moment: an impact (meta.impact), not a pose to copy
	return fromKeys("LandShort", LAND_SHORT, { ground = true, budget = DEEP, meta = { stride = true, impact = true, bury = 1.6 } })
end

function Locomotion.LandLong()
	return fromKeys("LandLong", LAND_LONG, { ground = true, budget = DEEP, meta = { stride = true, impact = true, bury = 1.6 } })
end

function Locomotion.WallRunRight()
	return fromKeys("WallRunRight", WALLRUN, { loop = true, meta = { airborne = true, stride = true } })
end

function Locomotion.WallRunLeft()
	local mirrored = {}
	for frame, pose in WALLRUN do
		mirrored[frame] = R6Clip.mirror(pose)
	end
	return fromKeys("WallRunLeft", mirrored, { loop = true, meta = { airborne = true, stride = true } })
end

Locomotion.LIST = { "Idle", "Walk", "Run", "Climb", "Jump", "Fall", "Land", "LandShort", "LandLong", "WallRunRight", "WallRunLeft" }

function Locomotion.build(bakeOpts)
	local out = {}
	for _, name in Locomotion.LIST do
		local c = Locomotion[name]()
		out[name] = { clip = c, baked = c:bake(bakeOpts), meta = c.meta }
	end
	return out
end

return Locomotion
