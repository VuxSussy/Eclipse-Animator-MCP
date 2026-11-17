-- CombatMoves: a starter kit of R6 fist moves built with R6Clip, with the gameplay numbers that
-- go with each one. Orthodox stance (left foot and left hand lead). Frames are 60 fps.
--
--   local moves = CombatMoves.build()        -- name -> { clip, baked, meta }
--   moves.Jab.meta.hit, moves.Jab.meta.cancel, moves.Jab.meta.hitstop
--
-- Every pose is keyed: angles plus `pos` slides. No IK, no solver. The size of the moves comes from
-- measured R6 references (references/reference-first.md):
--   * Creator Store R6 punch packs: at contact the torso is turned 30-110 degrees into the punch,
--     leans 15-40, lunges 0.2-0.65 stud and drops 0.2-1.0; the striking arm is pushed 0.5-1.4 stud
--     out of its socket and the fist ends 2.3-4.2 studs in front of the root.
--   * the user's R6 movement system: arms slide 0.4-0.7 stud along their swing, legs ride up
--     into the torso as the body sinks, the head never leaves the neck.
-- Strike anatomy (see references/combat.md):
--   guard -> chamber (load opposite the strike) -> hang -> snap to contact (the "Hit" marker)
--   -> hold 6-8 frames, creeping -> recover into guard with a small settle.

local R6Clip = require(script.Parent.R6Clip)

local CombatMoves = {}

local V = Vector3.new
local merge = R6Clip.merge

-- Legs are keyed against the root (space = "root") so the torso can twist 60 degrees without
-- swinging the feet around, and grounded (ground = true) so every drop of the body becomes the leg
-- riding up into the torso, the movement system's crouch.
local function leg(angles)
	angles.space = "root"
	angles.ground = true
	return angles
end
CombatMoves.leg = leg

-- Guard: lead shoulder at the target, a real sink, fists up at the chin and slid forward out of the
-- shoulders a little (the hands-up silhouette R6 cannot make with rotation alone).
CombatMoves.Guard = {
	Torso = { twist = -25, lean = 10, pos = { up = -0.35 } },
	Head = { nod = -2, turn = 12 }, -- the head counters the lean: the face looks ~8 down (house: 2-13)
	LeftArm = { raise = 138, swing = 32, pos = { forward = 0.2 } },
	RightArm = { raise = 150, swing = 62, pos = { forward = 0.15, right = -0.1 } },
	LeftLeg = leg({ raise = 14, spread = 4, twist = -10 }),
	RightLeg = leg({ raise = -16, spread = 6, twist = -25 }),
}
local G = CombatMoves.Guard

local function clip(name, opts)
	return R6Clip.new(name, opts)
end

-- Lead jab. The chamber hangs and keeps loading, the release takes 3 frames, and the whole body goes
-- with the fist: torso 50 degrees in, a 0.55-stud lunge, the shoulder thrown 0.75 stud forward out
-- of its socket, the rear hand snapping back to the chin. Then it holds, creeping, and snaps home.
function CombatMoves.Jab()
	local c = clip("Jab")
	c:key(0, G, "snap")
	local chamber = merge(G, {
		Torso = { twist = -12, lean = 4, pos = { up = -0.5, forward = -0.25 } },
		LeftArm = { raise = 120, swing = 40, pos = { forward = -0.15, up = -0.05 } },
		Head = { nod = 10, turn = 8 },
	})
	c:key(4, chamber, "sineInOut")
	c:key(7, merge(chamber, { Torso = { twist = -9, lean = 2, pos = { up = -0.53, forward = -0.3 } }, LeftArm = { pos = { forward = -0.2 } } }), "snap")
	local contact = merge(G, {
		Torso = { twist = -50, lean = 22, pos = { up = -0.42, forward = 0.55 } },
		Head = { nod = 4, turn = 26 },
		LeftArm = { raise = 134, swing = -32, pos = { forward = 0.75 } },
		RightArm = { raise = 158, swing = 70, pos = { forward = 0.1, right = -0.15 } },
		LeftLeg = leg({ raise = 24, spread = 4, twist = -12 }),
		RightLeg = leg({ raise = -28, spread = 6, twist = -40, pos = { forward = -0.25 } }),
	})
	c:key(10, contact, { settle = 0.12 })
	c:key(18, merge(contact, { Torso = { twist = -53, lean = 24, pos = { up = -0.44, forward = 0.6 } }, LeftArm = { pos = { forward = 0.82 } } }), "snap")
	c:key(24, merge(G, { Torso = { twist = -30, lean = 12 } }), { settle = 0.1 })
	c:key(30, G)
	c:marker(10, "Hit")
	c:marker(18, "Cancel")
	c:lead("Torso", 1)
	c:lead("Head", -2)
	c.meta = {
		limb = "LeftArm",
		windup = { 0, 9 }, -- telegraph window (R6Combat's wind-up highlight)
		strike = { 7, 10 },
		hit = 10,
		active = { 10, 12 },
		cancel = 18,
		hitstop = 0.075,
		damage = 1,
	}
	return c
end

-- Rear cross. The hips and chest turn all the way through (+60), the rear foot pivots and pushes,
-- the right shoulder is thrown 0.85 stud at the target, the lead hand pulls back to the chin.
function CombatMoves.Cross()
	local c = clip("Cross")
	c:key(0, G, "quadOut")
	local chamber = merge(G, {
		Torso = { twist = -42, lean = 8, pos = { up = -0.48, forward = -0.15 } },
		RightArm = { raise = 128, swing = 66, pos = { forward = -0.2 } },
		Head = { nod = 9, turn = 18 },
	})
	c:key(4, chamber, "sineInOut")
	c:key(7, merge(chamber, { Torso = { twist = -45, pos = { up = -0.5, forward = -0.18 } } }), "snap")
	local contact = merge(G, {
		Torso = { twist = 60, lean = 22, pos = { up = -0.45, forward = 0.6 } },
		Head = { nod = 4, turn = -24 },
		RightArm = { raise = 134, swing = -30, pos = { forward = 0.85 } },
		LeftArm = { raise = 150, swing = 60, pos = { forward = 0.05, right = 0.15 } },
		LeftLeg = leg({ raise = 24, spread = 6, twist = 10 }),
		RightLeg = leg({ raise = -30, spread = 8, twist = 40, pos = { forward = -0.3 } }),
	})
	c:key(11, contact, { settle = 0.12 })
	c:key(19, merge(contact, { Torso = { twist = 63, lean = 24, pos = { forward = 0.65 } }, RightArm = { pos = { forward = 0.9 } } }), { recover = 0.1 })
	c:key(32, G)
	c:marker(11, "Hit")
	c:marker(20, "Cancel")
	c:lead("Torso", 1)
	c:lead("LeftArm", -1)
	c:lead("Head", -2)
	c.meta = { limb = "RightArm", strike = { 7, 11 }, hit = 11, active = { 11, 13 }, cancel = 20, hitstop = 0.08, damage = 1.2 }
	return c
end

-- Lead hook: the arm swings out and around on an arc (rotation keys, so the fist travels a curve)
-- while the shoulder is pushed forward into the turn.
function CombatMoves.Hook()
	local c = clip("Hook")
	c:key(0, G, "sineInOut")
	local chamber = merge(G, {
		Torso = { twist = 5, lean = 10, pos = { up = -0.5, forward = -0.1 } },
		LeftArm = { raise = 30, spread = 80, swing = 5, pos = { right = -0.25 } },
		Head = { nod = 8, turn = 0 },
	})
	c:key(5, chamber, "sineInOut")
	c:key(8, merge(chamber, { Torso = { twist = 9 } }), "snap")
	local contact = merge(G, {
		Torso = { twist = -50, lean = 16, pos = { up = -0.45, forward = 0.4 } },
		Head = { nod = 4, turn = 24 },
		LeftArm = { raise = 15, spread = 100, swing = 52, pos = { forward = 0.55, right = 0.2 } },
		LeftLeg = leg({ raise = 18, spread = 6, twist = -30 }),
		RightLeg = leg({ raise = -22, spread = 8, twist = -35 }),
	})
	c:key(12, contact, { settle = 0.1 })
	c:key(19, merge(contact, { Torso = { twist = -60, lean = 17 }, LeftArm = { swing = 72 } }), { recover = 0.1 }) -- follow-through
	c:key(32, G)
	c:marker(12, "Hit")
	c:marker(21, "Cancel")
	c:lead("Torso", 1)
	c:lead("RightArm", -1)
	c:lead("Head", -2)
	c.meta = { limb = "LeftArm", strike = { 8, 12 }, arc = true, hit = 12, active = { 12, 14 }, cancel = 21, hitstop = 0.085, damage = 1.3 }
	return c
end

-- Rear uppercut: sink deep (the legs ride a full stud into the torso), then drive up through the
-- legs; the fist rises in front of the face with the shoulder thrown up and forward.
-- The finisher of the string: deepest chamber, longest hit-stop.
function CombatMoves.Uppercut()
	local c = clip("Uppercut")
	c:key(0, G, "sineInOut")
	-- the dip the house way: the front leg takes the depth, the back leg stretches long behind
	local chamber = merge(G, {
		Torso = { twist = -35, lean = 28, pos = { up = -0.9, forward = 0.1 } },
		RightArm = { raise = 20, spread = 10, pos = { up = -0.25 } },
		Head = { nod = 14, turn = 14 },
		LeftLeg = leg({ raise = 30, spread = 4, twist = -10 }),
		RightLeg = leg({ raise = -52, spread = 6, twist = -25 }),
	})
	c:key(6, chamber, "sineInOut")
	c:key(9, merge(chamber, { Torso = { twist = -38, lean = 30, pos = { up = -0.95 } } }), "snap")
	local contact = merge(G, {
		Torso = { twist = 40, lean = -8, pos = { up = -0.05, forward = 0.45 } },
		Head = { nod = -6, turn = -14 },
		RightArm = { raise = 142, swing = 12, pos = { forward = 0.55, up = 0.35 } },
		LeftArm = { raise = 145, swing = 55, pos = { forward = 0.05 } },
		LeftLeg = leg({ raise = 18, spread = 6 }),
		RightLeg = leg({ raise = -24, spread = 8, twist = 28, pos = { forward = -0.2 } }),
	})
	c:key(13, contact, { settle = 0.12 })
	c:key(21, merge(contact, { Torso = { twist = 43, lean = -10, pos = { up = 0 } }, RightArm = { raise = 146, pos = { up = 0.42 } } }), { recover = 0.12 })
	c:key(38, G)
	c:marker(13, "Hit")
	c:marker(27, "Cancel")
	c:lead("Torso", 1)
	c:lead("LeftArm", -1)
	c:lead("Head", -2)
	c.meta = {
		limb = "RightArm",
		direction = V(0, 1, -0.3).Unit,
		strike = { 9, 13 },
		hit = 13,
		active = { 13, 15 },
		cancel = 27,
		hitstop = 0.12,
		damage = 1.8,
		finisher = true,
	}
	return c
end

-- Push kick with the rear leg: chamber high, then the leg is thrown out of the hip (0.6 stud) at
-- the target while the torso leans back for balance and the arms counter.
function CombatMoves.Kick()
	local c = clip("Kick")
	c:key(0, G, "sineInOut")
	c:key(6, merge(G, {
		Torso = { twist = -12, lean = -6, pos = { up = -0.25 } },
		RightLeg = { raise = 70, spread = 4, ground = false, pos = { up = 0.3 } },
		LeftArm = { raise = 145, swing = 30 },
	}), "snap")
	local contact = merge(G, {
		Torso = { twist = 6, lean = -22, pos = { up = -0.15, forward = 0.25 } },
		Head = { nod = 14, turn = 4 },
		RightLeg = { raise = 100, spread = 2, twist = 6, ground = false, pos = { forward = 0.6, up = 0.1 } },
		LeftArm = { raise = -30, spread = 22, pos = { forward = -0.2 } },
		RightArm = { raise = 150, swing = 55 },
		LeftLeg = leg({ raise = 4, spread = 6, twist = -10 }),
	})
	c:key(12, contact, { settle = 0.1 })
	c:key(20, merge(contact, { Torso = { lean = -24 }, RightLeg = { raise = 102 } }), "quadInOut")
	c:key(28, merge(G, { RightLeg = { raise = 45, spread = 6, ground = false, pos = { up = 0.25 } }, Torso = { lean = 4, twist = -16, pos = { up = -0.3 } } }), { recover = 0.08 })
	c:key(34, merge(G, { RightLeg = leg({ raise = -10, spread = 6, twist = -20 }), Torso = { lean = 4, twist = -20, pos = { up = -0.2 } } }), "sineInOut")
	c:key(40, G)
	c:marker(12, "Hit")
	c:marker(30, "Cancel")
	c:lead("Torso", 1)
	c:lead("LeftArm", -2)
	c:lead("Head", -2)
	c.meta = {
		limb = "RightLeg",
		direction = V(0, 0.15, -1).Unit,
		strike = { 6, 12 },
		hit = 12,
		active = { 12, 15 },
		cancel = 30,
		hitstop = 0.1,
		damage = 1.6,
		hop = true,
	}
	return c
end

-- Dashes. The body sells the burst: a short crouch, a hard lean into the travel, the arms
-- flung BACK out of the guard (no hands up: a dash is not a block), the head dragging behind, then
-- a brake. The travel itself is physics (R6Combat), starting on the "Go" marker.
local function dashStart(c, crouch)
	c:key(0, G, "quadIn")
	-- the guard already breaks on the crouch: hands drop toward the swing
	c:key(3, merge(G, merge({
		Torso = { lean = 16, twist = -16, pos = { up = -0.6 } },
		LeftArm = { raise = 70, swing = 15, pos = { forward = 0.05 } },
		RightArm = { raise = 80, swing = 30, pos = { forward = 0 } },
	}, crouch or {})), "snap")
end

local function dashMeta(c, travel, cancel)
	c:marker(6, "Go")
	c:marker(cancel, "Cancel")
	c.meta = { dash = travel, go = 6, strike = { 3, 10 }, cancel = cancel, hop = true }
	return c
end

function CombatMoves.DashForward()
	local c = clip("DashForward")
	dashStart(c)
	local launch = {
		Torso = { lean = 45, twist = -6, pos = { up = -0.7, forward = 0.6 } },
		Head = { nod = -28 },
		-- both arms thrown back behind the body and slid back out of the shoulders
		RightArm = { raise = -60, spread = 18, pos = { forward = -0.5, up = 0.05 } },
		LeftArm = { raise = -52, spread = 20, pos = { forward = -0.45, up = 0.05 } },
		LeftLeg = leg({ raise = 40, spread = 4 }),
		RightLeg = leg({ raise = -50, spread = 6, pos = { forward = -0.3 } }),
	}
	c:key(6, launch, "sineInOut")
	c:key(14, merge(launch, { Torso = { lean = 40, twist = -8, pos = { up = -0.62, forward = 0.5 } }, LeftLeg = { raise = 32 }, RightArm = { raise = -66 }, LeftArm = { raise = -58 } }), { recover = 0.12 })
	c:key(26, G)
	c:lead("Torso", 1)
	c:lead("RightArm", -2)
	c:lead("LeftArm", -2)
	c:lead("Head", -1)
	return dashMeta(c, { direction = V(0, 0, -1), distance = 16, time = 0.22 }, 20)
end

-- Back dash: a push off, the slide back, then the brake drops into a low kneel, the lead hand
-- reaching down to the ground and the rear arm flung back, one leg forward and one stretched behind
-- like a knee on the floor. The depth is the size of the movement system's long landing (body down 1.15 stud,
-- legs riding 1.0-1.5 into the torso).
function CombatMoves.DashBack()
	local c = clip("DashBack")
	dashStart(c, { Torso = { lean = 10 } })
	local launch = {
		Torso = { lean = 14, twist = -18, pos = { up = -0.55, forward = 0.1 } },
		Head = { nod = 8 },
		-- the arms trail the travel: they fly forward as the body shoots back
		LeftArm = { raise = 55, spread = 15, pos = { forward = 0.3 } },
		RightArm = { raise = 45, spread = 20, pos = { forward = 0.25 } },
		LeftLeg = leg({ raise = 26, spread = 8 }),
		RightLeg = leg({ raise = -30, spread = 10 }),
	}
	c:key(6, launch, "sineInOut")
	local kneel = {
		Torso = { lean = 30, twist = -15, pos = { up = -1.15, forward = 0.1 } },
		Head = { nod = -10, turn = 10 },
		LeftArm = { raise = 18, spread = 18, swing = 8, pos = { forward = 0.15, up = -0.55 } }, -- hand to the ground
		RightArm = { raise = -55, spread = 25, pos = { forward = -0.4, up = -0.1 } }, -- flung back
		LeftLeg = leg({ raise = 50, spread = 6, twist = -10 }),
		RightLeg = leg({ raise = -62, spread = 8, twist = -20 }), -- stretched behind, knee at the floor
	}
	c:key(16, kneel, { settle = 0.1 })
	c:key(26, merge(kneel, { Torso = { lean = 32, pos = { up = -1.18 } }, LeftArm = { raise = 15 } }), { recover = 0.12 })
	c:key(40, G)
	c:lead("Torso", 1)
	c:lead("RightArm", -2)
	c:lead("LeftArm", -2)
	c:lead("Head", -1)
	return dashMeta(c, { direction = V(0, 0, 1), distance = 12, time = 0.2 }, 32)
end

-- Side dashes: the body tilts into the travel, the arms swing back and away from it (the trailing
-- arm flung out for balance), the lead leg reaches.
local function sideDash(name, side)
	local c = clip(name)
	dashStart(c)
	local lead = side > 0 and "RightLeg" or "LeftLeg"
	local trail = side > 0 and "LeftLeg" or "RightLeg"
	local leadArm = side > 0 and "RightArm" or "LeftArm"
	local trailArm = side > 0 and "LeftArm" or "RightArm"
	local launch = {
		Torso = { tilt = 22 * side, lean = 16, twist = -16, pos = { up = -0.6, right = 0.35 * side } },
		Head = { tilt = -14 * side, nod = -6 },
		[leadArm] = { raise = -40, spread = 12, pos = { forward = -0.35 } },
		[trailArm] = { raise = -30, spread = 50, pos = { forward = -0.25, right = -0.3 * side } },
		[lead] = leg({ spread = 36, raise = 6 }),
		[trail] = leg({ spread = -6, raise = -6 }),
	}
	c:key(6, launch, "sineInOut")
	c:key(10, merge(launch, { [leadArm] = { raise = -48 }, [trailArm] = { raise = -36, spread = 56 } }), "sineInOut")
	c:key(14, merge(launch, { Torso = { tilt = 18 * side, lean = 13, twist = -16, pos = { up = -0.55, right = 0.3 * side } } }), { recover = 0.12 })
	c:key(26, G)
	c:lead("Torso", 1)
	c:lead(leadArm, -2)
	c:lead(trailArm, -2)
	c:lead("Head", -1)
	return dashMeta(c, { direction = V(side, 0, 0), distance = 13, time = 0.2 }, 20)
end

function CombatMoves.DashLeft()
	return sideDash("DashLeft", -1)
end

function CombatMoves.DashRight()
	return sideDash("DashRight", 1)
end

-- Block: a held, breathing pose (loops), forearms stacked in front of the face, shoulders hunched
-- forward out of their sockets.
function CombatMoves.Block()
	local c = clip("Block", { loop = true, priority = "Action2" })
	local hold = merge(G, {
		Torso = { twist = -10, lean = 16, pos = { up = -0.45 } },
		Head = { nod = -6, turn = 6 }, -- eyes over the forearms, not buried behind them
		LeftArm = { raise = 160, swing = 70, pos = { forward = 0.35, up = 0.1 } },
		RightArm = { raise = 165, swing = 75, pos = { forward = 0.3, up = 0.15 } },
		-- the house lowers the body on one leg: the front leg takes the depth, the back leg
		-- stretches behind at acos(1 - drop/2) and stays long
		LeftLeg = leg({ raise = 16, spread = 4, twist = -10 }),
		RightLeg = leg({ raise = -40, spread = 6, twist = -15 }),
	})
	c:key(0, hold, "sineInOut")
	c:key(30, merge(hold, { Torso = { lean = 17.5, pos = { up = -0.5 } } }), "sineInOut")
	c:key(60, hold)
	c.meta = { blocking = true }
	return c
end

-- Reactions start already displaced: frame 0 is the struck pose, no wind-up (the hit sells itself).
function CombatMoves.HitLight()
	local c = clip("HitLight", { priority = "Action3" })
	local struck = merge(G, {
		Torso = { twist = -10, lean = -14, pos = { up = -0.35, forward = -0.35 } },
		Head = { nod = -26, turn = 12 },
		LeftArm = { raise = 40, spread = 26, pos = { forward = -0.25 } },
		RightArm = { raise = 30, spread = 32, pos = { forward = -0.25 } },
	})
	c:key(0, struck, "quadOut")
	c:key(4, merge(struck, { Torso = { twist = -8, lean = -18, pos = { forward = -0.42 } }, Head = { nod = -32 } }), "sineInOut")
	c:key(9, merge(struck, { Torso = { twist = -12, lean = -10, pos = { forward = -0.3 } }, Head = { nod = -14, turn = 8 } }), { recover = 0.1 })
	c:key(24, G)
	c:marker(14, "Cancel")
	c:lead("Head", 1)
	c.meta = { reaction = true, cancel = 14, stun = 0.3 }
	return c
end

function CombatMoves.HitHeavy()
	local c = clip("HitHeavy", { priority = "Action3" })
	local struck = merge(G, {
		Torso = { twist = 12, lean = -30, pos = { up = -0.5, forward = -0.8 } },
		Head = { nod = -36, turn = -12 },
		LeftArm = { raise = 75, spread = 45, pos = { forward = -0.4, up = 0.2 } },
		RightArm = { raise = 60, spread = 50, pos = { forward = -0.4, up = 0.2 } },
		LeftLeg = leg({ raise = 36, spread = 8 }),
	})
	c:key(0, struck, "quadOut")
	c:key(6, merge(struck, { Torso = { twist = 14, lean = -34, pos = { up = -0.55, forward = -0.9 } }, Head = { nod = -40 } }), "quadInOut")
	-- stumble: catch the weight by pitching forward past guard, then settle
	c:key(16, merge(G, {
		Torso = { twist = -12, lean = 26, pos = { up = -0.65, forward = 0.15 } },
		Head = { nod = 20 },
		-- the weight caught on the front leg, the back leg stretched long behind (the house's crouch)
		LeftLeg = { raise = 18 },
		RightLeg = { raise = -48 },
	}), { recover = 0.12 })
	c:key(40, G)
	c:marker(28, "Cancel")
	c:lead("Head", 2)
	c:lead("LeftArm", -2)
	c:lead("RightArm", -3)
	c.meta = { reaction = true, cancel = 28, stun = 0.55 }
	return c
end

-- Fighting stance idle: a moving hold, never a dead stop. The body breathes down and up 0.05 stud and
-- the hands drift in and out of the shoulders, the way the movement system's idle keeps its arms 0.15 stud loose.
function CombatMoves.Stance()
	local c = clip("Stance", { loop = true, priority = "Idle" })
	c:key(0, G, "sineInOut")
	c:key(36, merge(G, {
		Torso = { lean = 11.5, pos = { up = -0.4 } },
		LeftArm = { raise = 134, pos = { forward = 0.27 } },
		RightArm = { raise = 146, pos = { forward = 0.2 } },
		Head = { nod = -3.5 },
	}), "sineInOut")
	c:key(72, G)
	c:lead("Head", -4)
	c:lead("LeftArm", -2)
	c:lead("RightArm", -3)
	c.meta = {}
	return c
end

CombatMoves.LIST = {
	"Stance",
	"Jab",
	"Cross",
	"Hook",
	"Uppercut",
	"Kick",
	"DashForward",
	"DashBack",
	"DashLeft",
	"DashRight",
	"Block",
	"HitLight",
	"HitHeavy",
}

-- The M1 string: fast first hit, heavier later ones, the finisher heaviest.
CombatMoves.COMBO = { "Jab", "Cross", "Hook", "Uppercut" }

function CombatMoves.build(bakeOpts)
	local out = {}
	for _, name in CombatMoves.LIST do
		local c = CombatMoves[name]()
		out[name] = { clip = c, baked = c:bake(bakeOpts), meta = c.meta }
	end
	return out
end

return CombatMoves
