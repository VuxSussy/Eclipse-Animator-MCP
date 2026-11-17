# Authoring example


```lua
local R6Clip = require(path.R6Clip)
local Moves = require(path.CombatMoves)
local G, leg, merge = Moves.Guard, Moves.leg, R6Clip.merge

-- lead jab: hanging chamber -> 3-frame release -> body and shoulder thrown in -> hold -> snap home
local c = R6Clip.new("Jab")
c:key(0, G, "snap")                                      -- the press reads on the first frame
local chamber = merge(G, {
	Torso = { twist = -12, lean = 4, pos = { up = -0.5, forward = -0.25 } },
	LeftArm = { raise = 120, swing = 40, pos = { forward = -0.15 } },   -- fist drawn back in
})
c:key(4, chamber, "sineInOut")
c:key(7, merge(chamber, { Torso = { twist = -9, pos = { forward = -0.3 } } }), "snap") -- keeps loading
local contact = merge(G, {
	Torso = { twist = -50, lean = 22, pos = { up = -0.42, forward = 0.55 } },  -- turned in, lunging
	Head = { turn = 26 },                                                      -- eyes stay on target
	LeftArm = { raise = 134, swing = -32, pos = { forward = 0.75 } },         -- shoulder thrown out
	RightArm = { raise = 158, swing = 70, pos = { forward = 0.1 } },          -- rear hand to the chin
	LeftLeg = leg({ raise = 24, spread = 4 }),                                 -- front foot steps
	RightLeg = leg({ raise = -28, spread = 6, pos = { forward = -0.25 } }),   -- rear leg pushes
})
c:key(10, contact, { settle = 0.12 })
c:key(18, merge(contact, { LeftArm = { pos = { forward = 0.82 } } }), "snap")  -- held, creeping
c:key(24, merge(G, { Torso = { twist = -30, lean = 12 } }), { settle = 0.1 })
c:key(30, G)
c:marker(10, "Hit"); c:marker(18, "Cancel")
c:lead("Torso", 1); c:lead("Head", -2)
c.meta = { limb = "LeftArm", strike = { 7, 10 }, hit = 10, hitstop = 0.075 }

local baked = c:bake()
print(R6Clip.audit(baked, c.meta).notes)                -- fix until empty
local ks = R6Clip.toKeyframeSequence(baked)             -- AnimSaves-ready
```

**Weapons.** A sword in a Tool's default grip (RightGrip) is a fixed extension of the arm: its
blade stands out of the fist along the arm's front, so the arm's `raise` sets where the blade
points (raise 0 forward, 90 straight up, 165 back over the head). Give the clip `meta.tip =
Vector3.new(0, -1, -blade)` (Right Arm space) and the audit's contact/sweep checks measure the
blade tip; `lune run study ... --tip="Right Arm:0,-1,-4"` measures references the same way. A
long lever turns small arm motions into big tip speeds: accelerate into contact (`quadIn` out of
the hang), do not `snap` out of it. Worked example and numbers: `references/combat.md` §9.

Part entries: named angles (Torso `lean/twist/tilt`, Head `nod/turn/tilt`, limbs
`raise/spread/swing/twist`, degrees, parent space), `pos = { forward, up, right }` studs (the torso
against the root; any other part slid out of its socket), and for legs `space = "root"` (hang from
a pelvis taking `hips` = 0.35 of the torso's turn) and `ground = true` (slide to the floor every
frame). `transform = CFrame` takes a raw pose. Details and numbers: `posing.md`.

