# A simple R6 combat animation system

## Contents
1. Anatomy of an attack
2. The starter moves
3. The M1 string: buffer, cancels, reset
4. Dashes
5. Hit-stop and reactions
6. Effects and camera pairing
7. Wiring it up (client and server)
8. Adding a move

## 1. Anatomy of an attack

From Sakurai and the GDC talks, via the team's motion bible:

| Part | What it does | On R6 |
|---|---|---|
| Idle (guard) | the origin of every pose; a moving pose, never a dead stop | `CombatMoves.Guard` + the `Stance` loop |
| Wind-up (chamber) | tells the player the input was taken, gives the hit its weight | load **opposite** the strike: torso twist away, arm cocked, weight back |
| Hit (contact) | the pose at the active start; hit-stop freezes it, so it is what the eye keeps | the extreme on the active frame, on the target line |
| Follow-through | most of the move and most of what players see | hold 4–6 frames, then recover into guard with a small settle |

Torso direction for an orthodox stance (left foot and left hand lead):
- **Jab and lead hook** turn the shoulders **clockwise**: twist goes more negative.
- **Cross, rear uppercut and rear kick** turn them **counter-clockwise**: twist goes toward
  positive.

Getting this backwards makes a hook that never crosses the centre line. The audit's `arc` check
catches that.

## 2. The starter moves

`CombatMoves.build()` gives `name → { clip, baked, meta }`. All 13 pass the audit.

| Move | Frames | Hit | Cancel | Hit-stop | Damage | Notes |
|---|---|---|---|---|---|---|
| Stance | 72, loop | — | — | — | — | breathing guard; hands drift 0.07 stud in and out of the shoulders |
| Jab | 30 | 10 | 18 | 75 ms | 1.0 | hanging chamber, 3-frame release, torso −50°, 0.55 lunge, shoulder out 0.75-0.82, fist 3.3 studs out, rear hand snaps to the chin |
| Cross | 32 | 11 | 20 | 80 ms | 1.2 | hips through to +60°, rear foot pushes, shoulder out 0.85-0.9, fist 3.2 studs out |
| Hook | 32 | 12 | 21 | 85 ms | 1.3 | arc at head height (spread 100, swing 52 → 72), crosses the centre line at the hit, shoulder pushed 0.55 |
| Uppercut | 38 | 13 | 27 | 120 ms | 1.8 | sinks a full stud (legs ride 0.9 into the torso), drives up, shoulder thrown 0.65 up and forward; the finisher |
| Kick | 40 | 12 | 30 | 100 ms | 1.6 | rear push kick thrown 0.6 out of the hip, leans back, steps down grounded |
| DashForward | 26 | Go f6 | 20 | — | — | crouch, lean 45°, both arms flung back behind the body and slid 0.45-0.5 back, back leg long |
| DashBack | 40 | Go f6 | 32 | — | — | push off, arms trail forward, then brake into a low kneel (body down 1.15, front leg forward, rear leg stretched behind like a knee on the floor, lead hand to the ground, rear arm flung back), rise at f40 |
| DashLeft / DashRight | 26 | Go f6 | 20 | — | — | tilt 22° into the side, the lead leg spreads, both arms swing back, the trailing arm flung out for balance; no guard |
| Block | 60, loop | — | — | — | — | forearms stacked in front of the face, shoulders hunched 0.3 forward, breathing |
| HitLight | 24 | — | 14 | — | — | starts displaced: head snapped back 26°, torso −14°, arms knocked back 0.25 |
| HitHeavy | 40 | — | 28 | — | — | thrown back 30°, then a stumble forward past guard and a settle |

Every pose is keyed angles plus slides; legs hang from the pelvis (`space = "root"`) and stay
grounded. The numbers come from the R6 references in `reference-first.md` (section 6).

Meta fields:
- `limb`: the striking part
- `hit`, `active = { from, to }`, `strike = { chamber, contact }` (the audit window), `cancel`
- `hitstop` (seconds), `damage`
- `dash = { direction, distance, time }`, `go` (the burst frame)
- `arc` (a sweeping strike), `direction` (the strike direction, for the audit)
- `hop`, `airborne`, `reaction`, `blocking`, `finisher`
- audit knobs: `minReach` (2.4), `minTwist` (25), `noCommit`, `legGap` (0.75), `legsMayCross`

## 3. The M1 string: buffer, cancels, reset

`R6Combat.DEFAULTS.combo = { "Jab", "Cross", "Hook", "Uppercut" }`:
- **Fast first, heavier later, finisher heaviest.** Hit-stop and damage rise through the string.
- **Cancel.** The next hit may start at the clip's `Cancel` marker (12–24 frames), not at its end.
  That is the hand-over. The recovery before it already leans toward the next wind-up.
- **Buffer.** A press during the recovery is kept for 0.25 s and fires the moment the cancel
  window opens, so mashing feels responsive and never eats inputs.
- **Reset.** If 0.9 s pass since the last hit, the string starts over at the Jab.
- **Crossfades.** The first hit fades in over 0.04 s, later hits over 0.1 s (DevForum: 0.1–0.15 s
  between combo hits), reactions over 0, and the way out over 0.15 s.
- **Spacing.** Hits about 0.33–0.45 s apart read clearly; at 0.35 s and below, clips start to
  smear into each other (DevForum). A YouTube combat system spaces its M1s about 0.63 s apart.
- **Random variants.** A combo slot can list several clips (`combo = { { "Jab", "JabHigh" },
  "Cross", ... }`). R6Combat picks one at random and never the same one twice in a row, so a
  string never looks pasted ("random M1 combos").
- **Wind-up highlight.** `R6Combat` flashes a `Highlight` on the attacker over `meta.windup`
  (frames), then fades it over 0.12 s. It is a telegraph the defender can read (a YouTube combat
  system). Turn it off with `config = { windup = false }`.
- **Ideas from the same system, to build on the server:**
  - a *bodyshot* that lands only while the target blocks
  - a *block break*
  - a short *knockout* state

## 4. Dashes

The clip sells the burst (crouch → hard lean → arms flung back → brake and settle). The user's
rules: arms swing back during a dash, side dashes never hold a block guard, and the back dash ends
in a grounded kneel (one leg forward, one behind, hands to the ground and back). The kneel's depth
comes from the movement system's long landing (body down 1.18, legs riding 1.05-1.58 into the torso). Physics carries the
body:
- **A `LinearVelocity`** in Plane mode on the root attachment (X/Z only, so gravity still acts),
  created once per character.
- **Profile.** `v(t) = v0 · (1 − t/T)²`, fast out and braking to zero. It covers `v0·T/3`, so
  `v0 = 3·D/T`. The forward dash covers 16 studs in 0.22 s (v0 ≈ 218 studs/s at the start), the
  back dash 12 studs in 0.2 s, the sides 13 studs in 0.2 s.
- **Starts on the clip's `Go` marker** (frame 6, after the crouch), with a timer as a safety net.
- **Direction.** `dash("Forward"|"Back"|"Left"|"Right")` is relative to the root.
  `dash(worldVector)` picks the clip from the local direction (for camera-relative input).
- **Cooldown** 0.55 s. Dashing during a recovery is buffered like attacks.
- **Juice.** An FOV kick on dash (movement system: FOV per state, eased over 0.35–0.5 s), dust at the start,
  an optional afterimage that must never read as an extra enemy.

## 5. Hit-stop and reactions

- **At the `Hit` marker,** the attacker's track goes `AdjustSpeed(0)` for `meta.hitstop`, then
  back to 1. R6Clip always puts a keyframe exactly on a marker, which is what makes a 0-speed
  freeze hold cleanly (DevForum's fix for unreliable freezes).
- **Draw on the client only.** Never stall the server.
- **The victim** plays `react(heavy)` when the server reports the hit. Reactions start displaced
  (frame 0 is the struck pose), cut in with no fade, and run at Action3 priority so they override
  attacks.
- **Victim shake** during the freeze is larger than the attacker's (motion bible), sideways on the
  ground. Shake the drawn body or the camera, never the hitbox.
- **Heavy hits** can push the victim with a short `LinearVelocity` like a dash. The attacker's
  follow-through lurch is already in the clip (the held contact creeps forward).

## 6. Effects and camera pairing

From the two reference videos and the motion bible:
- **Contact flash.** One frame of impact star or flash exactly at the Hit marker, with radial speed
  lines (Nullscript). A blank or flash frame before a cut-in (Hovark).
- **Trails.** White arcs on swings (Trail or Beam on the striking limb), only during the strike and
  hold, never during the wind-up.
- **Smears.** Only on the fastest strike frames. Hovark's TikTok shows 2D swirl or wind lines held
  about 0.25 s around a landed aerial kick.
- **Camera.**
  - Shake scaled by damage, not on every jab.
  - On a big clash, cut to a close-up and hold about 0.5 s (Nullscript).
  - Dutch angles on aerials (Hovark).
  - An FOV kick on dash.
- **Sound.** On the Hit marker with varied pitch (DevForum). A heavier body sound on finishers.

## 7. Wiring it up (client and server)

Client (a LocalScript in StarterCharacterScripts; modules in `ReplicatedStorage.R6Animation`):

```lua
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local lib = RS:WaitForChild("R6Animation")
local R6Combat = require(lib.R6Combat)
local CombatMoves = require(lib.CombatMoves)
local remote = RS:WaitForChild("CombatHit") -- RemoteEvent

local character = script.Parent
local ids = require(lib.AnimationIds)        -- your published ids: { Jab = "rbxassetid://...", ... }
local combat = R6Combat.new(character, {
	animations = ids,
	moves = R6Combat.movesFrom(CombatMoves),
	onHit = function(name)
		remote:FireServer(name)              -- the server decides; the client only asks
	end,
})

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		combat:attack()
	elseif input.KeyCode == Enum.KeyCode.Q then
		local move = character.Humanoid.MoveDirection
		combat:dash(move.Magnitude > 0.1 and move or "Forward")
	elseif input.KeyCode == Enum.KeyCode.F then
		combat:block(true)
	end
end)
UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F then combat:block(false) end
end)
```

For a project that uses the Input Action System, bind the same calls there instead (see the
`rbx-input-action-system` skill).

Server (a Script): trust nothing from the client but the request.

```lua
local R6Combat = require(game.ReplicatedStorage.R6Animation.R6Combat)
local last = {}
local MOVES = { Jab = { damage = 8, gap = 0.2 }, Cross = { damage = 10, gap = 0.25 }, Hook = { damage = 11, gap = 0.28 }, Uppercut = { damage = 15, gap = 0.35 }, Kick = { damage = 13, gap = 0.4 } }
game.ReplicatedStorage.CombatHit.OnServerEvent:Connect(function(player, name)
	local move, char = MOVES[name], player.Character
	if not move or not char then return end
	local now = os.clock()
	if last[player] and now - last[player] < move.gap then return end   -- rate limit by the move's own timing
	last[player] = now
	for _, humanoid in R6Combat.query(char, 4.5) do                    -- the box in front of the root
		humanoid:TakeDamage(move.damage)
		-- tell the victim's client to play the reaction (another RemoteEvent), heavy for finishers
	end
end)
```

If the experience runs **server authority**, the attack is a server action instead, with the
client predicting the animation. Follow the project's own rules (for se370: Server Authority docs
and the team's `AGENTS.md`). The animation layer stays the same.

## 8. Adding a move

1. Find the move made for R6 and measure it (`reference-first.md`); write the brief from those
   numbers. Fall back to the house grammar only when no R6 version exists. In the motion bible,
   fists are "Brawler": snappy, punchy, overshoot, settle, whippy.
2. Copy the closest kit move and change the poses, not the structure: guard, chamber, contact,
   hold, recovery, with the same eases. Commit the body (torso twist and lunge), slide the striking
   limb inside its budget, legs with `CombatMoves.leg{...}`.
3. Set `meta.limb`, `strike`, `hit`, `cancel`, `hitstop`, and `arc` for sweeping strikes.
4. `lune run build <outDir>`. The audit must be clean. Run `lune run study` on your clip next to
   the reference. Look at it in the preview from the side and from the front at 0.25×, and in
   Studio at the Hit frame.
5. Add it to `CombatMoves.LIST` (and to the combo, if it belongs to the string). Publish it, and
   map its id in `animations`.

## 9. Weapons: a sword slash, worked through

The skill's first test (2026-10-28) was a right-handed sword slash, made by following this skill
step by step (it lives outside the skill, in the project's `sword/` folder).

1. **References.** Creator Store queries containing "sword" or "katana" returned nothing; "R6
   slash animation" found packs. The katana pack (122453404864942) would not load ("not
   authorized"); "Slash Animations Testing for Soldier R6" (127875309409617) did. The weapon
   "Swing" clips of 80460719695191 turn their sword with a Handle Motor6D, so only their timing
   counts (hit at 43-50%, 9-10 frame releases).
2. **Measured with the blade** (`--tip="Right Arm:0,-1,-4"`): 0.667 s, chamber f10, the blade
   crosses the centre line in front at f18, fastest 192 studs/s at f15, torso turned 43 degrees and
   leaning 25 at contact, blade tip 4.9 studs out.
3. **The slash** (diagonal, upper right to lower left), 42 frames with leads:

| Key | Frame | Pose |
|---|---|---|
| guard | 0 (`snap`) | blade forward and up from the hip (raise 35, swing 20) |
| wind-up | 9, hang to 11 (`quadIn` out) | body turned -40 and back, sword cocked behind the head (raise 165, spread 35), off hand out at the target |
| over the top | 14 (`linear`) | blade straight up in front of the right shoulder (raise 100) |
| contact | 17 (`sineInOut`), Hit | torso +35, lean 24, lunge 0.4; arm raise 55, swing -25, shoulder slid 0.6 forward; blade crosses the centre line at chest height, 5.5-5.7 studs out; off hand yanked to the hip |
| follow-through | 22 (`settle`), held to 29 | torso +55, blade low to the left by the floor |
| guard | 42 (`recover`) | |

4. **Result.** Audit clean; study: blade crosses at f17 (40%), fastest 244 studs/s at f14 (3
   frames before contact, like the reference), torso 35 at contact. In a playtest the Hit marker
   found the blade tip 5.7 studs out at the centre line with the torso at 41 degrees; hit-stop held.
5. **What the first draft got wrong:** `snap` out of the hang put the blade's peak (309 studs/s)
   right after the wind-up; the contact key had already swept past the centre (tip x -3.8). Probe
   the blade tip of each key before baking (fist + 4 studs along the arm's front).

For an overhead weapon, see [pack-tools.md](pack-tools.md) for `meta.contactHeight`: an upright blade above the target is not yet a chest-height impact. Keep default behavior when no target band is declared.
### Swinging, not punching (the showcase katana combo, 2026-10-29)

The first katana combo copied the punch grammar: the arm pushed out along a line to contact and
pulled back. The user's note: a weapon swing needs width, the arm out at full stretch, and a cut
from above has to lift the sword all the way over the head before chopping down. The rebuilt cuts:

| Cut | Wind-up (meta.strike[1]) | The arc | Follow-through | Travelled arc, arm out |
|---|---|---|---|---|
| Katana1 diagonal | sword behind the right shoulder (raise 182-186, spread 42-44, body turned -55, arched) | out wide right and high (raise 138, spread 62, shoulder slid 0.6 right), round to the front (raise 92, spread 50) | down across the body to behind the left hip (raise -12, swing 78) | 336 degrees, 0.67 |
| Katana2 backhand | wrapped round behind the left shoulder (swing 110-116, body turned +62) | flat across the front at chest height, arm slid 0.85 forward | flung out straight to the right (spread 88-94, blade pointing behind) | 269, 0.80 |
| Katana3 rising | low behind the left hip (raise -30, body dropped 0.66) | up through the front (raise 18 → 58 → 108, spread to 34) | over the right shoulder (raise 176-182) | 289, 0.78 |
| Katana4 overhead | both hands, sword over the head with the blade hanging behind (raise 150-154, back arched -16): tip 1.5+ above the head | straight down the centre line | on through to the floor (raise -8), held | 200, 0.70 |

Keys sit every 2 frames along the arc (otherwise the tip cuts the chord between two keys) and the
cut leaves the hang with `heavyIn`. The audit's `swing` check (travelled arc, average arm slide,
overhead wind-up) fails the old punch-shaped versions.
