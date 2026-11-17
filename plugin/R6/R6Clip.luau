-- R6Clip: build R6 animations from key poses, in code, with weight.
--
--   local clip = R6Clip.new("Jab")
--   clip:key(0,  Guard, "snap")                          -- ease shapes the segment LEAVING the key
--   clip:key(8,  { Torso = { twist = -55, lean = 24, pos = { forward = 0.5, up = -0.35 } },
--                  LeftArm = { raise = 92, swing = 22, pos = { forward = 0.7 } } }, { settle = 0.12 })
--   clip:marker(8, "Hit")
--   clip:lead("Torso", 1)                                -- torso moves 1 frame before the rest (overlap)
--   local baked = clip:bake()                            -- 60 fps, every frame
--   print(R6Clip.audit(baked).notes)                     -- fix until empty
--   local ks = R6Clip.toKeyframeSequence(baked)          -- AnimSaves-ready KeyframeSequence
--   local json = R6Clip.toEclipse(baked)                 -- for the Eclipse Animator MCP save_animation tool
--
-- What you key is what plays. There is no IK and no solver: no aim targets, no planted-leg fitting,
-- no head counter. Each part entry is
--   named angles (R6Rig.rotation, degrees): Torso lean/twist/tilt, Head nod/turn/tilt,
--                limbs raise/spread/swing/twist
--   pos = { forward, up, right }  studs. On the torso: the body against the root (drop, lunge). On
--                a limb or the head: the part slides out of its socket. This is how R6 gets reach and
--                force: the movement system's run throws the arms 0.7 stud along their swing, battlegrounds punches
--                push the striking shoulder 0.5-1.4 stud at the target, legs ride up 0.5-1.5 stud
--                into the torso when the body sinks (R6 has no knees). Budgets: R6Rig.GAP.
--   space = "root"  (legs) hang the leg from a pelvis that takes only `hips` (default 0.35) of the
--                torso's turn and lean, and slide the hip socket to that pelvis: the chest can twist
--                60 degrees without swinging the feet around or crossing the legs. Once per key.
--   ground = true  (legs) every frame, slide the leg straight up or down (root space) until its
--                sole is on the floor: the telescoping-leg trick. Translation only, the leg's angle
--                is yours. Between a grounded key and a free one it fades in or out.
--   transform = CFrame  a raw joint Transform (pasted from another tool or a measured clip)
--   ease       overrides the key's ease for this part
-- Eases shape the segment LEAVING a key. "auto" (or opts.curve = "auto", which turns every
-- sineInOut / linear / quadInOut / cubicInOut / recover / unset segment into one) runs the values on a
-- curve THROUGH the keys: monotone cubic tangents (PCHIP), flat at a real extreme (a contact, a
-- turnaround), never overshooting a key. Strike eases (snap, settle, quadIn, heavyIn...) stay.
-- opts.tension (0..1, default R6Clip.tension or 0) is how much the body slows at every key on
-- that curve: 0 glides through (smooth, fast-looking), 0.5 surges between keys and settles into
-- each pose, 1 stops at every key. Uneven speed is what reads as weight; 0 reads as floaty.
-- opts.weight ("light" | "medium" | "heavy" | { load, strike, hold, recover, move }; default
-- R6Clip.weight) is timing contrast, applied once at bake: the wind-up (keys before meta.strike),
-- the hold (meta.hit to meta.cancel) and the recovery (after meta.cancel) are stretched by their
-- factor while the strike itself stays as fast as keyed. A one-shot without meta.strike stretches
-- by `move`. Left alone: loops (a walk has to match its ground speed), clips airborne throughout
-- (a jump) and landings (meta.impact) unless their own opts.weight asks: those are timed by the
-- fall, not by the animator. Markers and the meta
-- frames (hit, cancel, go, strike, active, windup, airborne, wings) move with the keys.
-- Parts missing from a key are not keyed there: they move between the keys that name them.

local R6Rig = require(script.Parent.R6Rig)
local Ease = require(script.Parent.Ease)
local Sequence = require(script.Parent.Sequence)

local R6Clip = {}
R6Clip.__index = R6Clip
-- defaults for opts.curve, opts.tension and opts.weight: set them before building to apply to
-- every clip built afterwards (a whole moveset)
R6Clip.curve = nil
R6Clip.tension = nil
R6Clip.weight = nil

-- Timing contrast: how much each phase of a one-shot is stretched (strike = the meta.strike
-- window, which stays fast; hold = from the hit to the cancel; move = a clip without a strike).
-- Measured against the kit's own timing: its wind-ups (4-9 f) and recoveries (12-20 f) read
-- rushed next to the house movement system's 0.5-0.9 s actions.
R6Clip.WEIGHTS = {
	light = { load = 1.15, strike = 1, hold = 1.1, recover = 1.2, move = 1.1 },
	medium = { load = 1.3, strike = 1, hold = 1, recover = 1.55, move = 1.3 },
	heavy = { load = 1.7, strike = 1.15, hold = 1.2, recover = 1.9, move = 1.55 },
}

local ALIAS = {
	RightArm = "Right Arm",
	LeftArm = "Left Arm",
	RightLeg = "Right Leg",
	LeftLeg = "Left Leg",
}

local function partName(name)
	local part = ALIAS[name] or name
	if not R6Rig.JOINTS[part] then
		error("Not an R6 part: " .. tostring(name), 3)
	end
	return part
end

local function checkEntry(part, entry)
	if entry.aim or entry.pole or entry.free then
		error(string.format("R6Clip: %s uses aim/pole/free, which were removed (no IK). Key angles and pos instead.", part), 4)
	end
	if (entry.space or entry.ground) and part ~= "Right Leg" and part ~= "Left Leg" then
		error(string.format("R6Clip: space/ground are for legs only (%s)", part), 4)
	end
end

-- opts: fps (60), loop, priority ("Action"), budget (part -> studs, overrides R6Rig.GAP),
--       meta (anything: move data for the combat runtime travels with the clip)
function R6Clip.new(name, opts)
	opts = opts or {}
	local budget = table.clone(R6Rig.GAP)
	for part, studs in opts.budget or {} do
		budget[partName(part)] = studs
	end
	return setmetatable({
		name = name,
		fps = opts.fps or 60,
		loop = opts.loop or false,
		priority = opts.priority or "Action",
		curve = opts.curve or R6Clip.curve,
		tension = opts.tension or R6Clip.tension or 0,
		weight = opts.weight or R6Clip.weight,
		weightAsked = opts.weight ~= nil,
		budget = budget,
		meta = opts.meta or {},
		keys = {},
		markers = {},
		leads = {},
		_cache = {},
		_rootCache = {},
	}, R6Clip)
end

-- Deep copy of a pose with overrides merged in: R6Clip.merge(Guard, { Torso = { lean = 20 } })
-- Named angles merge field by field; `pos` merges by axis; a `transform` replaces the whole entry.
function R6Clip.merge(base, over)
	local out = {}
	for part, entry in base or {} do
		local e = table.clone(entry)
		if e.pos then
			e.pos = table.clone(e.pos)
		end
		out[ALIAS[part] or part] = e
	end
	for part, entry in over or {} do
		local name = ALIAS[part] or part
		local into = out[name]
		if into and not into.transform and not entry.transform then
			for k, v in entry do
				if k == "pos" and into.pos then
					local p = table.clone(into.pos)
					for axis, studs in v do
						p[axis] = studs
					end
					into.pos = p
				else
					into[k] = v
				end
			end
		else
			out[name] = table.clone(entry)
		end
	end
	return out
end

-- The same pose on the other side: left and right parts swap, the torso and head turn and tilt the
-- other way, sideways slides flip. A walk or run cycle is half keys plus their mirror.
local MIRROR_PART = { ["Right Arm"] = "Left Arm", ["Left Arm"] = "Right Arm", ["Right Leg"] = "Left Leg", ["Left Leg"] = "Right Leg" }
function R6Clip.mirror(pose)
	local out = {}
	for part, entry in pose do
		local name = ALIAS[part] or part
		local e = table.clone(entry)
		if e.pos then
			e.pos = table.clone(e.pos)
			e.pos.right = e.pos.right and -e.pos.right or nil
		end
		if name == "Torso" or name == "Head" then
			for _, k in { "twist", "turn", "tilt" } do
				if e[k] then
					e[k] = -e[k]
				end
			end
		end
		out[MIRROR_PART[name] or name] = e
	end
	return out
end

function R6Clip:key(frame, pose, ease)
	local key = { frame = frame, ease = ease, parts = {} }
	for name, entry in pose do
		local part = partName(name)
		checkEntry(part, entry)
		if key.parts[part] then
			-- "RightLeg" and "Right Leg" in one pose: which one wins would depend on table order
			error(string.format("R6Clip: %s is keyed twice at frame %s (under two names)", part, tostring(frame)), 2)
		end
		key.parts[part] = entry
	end
	self._cache, self._rootCache = {}, {}
	for i, k in self.keys do
		if k.frame == frame then
			self.keys[i] = key
			return self
		elseif k.frame > frame then
			table.insert(self.keys, i, key)
			return self
		end
	end
	table.insert(self.keys, key)
	return self
end

function R6Clip:marker(frame, name, value)
	table.insert(self.markers, { frame = frame, name = name, value = value or "" })
	return self
end

-- frames > 0: the part moves earlier than its keys (leads); < 0: it trails (drag/overlap).
function R6Clip:lead(part, frames)
	self.leads[partName(part)] = frames
	return self
end

function R6Clip:length()
	local last = self.keys[#self.keys]
	return last and last.frame or 0
end

-- Eases that opts.curve = "auto" turns into smooth curves through the keys: the in-betweens a
-- blocking pass leaves, and the long recoveries home. The strike's own timing (snap, settle,
-- quadIn, quadOut, back...) stays: settle's bounce is the weight of the contact.
local CURVABLE = { sineInOut = true, linear = true, quadInOut = true, cubicInOut = true, recover = true, auto = true }

function R6Clip:_ease(ease)
	local key = type(ease) == "table" and ((ease.settle and "settle") or (ease.recover and "recover")) or ease
	if ease == "auto" or (self.curve == "auto" and (ease == nil or CURVABLE[key])) then
		return "auto"
	end
	return ease
end

-- The two keys around `frame` that name `part`, and the eased alpha between them. On an "auto"
-- segment the alpha is plain time and the 4th value holds the keys on either side ({ prev, next }),
-- for the curve through them (sample() does the curve).
function R6Clip:_segment(part, frame)
	local before, after
	local list = {}
	for _, k in self.keys do
		local entry = k.parts[part]
		if entry then
			table.insert(list, { frame = k.frame, entry = entry, ease = self:_ease(entry.ease or k.ease) })
		end
	end
	local at
	for i, k in list do
		if k.frame <= frame then
			before, at = k, i
		elseif not after then
			after = k
		end
	end
	if not before and not after then
		return nil
	end
	if not before then
		return after, after, 0
	elseif not after then
		return before, before, 0
	end
	local u = (frame - before.frame) / (after.frame - before.frame)
	if before.ease ~= "auto" then
		return before, after, Ease.get(before.ease)(u)
	end
	local prev, nxt = list[at - 1], list[at + 2]
	if self.loop and #list > 2 then
		-- a loop's last key is its first: the neighbours wrap round the cycle
		local len = self:length()
		if not prev and list[#list].frame >= len - 1e-6 then
			local k = list[#list - 1]
			prev = { frame = k.frame - len, entry = k.entry }
		end
		if not nxt and list[1].frame <= 1e-6 then
			local k = list[2]
			nxt = { frame = k.frame + len, entry = k.entry }
		end
	end
	return before, after, u, { prev = prev, next = nxt }
end

-- Monotone cubic (PCHIP) tangent at a key from the slopes on either side: zero at an extreme, never
-- an overshoot, and the speed carried through a key the motion passes.
local function tangent(d0, d1, h0, h1)
	if not d0 or not d1 then
		return 0 -- the clip's first or last key starts or ends at rest
	end
	if d0 * d1 <= 0 then
		return 0
	end
	local w1, w2 = 2 * h1 + h0, h1 + 2 * h0
	return (w1 + w2) / (w1 / d0 + w2 / d1)
end

local function hermite(va, vb, ma, mb, h, u)
	local u2, u3 = u * u, u * u * u
	return (2 * u3 - 3 * u2 + 1) * va + (u3 - 2 * u2 + u) * h * ma + (-2 * u3 + 3 * u2) * vb + (u3 - u2) * h * mb
end

-- one number on the curve through four keys' values (p and n may be missing). tension 0..1 slows
-- the curve at both keys (the tangents shrink by it): uneven speed, the body settling into poses.
local function curveValue(vp, va, vb, vn, fp, fa, fb, fn, u, tension)
	local h = fb - fa
	local d1 = (vb - va) / h
	local d0 = vp and (va - vp) / (fa - fp) or nil
	local d2 = vn and (vn - vb) / (fn - fb) or nil
	local keep = 1 - math.clamp(tension or 0, 0, 1)
	local ma = tangent(d0, d1, vp and (fa - fp) or 1, h) * keep
	local mb = tangent(d1, d2, h, vn and (fn - fb) or 1) * keep
	return hermite(va, vb, ma, mb, h, u)
end
R6Clip.curveValue = curveValue

local blend = Sequence.blend

local function offsetOf(entry)
	local p = entry.pos
	return p and Vector3.new(p.right or 0, p.up or 0, -(p.forward or 0)) or Vector3.zero
end

local function clampFrame(clip, f)
	local len = clip:length()
	if clip.loop and len > 0 then
		return f % len
	end
	return math.clamp(f, 0, len)
end

-- Between two keys of named angles, the ANGLES are interpolated, not the rotations. A rotation
-- blend always takes the shortest way round: an arm going from raise -55 (flung back) to 138 (guard)
-- is 193 degrees apart, so the "short" way swings it backwards over the head. Interpolating raise
-- -55 -> 0 -> 90 -> 138 takes the path the keys describe, down and forward.
local ANGLES = { "lean", "twist", "tilt", "nod", "turn", "raise", "spread", "swing" }
local function lerpEntry(a, b, alpha)
	local out = {}
	for _, k in ANGLES do
		if a[k] or b[k] then
			out[k] = (a[k] or 0) + ((b[k] or 0) - (a[k] or 0)) * alpha
		end
	end
	if a.pos or b.pos then
		local pa, pb = a.pos or {}, b.pos or {}
		out.pos = {}
		for _, axis in { "forward", "up", "right" } do
			out.pos[axis] = (pa[axis] or 0) + ((pb[axis] or 0) - (pa[axis] or 0)) * alpha
		end
	end
	return out
end
R6Clip.lerpEntry = lerpEntry

-- lerpEntry's curved twin: every angle and slide on the "auto" curve through prev, a, b and next
local function curveEntry(p, a, b, n, u, tension)
	local out = {}
	local pe, ne = p and p.entry, n and n.entry
	for _, k in ANGLES do
		if a.entry[k] or b.entry[k] then
			out[k] = curveValue(pe and (pe[k] or 0), a.entry[k] or 0, b.entry[k] or 0, ne and (ne[k] or 0), p and p.frame, a.frame, b.frame, n and n.frame, u, tension)
		end
	end
	if a.entry.pos or b.entry.pos then
		local pa, pb = a.entry.pos or {}, b.entry.pos or {}
		local pp, pn = pe and (pe.pos or {}), ne and (ne.pos or {})
		out.pos = {}
		for _, axis in { "forward", "up", "right" } do
			out.pos[axis] = curveValue(pp and (pp[axis] or 0), pa[axis] or 0, pb[axis] or 0, pn and (pn[axis] or 0), p and p.frame, a.frame, b.frame, n and n.frame, u, tension)
		end
	end
	return out
end
R6Clip.curveEntry = curveEntry

local function named(entry)
	return not entry.transform and entry.space ~= "root"
end

function R6Clip:_torso(frame)
	local a, b, alpha, curve = self:_segment("Torso", frame)
	if not a then
		return CFrame.identity
	end
	if a ~= b and named(a.entry) and named(b.entry) then
		if curve and (not curve.prev or named(curve.prev.entry)) and (not curve.next or named(curve.next.entry)) then
			return R6Rig.pose("Torso", curveEntry(curve.prev, a, b, curve.next, alpha, self.tension))
		end
		return R6Rig.pose("Torso", lerpEntry(a.entry, b.entry, alpha))
	end
	local ta = a.entry.transform or R6Rig.pose("Torso", a.entry)
	local tb = b.entry.transform or R6Rig.pose("Torso", b.entry)
	return blend(ta, tb, alpha)
end

-- A key's entry -> joint Transform, worked out once per key. A root-space leg needs the torso as it
-- will be when that key plays (leads shift the torso against the leg).
function R6Clip:_entry(part, entry, keyFrame)
	local cached = self._cache[entry]
	if cached then
		return cached
	end
	local t
	if entry.transform then
		t = entry.transform
	elseif entry.space == "root" then
		-- The legs hang from a pelvis that takes only `hips` (default 0.35) of the torso's turn and
		-- lean, the way real hips turn less than the shoulders. The hip socket is slid to where that
		-- pelvis puts it, so a torso twisted 60 degrees does not swap the hips front-to-back and
		-- cross the legs. Translation and a fixed rotation per key: no solver.
		local at = clampFrame(self, keyFrame - (self.leads[part] or 0) + (self.leads.Torso or 0))
		local torsoT = self:_torso(at)
		local torsoRot = R6Rig.fromTransform("Torso", torsoT)
		local torso = R6Rig.fk({ Torso = torsoT }).Torso
		local pelvisRot = blend(CFrame.identity, torso.Rotation, entry.hips or 0.35)
		local hipC0 = R6Rig.JOINTS[part].C0.Position
		local slide = (CFrame.new(torso.Position) * pelvisRot) * hipC0 - torso * hipC0
		local rot = pelvisRot * R6Rig.rotation(part, entry)
		t = R6Rig.toTransform(part, torsoRot:Inverse() * rot, torsoRot:Inverse() * (offsetOf(entry) + slide))
		local j = R6Rig.JOINTS[part]
		self._cache[entry] = t
		self._rootCache[entry] = torso * j.C0 * t * j.C1:Inverse() -- the leg in root space
		return t
	else
		t = R6Rig.pose(part, entry)
	end
	self._cache[entry] = t
	return t
end

-- Slide a leg straight up or down (root space) so its sole sits on the floor. Translation only:
-- the leg rides into or out of the torso, its angle never changes. weight 0..1 fades it in and out
-- between a grounded key and a free one.
local function grounded(part, legT, torsoT, weight)
	local w = R6Rig.fk({ Torso = torsoT, [part] = legT })
	local lift = -(R6Rig.tip(part, w[part]).Y + R6Rig.ROOT_HEIGHT) * weight
	if math.abs(lift) < 1e-5 then
		return legT
	end
	local torsoRot = R6Rig.fromTransform("Torso", torsoT)
	local r0 = R6Rig.JOINTS[part].C0.Rotation
	return r0:Inverse() * CFrame.new(torsoRot:Inverse() * Vector3.new(0, lift, 0)) * r0 * legT
end

-- On an "auto" segment between poses that blend as whole rotations (legs on the pelvis, raw
-- transforms), the fraction of the way from a to b, eased so the joint keeps its speed through the
-- keys: a monotone curve over how far the joint travels (degrees, plus studs x 10) key to key.
function R6Clip:_progress(part, p, a, b, n, u)
	local function pose(k)
		local t = self:_entry(part, k.entry, k.frame)
		return k.entry.space == "root" and self._rootCache[k.entry] or t
	end
	local function travel(x, y)
		local cx, cy = pose(x), pose(y)
		return Sequence.angleBetween(cx, cy) + (cx.Position - cy.Position).Magnitude * 10
	end
	local d = travel(a, b)
	if d < 1e-4 then
		return u
	end
	local dp = p and travel(p, a)
	local dn = n and travel(b, n)
	return curveValue(dp and -dp, 0, d, dn and d + dn, p and p.frame, a.frame, b.frame, n and n.frame, u, self.tension) / d
end

-- All six joint Transforms at a (fractional) frame.
function R6Clip:sample(frame)
	local out = {}
	out.Torso = self:_torso(clampFrame(self, frame + (self.leads.Torso or 0)))
	for _, part in R6Rig.ORDER do
		if part ~= "Torso" then
			local f = clampFrame(self, frame + (self.leads[part] or 0))
			local a, b, alpha, curve = self:_segment(part, f)
			if a then
				local t
				local u = alpha
				if curve and a ~= b then
					alpha = self:_progress(part, curve.prev, a, b, curve.next, u)
				end
				if a.entry.space == "root" and b.entry.space == "root" and a ~= b then
					-- blend the leg where it lives (against the root), then hang it from this frame's
					-- torso: a fast torso swing between keys cannot drag the legs through each other
					self:_entry(part, a.entry, a.frame)
					self:_entry(part, b.entry, b.frame)
					local leg = blend(self._rootCache[a.entry], self._rootCache[b.entry], alpha)
					local j = R6Rig.JOINTS[part]
					local torso = R6Rig.fk({ Torso = out.Torso }).Torso
					t = j.C0:Inverse() * torso:Inverse() * leg * j.C1
				elseif a ~= b and named(a.entry) and named(b.entry) then
					if curve and (not curve.prev or named(curve.prev.entry)) and (not curve.next or named(curve.next.entry)) then
						-- per angle and slide, on the curve through the keys (alpha is plain time here)
						t = R6Rig.pose(part, curveEntry(curve.prev, a, b, curve.next, u, self.tension))
					else
						t = R6Rig.pose(part, lerpEntry(a.entry, b.entry, alpha))
					end
				else
					t = blend(self:_entry(part, a.entry, a.frame), self:_entry(part, b.entry, b.frame), alpha)
				end
				local weight = (a.entry.ground and 1 - alpha or 0) + (b.entry.ground and alpha or 0)
				if a == b then
					weight = a.entry.ground and 1 or 0
				end
				if weight > 0 then
					t = grounded(part, t, out.Torso, math.clamp(weight, 0, 1))
				end
				out[part] = t
			else
				out[part] = CFrame.identity
			end
		end
	end
	return out
end

-- Stretch the clip's phases by a weight profile (see opts.weight): keys, markers and the meta
-- frames move together, the strike window keeps its speed. Once per clip; bake() calls it.
local META_FRAMES = { "hit", "cancel", "go" }
local META_WINDOWS = { "strike", "active", "windup", "airborne" }
function R6Clip:weigh(profile)
	local info = self.meta or {}
	if self._weighed or self.loop or info.airborne == true or (info.impact and not info.strike and not self.weightAsked) then
		return self
	end
	profile = type(profile) == "string" and R6Clip.WEIGHTS[profile] or profile
	if not profile then
		return self
	end
	self._weighed = true
	local len = self:length()
	local meta = self.meta or {}
	-- breakpoints and the factor of the span that starts at each
	local cuts
	if meta.strike and meta.hit then
		local cancel = meta.cancel
		for _, m in self.markers do
			if m.name == "Cancel" and not cancel then
				cancel = m.frame
			end
		end
		cancel = math.clamp(cancel or len, meta.hit, len)
		cuts = {
			{ 0, profile.load or 1 },
			{ meta.strike[1], profile.strike or 1 },
			{ meta.hit, profile.hold or 1 },
			{ cancel, profile.recover or 1 },
			{ len, 1 },
		}
	else
		cuts = { { 0, profile.move or 1 }, { len, 1 } }
	end
	local function map(f)
		local out = 0
		for i = 1, #cuts - 1 do
			local a, b, k = cuts[i][1], cuts[i + 1][1], cuts[i][2]
			if f <= a then
				break
			end
			out += (math.min(f, b) - a) * k
		end
		if f > len then
			out += f - len
		end
		return math.floor(out + 0.5)
	end
	for _, k in self.keys do
		k.frame = map(k.frame)
	end
	for _, m in self.markers do
		m.frame = map(m.frame)
	end
	for _, field in META_FRAMES do
		if type(meta[field]) == "number" then
			meta[field] = map(meta[field])
		end
	end
	for _, field in META_WINDOWS do
		if type(meta[field]) == "table" then
			meta[field] = { map(meta[field][1]), map(meta[field][2]) }
		end
	end
	if type(meta.wings) == "table" then
		for _, k in meta.wings do
			k[1] = map(k[1])
		end
	end
	self._cache, self._rootCache = {}, {}
	return self
end

-- opts.step: sample every N frames (1 = every 60 fps frame; 5 = 12 poses a second "on twos")
-- opts.stepped: hold each sample (Constant easing) instead of sliding between them
function R6Clip:bake(opts)
	opts = opts or {}
	if self.weight then
		self:weigh(self.weight)
	end
	local step = opts.step or 1
	local len = self:length()
	-- parts that trail (negative lead) finish after the last key: run on until they land
	if not self.loop then
		for _, frames in self.leads do
			len = math.max(len, self:length() - frames)
		end
	end
	local frames = {}
	local f = 0
	while f <= len + 1e-6 do
		table.insert(frames, { frame = f, time = f / self.fps, transforms = self:sample(f) })
		f += step
	end
	if frames[#frames].frame < len - 1e-6 then
		table.insert(frames, { frame = len, time = len / self.fps, transforms = self:sample(len) })
	end
	local markers = {}
	for _, m in self.markers do
		table.insert(markers, { frame = m.frame, time = m.frame / self.fps, name = m.name, value = m.value })
	end
	return {
		name = self.name,
		fps = self.fps,
		loop = self.loop,
		priority = self.priority,
		stepped = opts.stepped or false,
		frames = frames,
		markers = markers,
		meta = self.meta,
		budget = self.budget,
		leads = table.clone(self.leads),
	}
end

-- Drop keys that straight interpolation between their neighbours reproduces (Ramer-Douglas-Peucker
-- per part). tolerance in degrees (default 0.25, below what the eye sees), studs/10 for offsets.
local angle = Sequence.angleBetween

function R6Clip.reduce(baked, tolerance)
	tolerance = tolerance or 0.25
	local forced = {}
	for _, m in baked.markers do
		forced[m.time] = true
	end
	local tracks = {}
	for _, part in R6Rig.ORDER do
		local samples = {}
		for _, fr in baked.frames do
			table.insert(samples, { time = fr.time, cf = fr.transforms[part] or CFrame.identity })
		end
		local keep = { [1] = true, [#samples] = true }
		local function split(i, j)
			if j - i < 2 then
				return
			end
			local worst, at = 0, nil
			for k = i + 1, j - 1 do
				local u = (samples[k].time - samples[i].time) / (samples[j].time - samples[i].time)
				local guess = blend(samples[i].cf, samples[j].cf, u)
				local err = angle(guess, samples[k].cf) + (guess.Position - samples[k].cf.Position).Magnitude * 10
				if err > worst then
					worst, at = err, k
				end
			end
			if worst > tolerance then
				keep[at] = true
				split(i, at)
				split(at, j)
			end
		end
		split(1, #samples)
		local track = {}
		for i, s in samples do
			if keep[i] or forced[s.time] or baked.stepped then
				table.insert(track, s)
			end
		end
		tracks[part] = track
	end
	return tracks
end

-- Baked clip -> KeyframeSequence (Roblox Instance). opts.reduce (default true) thins keys first.
function R6Clip.toKeyframeSequence(baked, opts)
	opts = opts or {}
	local tracks
	if opts.reduce == false then
		tracks = {}
		for _, part in R6Rig.ORDER do
			tracks[part] = {}
			for _, fr in baked.frames do
				table.insert(tracks[part], { time = fr.time, cf = fr.transforms[part] or CFrame.identity })
			end
		end
	else
		tracks = R6Clip.reduce(baked, opts.tolerance)
	end

	local byTime = {}
	local function at(time)
		local key = math.floor(time * 10000 + 0.5)
		byTime[key] = byTime[key] or { time = time, poses = {} }
		return byTime[key]
	end
	for part, track in tracks do
		for _, s in track do
			local x = s.cf.XVector.X + s.cf.Position.X
			if x ~= x then
				-- a NaN Pose plays as a silent rest pose in Roblox; fail loudly instead
				error(string.format("R6Clip: NaN in %s at %.3fs of %s", part, s.time, baked.name), 2)
			end
			at(s.time).poses[part] = s.cf
		end
	end
	for _, m in baked.markers do
		at(m.time)
	end

	local ks = Instance.new("KeyframeSequence")
	ks.Name = baked.name
	ks.Loop = baked.loop
	ks.Priority = Enum.AnimationPriority[baked.priority]
	local style = baked.stepped and Enum.PoseEasingStyle.Constant or Enum.PoseEasingStyle.Linear

	local times = {}
	for _, entry in byTime do
		table.insert(times, entry)
	end
	table.sort(times, function(a, b)
		return a.time < b.time
	end)
	for _, entry in times do
		local kf = Instance.new("Keyframe")
		kf.Time = entry.time
		local root = Instance.new("Pose")
		root.Name = "HumanoidRootPart"
		root.Weight = 0
		root.Parent = kf
		local torso = Instance.new("Pose")
		torso.Name = "Torso"
		torso.Weight = entry.poses.Torso and 1 or 0
		torso.CFrame = entry.poses.Torso or CFrame.identity
		torso.EasingStyle = style
		torso.EasingDirection = Enum.PoseEasingDirection.In
		torso.Parent = root
		for _, part in { "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
			local cf = entry.poses[part]
			if cf then
				local pose = Instance.new("Pose")
				pose.Name = part
				pose.Weight = 1
				pose.CFrame = cf
				pose.EasingStyle = style
				pose.EasingDirection = Enum.PoseEasingDirection.In
				pose.Parent = torso
			end
		end
		for _, m in baked.markers do
			if math.abs(m.time - entry.time) < 1e-4 then
				local marker = Instance.new("KeyframeMarker")
				marker.Name = m.name
				marker.Value = m.value
				marker.Parent = kf
			end
		end
		kf.Parent = ks
	end
	return ks
end

-- Baked clip -> the JSON the Eclipse Animator MCP save_animation tool takes.
function R6Clip.toEclipse(baked, opts)
	opts = opts or {}
	local tracks = R6Clip.reduce(baked, opts.tolerance)
	local byTime = {}
	for part, track in tracks do
		for _, s in track do
			local key = math.floor(s.time * 10000 + 0.5)
			byTime[key] = byTime[key] or { time = s.time, poses = {} }
			local rx, ry, rz = s.cf:ToEulerAnglesXYZ()
			local p = s.cf.Position
			local function r(x)
				return math.floor(x * 1000 + 0.5) / 1000
			end
			byTime[key].poses[part] = {
				rot = { r(math.deg(rx)), r(math.deg(ry)), r(math.deg(rz)) },
				pos = { r(p.X), r(p.Y), r(p.Z) },
				easing = baked.stepped and "Constant" or "Linear",
			}
		end
	end
	local keyframes = {}
	for _, k in byTime do
		table.insert(keyframes, k)
	end
	table.sort(keyframes, function(a, b)
		return a.time < b.time
	end)
	return { name = baked.name, loop = baked.loop, priority = baked.priority, keyframes = keyframes }
end

-- Character-space CFrame of every part on every baked frame (for previews and audits).
function R6Clip.world(baked)
	local out = {}
	for _, fr in baked.frames do
		table.insert(out, { time = fr.time, frame = fr.frame, parts = R6Rig.fk(fr.transforms) })
	end
	return out
end

-- The shape of a strike in frames, to compare against a reference clip or video:
--   load     frames from the start to the deepest chamber (where the release begins)
--   release  frames from the deepest chamber until the tip covers 90% of its travel
--   hold     frames the tip then stays within 15% of its extreme
--   back     frames from the end of the hold until the tip is 90% of the way home
--   lean     degrees the torso leans from upright at the extreme
--   rearPull studs the other arm's fist moves back, relative to the chest, during the release
-- limb: "LeftArm" etc.; dir: strike direction in character space (default forward).
function R6Clip.profile(baked, limb, dir, tipPoint)
	limb = ALIAS[limb] or limb
	dir = dir or Vector3.new(0, 0, -1)
	local other = ({ ["Left Arm"] = "Right Arm", ["Right Arm"] = "Left Arm" })[limb]
	local world = R6Clip.world(baked)
	local ext, rear = {}, {}
	for i, w in world do
		ext[i] = (tipPoint and w.parts[limb] * tipPoint or R6Rig.tip(limb, w.parts[limb])):Dot(dir)
		-- the rear hand is judged against the chest, not the floor: the body lunges forward under it
		local torso = w.parts.Torso
		rear[i] = other and torso:PointToObjectSpace(R6Rig.tip(other, w.parts[other])):Dot(torso:VectorToObjectSpace(dir)) or 0
	end
	local n = #ext
	local peakI = 1
	for i = 1, n do
		if ext[i] > ext[peakI] + 1e-4 then
			peakI = i
		end
	end
	local lowI = 1
	for i = 1, peakI do
		if ext[i] < ext[lowI] - 1e-4 then
			lowI = i
		end
	end
	local low, peak = ext[lowI], ext[peakI]
	local span = math.max(peak - low, 1e-6)
	local arrive = peakI
	for i = lowI, peakI do
		if ext[i] >= low + 0.9 * span then
			arrive = i
			break
		end
	end
	local holdEnd = arrive
	while holdEnd < n and ext[holdEnd + 1] >= peak - 0.15 * span do
		holdEnd += 1
	end
	local home = n
	local base = ext[n] -- the guard it returns to (the first frame may already be loading)
	for i = holdEnd, n do
		if ext[i] <= base + 0.1 * (peak - base) then
			home = i
			break
		end
	end
	local torsoUp = world[peakI].parts.Torso.UpVector
	return {
		load = lowI - 1,
		release = arrive - lowI,
		hold = holdEnd - arrive,
		back = home - holdEnd,
		lean = math.deg(math.acos(math.clamp(torsoUp.Y, -1, 1))),
		rearPull = rear[lowI] - rear[arrive],
		extremeFrame = peakI - 1,
		reach = span,
	}
end

-- The house grammar (the user's R6 movement system), measured with tools/house.luau. Every clip is
-- held to how that system moves the body:
--   bury   how far a leg's top rides up into the torso (the leg is 2 long). The house lowers the
--          body on ONE leg: its crouch puts the front leg 0.96 in and keeps the back one 0.11,
--          stretched behind; its run passes 0.46/-0.20. Two legs sunk together read as stumps.
--          held: in a pose held 10+ frames the shallower leg stays within 0.4; peak: no leg past
--          1.4 (its crouch-walk 1.32). Landings (meta.impact) are the house's own exception.
--   width  feet under the hips: soles 0.5-0.82 out from the centre in every grounded house clip
--   lean   a lowered body leans into it, about 30 degrees per stud of drop (crouch 0.74 -> 22,
--          run 0.33 -> 20, walk 0.25 -> 9): at least 20 per stud once the drop passes 0.3
--   face   the head counters the lean: in held and moving house clips the face looks 2-13
--          degrees down, never past 15 (landings and crawls aside)
-- width, lean and face are checked on grounded loops (idles, stances, guards, walks, runs).
R6Clip.HOUSE = {
	bury = { held = 0.4, peak = 1.4, frames = 10 },
	width = 0.85,
	leanPerStud = 20,
	leanFrom = 0.3,
	face = -15,
}

-- The hard rules, checked on numbers instead of eyes:
--   pops      no part jumps in one frame (a spike against its neighbours, or over maxStep = 90
--             degrees) unless a "Snap" marker or the meta.strike window covers it
--   contact   the striking limb is at its most extended within 2 frames of the "Hit" marker
--   placement the hit lands 15-60% into the move (short before, long after)
--   hold      the strike reads for 4+ frames
--   commit    a straight punch puts the whole body behind it: the fist ends at least
--             meta.minReach (2.4) studs in front of the root and the torso turns at least
--             meta.minTwist (25) degrees into it. Timid, tucked-in strikes fail here.
--   gap       no part leaves its socket further than its budget (R6Rig.GAP, clip opts.budget)
--   legs      the two legs never cross or pass through each other (centre lines 0.75+ apart), and
--             never form an X seen from the side or the front (meta.stride: walks and runs pass
--             their legs on purpose, only the front view is checked)
--   overhead  no fist swings above the shoulders AND behind the back unless meta.overhead says the
--             move means it: that is the "long way round" a rotation blend takes between poses
--             more than 180 degrees apart (an arm flung back coming home over the head)
--   swing     a weapon cut (meta.tip) sweeps 120+ degrees from its wind-up to its follow-through,
--             and an overhead cut (meta.cut = "overhead") starts with the blade over and behind the head
--   export    the KeyframeSequence export, played the way Roblox plays it (shortest-way blends
--             between the kept keys), reproduces the clip within 1 degree
--   feet      soles stay on the floor (y = -3) unless meta.airborne; both off it needs meta.hop.
--             The note says how far to slide the leg (pos.up) or to set ground = true.
--   bury      the legs ride into the torso the house way: never both together in a held pose,
--             none past 1.4 (R6Clip.HOUSE; meta.bury, meta.buryHeld, meta.impact for landings)
--   house     grounded loops keep the house grammar's body: feet under the hips, the lean
--             following the drop, the face near level (R6Clip.HOUSE)
-- meta.limb names the striking part; meta.tip, a point in that part's space, is where it strikes
-- from when it holds a weapon (a sword in a Tool's default grip: Vector3.new(0, -1, -blade), the
-- blade standing out of the fist along the arm's front). Returns { ok, notes = {...}, metrics = {...} }.
function R6Clip.audit(baked, meta)
	meta = meta or baked.meta or {}
	local notes, metrics = {}, {}
	local world = R6Clip.world(baked)
	local snaps = {}
	for _, m in baked.markers do
		if m.name == "Snap" then
			snaps[math.floor(m.frame + 0.5)] = true
		end
	end
	-- the strike itself (chamber -> contact) is meant to be fast; only pops elsewhere count. Parts
	-- that lead strike earlier and parts that trail strike later, so the window widens by both.
	local leadMost, trailMost = 0, 0
	for _, frames in baked.leads or {} do
		leadMost, trailMost = math.max(leadMost, frames), math.max(trailMost, -frames)
	end
	for _, window in { meta.strike } do
		for f = window[1] + 1 - leadMost, window[2] + trailMost do
			snaps[f] = true
		end
	end

	-- Measured on what the eye sees (each part's turn in character space), not on joint angles.
	-- A pop is a spike: a frame that turns far more than the frames on either side of it, or an
	-- absurd turn in one frame. Fast but continuous motion is the strike doing its job.
	local steps = {}
	for i = 2, #baked.frames do
		local a, b = baked.frames[i - 1], baked.frames[i]
		local frameGap = math.max(1, b.frame - a.frame)
		steps[i] = {}
		for _, part in R6Rig.ORDER do
			local step = angle(world[i - 1].parts[part], world[i].parts[part]) / frameGap
			local slide = (world[i - 1].parts[part].Position - world[i].parts[part].Position).Magnitude / frameGap
			step = math.max(step, slide * 40) -- a 0.5-stud jump in one frame reads like a 20-degree pop
			if step ~= step then
				table.insert(notes, "NaN in " .. part .. " at frame " .. b.frame)
				step = 0
			end
			steps[i][part] = step
		end
	end
	local worstStep = 0
	for i = 2, #baked.frames do
		local frame = math.floor(baked.frames[i].frame + 0.5)
		for _, part in R6Rig.ORDER do
			local step = steps[i][part]
			worstStep = math.max(worstStep, step)
			local before = steps[i - 1] and steps[i - 1][part] or 0
			local after = steps[i + 1] and steps[i + 1][part] or 0
			local spike = step > (meta.popMin or 20) and step > 2.2 * math.max(before, after, 1)
			local absurd = step > (meta.maxStep or 90)
			if (spike or absurd) and not snaps[frame] and not baked.stepped then
				table.insert(notes, string.format("pop: %s jumps %.0f in one frame at frame %d (neighbours %.0f, %.0f)", part, step, frame, before, after))
			end
		end
	end
	metrics.worstDegPerFrame = worstStep

	-- sockets: how far each part slides out, against its budget
	local budget = baked.budget or R6Rig.GAP
	metrics.gap = {}
	for _, part in R6Rig.ORDER do
		if part ~= "Torso" then
			local most, at = 0, 0
			for _, fr in baked.frames do
				local g = R6Rig.gap(part, fr.transforms[part] or CFrame.identity).Magnitude
				if g > most then
					most, at = g, fr.frame
				end
			end
			metrics.gap[part] = most
			if budget[part] and most > budget[part] + 1e-3 then
				table.insert(notes, string.format("gap: %s leaves its socket by %.2f studs at frame %d (budget %.2f)", part, most, at, budget[part]))
			end
		end
	end

	local hit
	for _, m in baked.markers do
		if m.name == "Hit" then
			hit = m.frame
			break
		end
	end
	local function frameAt(f)
		for i, w in world do
			if math.abs(w.frame - f) < 0.5 then
				return i, w
			end
		end
		return nil
	end
	local function strikeTip(limb, cf)
		return meta.tip and cf * meta.tip or R6Rig.tip(limb, cf)
	end
	if hit and meta.limb and meta.arc then
		-- a sweeping strike (hook, roundhouse) lands where the tip crosses the centre line in front
		local limb = ALIAS[meta.limb] or meta.limb
		if meta.contactHeight then
			assert(type(meta.contactHeight[1]) == "number" and type(meta.contactHeight[2]) == "number"
				and meta.contactHeight[1] < meta.contactHeight[2], "contactHeight needs increasing numeric bounds")
		end
		local bestFrame, bestX = nil, math.huge
		for _, w in world do
			local tip = strikeTip(limb, w.parts[limb])
			if math.abs(w.frame - hit) <= 8 and tip.Z < -0.8
				and (not meta.contactHeight or (tip.Y >= meta.contactHeight[1] and tip.Y <= meta.contactHeight[2]))
				and math.abs(tip.X) < bestX then
				bestX, bestFrame = math.abs(tip.X), w.frame
			end
		end
		metrics.crossFrame = bestFrame
		if not bestFrame or bestX > 0.6 then
			table.insert(notes, "contact: the sweeping limb never crosses the centre line in front near the hit")
		elseif math.abs(bestFrame - hit) > 2 then
			table.insert(notes, string.format("contact: %s crosses the centre line at frame %d, the Hit marker is at %d", limb, bestFrame, hit))
		end
	elseif hit and meta.limb then
		local limb = ALIAS[meta.limb] or meta.limb
		local best, bestFrame, atHit = -math.huge, nil, nil
		local dir = meta.direction or Vector3.new(0, 0, -1)
		for _, w in world do
			local reachOut = strikeTip(limb, w.parts[limb]):Dot(dir)
			if reachOut > best + 1e-4 then
				best, bestFrame = reachOut, w.frame
			end
			if math.abs(w.frame - hit) < 0.5 then
				atHit = reachOut
			end
		end
		metrics.extremeFrame = bestFrame
		metrics.reachAtHit = atHit
		-- creeping a hair further while the hit holds is fine; arriving late is not
		local late = atHit and best - atHit > 0.1
		if bestFrame and math.abs(bestFrame - hit) > 2 and late then
			table.insert(notes, string.format("contact: %s is most extended at frame %d, the Hit marker is at %d", limb, bestFrame, hit))
		end
		local len = baked.frames[#baked.frames].frame
		metrics.hitShare = len > 0 and hit / len or 0
		if not baked.loop and (metrics.hitShare < 0.15 or metrics.hitShare > 0.6) then
			table.insert(notes, string.format("placement: the hit lands %.0f%% into the move (aim for 20-50%%)", metrics.hitShare * 100))
		end
		-- the strike should hold: 4+ frames near the extreme around the hit
		local holdFrames = 0
		for i = 2, #baked.frames do
			local fr = baked.frames[i]
			if fr.frame >= hit and fr.frame <= hit + 12 then
				if angle(world[i - 1].parts[limb], world[i].parts[limb]) < 2.5 then
					holdFrames += 1
				end
			end
		end
		metrics.holdFrames = holdFrames
		if holdFrames < 3 then
			table.insert(notes, "hold: the strike barely holds after the hit (want 4-6 readable frames)")
		end
		-- commitment: a straight arm strike forward needs the body behind it
		local straight = (limb == "Left Arm" or limb == "Right Arm") and dir.Z < -0.7
		local _, w = frameAt(hit)
		if straight and w and not meta.noCommit then
			local torso = w.parts.Torso
			local twist = math.deg(math.atan2(-torso.LookVector.X, -torso.LookVector.Z))
			metrics.twistAtHit, metrics.lungeAtHit = twist, -torso.Position.Z
			local minReach, minTwist = meta.minReach or 2.4, meta.minTwist or 25
			if atHit and atHit < minReach then
				table.insert(notes, string.format("commit: the fist ends only %.2f studs in front at the hit (want %.1f+; R6 punch references end 2.3-4.2): turn the torso in, lunge, push the shoulder out with pos.forward", atHit, minReach))
			end
			if math.abs(twist) < minTwist then
				table.insert(notes, string.format("commit: the torso is turned only %.0f degrees into the punch (want %d+; references 30-110)", math.abs(twist), minTwist))
			end
		end
	end

	-- bury and the house grammar's body rules (R6Clip.HOUSE)
	do
		local H = R6Clip.HOUSE
		local peakBudget, heldBudget = meta.bury or H.bury.peak, meta.buryHeld or H.bury.held
		local peak, peakAt, peakLeg = 0, 0, ""
		local run, held, heldAt, heldDepth = 0, 0, 0, 0
		local loopCheck = baked.loop and not meta.airborne
		local wide, wideAt, upright, uprightAt, uprightLean, uprightDrop, face, faceAt = 0, 0, math.huge, 0, 0, 0, 0, 0
		for _, w in world do
			local t = w.parts.Torso
			local depth = {}
			for _, leg in { "Left Leg", "Right Leg" } do
				depth[leg] = t:PointToObjectSpace(w.parts[leg] * Vector3.new(0, 1, 0)).Y + 1
				if depth[leg] > peak then
					peak, peakAt, peakLeg = depth[leg], w.frame, leg
				end
				if loopCheck then
					local side = math.abs((w.parts[leg] * Vector3.new(0, -1, 0)).X)
					if side > wide then
						wide, wideAt = side, w.frame
					end
				end
			end
			local shallow = math.min(depth["Left Leg"], depth["Right Leg"])
			run = shallow > heldBudget and run + 1 or 0
			if run > held then
				held, heldAt, heldDepth = run, w.frame, shallow
			end
			if loopCheck then
				local drop = -t.Position.Y
				local lean = math.deg(math.asin(math.clamp(-t.UpVector.Z, -1, 1)))
				if drop > H.leanFrom then
					local perStud = lean / drop
					if perStud < upright then
						upright, uprightAt, uprightLean, uprightDrop = perStud, w.frame, lean, drop
					end
				end
				local pitch = math.deg(math.asin(math.clamp(w.parts.Head.LookVector.Y, -1, 1)))
				if pitch < face then
					face, faceAt = pitch, w.frame
				end
			end
		end
		metrics.bury = peak
		if peak > peakBudget + 1e-3 then
			table.insert(notes, string.format("bury: %s rides %.2f studs into the torso at frame %d (house peak %.2f): lower the body less", peakLeg, peak, peakAt, peakBudget))
		end
		-- in the air the house tucks both legs on purpose (its jump and climb)
		if held >= H.bury.frames and not meta.impact and not meta.airborne then
			table.insert(notes, string.format("bury: both legs stay %.2f+ studs inside the torso for %d frames (to frame %d): the body is lowered on both legs like stumps. Lower it the house way: split the feet front and back, the front leg takes the depth (up to 1.0), the back leg stays long (within %.2f) and stretches behind", heldBudget, held, heldAt, heldBudget))
		end
		if loopCheck then
			metrics.feetWidth, metrics.faceDown = wide, face
			if wide > H.width + 1e-3 then
				table.insert(notes, string.format("house: a sole is %.2f studs out from the centre at frame %d (house feet stay under the hips, 0.5-%.2f): stand narrower and split the feet front and back instead", wide, wideAt, H.width))
			end
			if upright < H.leanPerStud then
				table.insert(notes, string.format("house: the body drops %.2f but leans only %.0f degrees at frame %d (the house leans about 30 per stud of drop, at least %d): lean into the drop, or drop less", uprightDrop, uprightLean, uprightAt, H.leanPerStud))
			end
			if face < H.face then
				table.insert(notes, string.format("house: the face looks %.0f degrees down at frame %d (house held and moving poses: 2-13 down): nod the head up against the torso's lean", -face, faceAt))
			end
		end
	end

	-- legs: two blocks a stud wide whose centre lines come closer than legGap (0.75) are passing
	-- through each other: an X from the side, or one leg inside the other from the front
	do
		local function closest(p1, q1, p2, q2)
			local d1, d2, r = q1 - p1, q2 - p2, p1 - p2
			local a, e, f = d1:Dot(d1), d2:Dot(d2), d2:Dot(r)
			local c, b = d1:Dot(r), d1:Dot(d2)
			local denom = a * e - b * b
			local s1 = denom > 1e-9 and math.clamp((b * f - c * e) / denom, 0, 1) or 0
			local t1 = math.clamp((b * s1 + f) / e, 0, 1)
			s1 = math.clamp((b * t1 - c) / a, 0, 1)
			return ((p1 + d1 * s1) - (p2 + d2 * t1)).Magnitude
		end
		local nearest, at = math.huge, 0
		local scissor, scissorAt, scissorView = 0, nil, nil
		for _, w in world do
			local l, r = w.parts["Left Leg"], w.parts["Right Leg"]
			local d = closest(l * Vector3.new(0, 0.9, 0), l * Vector3.new(0, -0.9, 0), r * Vector3.new(0, 0.9, 0), r * Vector3.new(0, -0.9, 0))
			if d < nearest then
				nearest, at = d, w.frame
			end
			-- seen from the side (Z) or the front (X): the hips in one order, the soles in the other,
			-- both by a clear margin, is an X
			local hipL, hipR = l * Vector3.new(0, 1, 0), r * Vector3.new(0, 1, 0)
			local soleL, soleR = R6Rig.tip("Left Leg", l), R6Rig.tip("Right Leg", r)
			-- a stride (walk, run) passes one leg past the other seen from the side on purpose:
			-- only the front view counts there
			local views = meta.stride and { { "front", "X" } } or { { "side", "Z" }, { "front", "X" } }
			for _, view in views do
				local axis = view[2]
				local hips, soles = hipL[axis] - hipR[axis], soleL[axis] - soleR[axis]
				local amount = math.min(math.abs(hips), math.abs(soles))
				if hips * soles < 0 and amount > 0.3 and amount > scissor then
					scissor, scissorAt, scissorView = amount, w.frame, view[1]
				end
			end
		end
		metrics.legGap = nearest
		if not meta.legsMayCross then
			if nearest < (meta.legGap or 0.75) then
				table.insert(notes, string.format("legs: the legs pass through each other at frame %d (centre lines %.2f studs apart; use space = \"root\" legs or spread them)", at, nearest))
			end
			if scissorAt then
				table.insert(notes, string.format("legs: the legs cross into an X seen from the %s at frame %d (by %.2f studs): the hips are in one order and the feet in the other; keep the legs on a pelvis (space = \"root\", hips 0.2-0.5) or step the feet the other way", scissorView, scissorAt, scissor))
			end
		end
	end

	-- swing: a weapon is swung, not punched. From the wind-up (meta.strike[1]) to the end of its
	-- follow-through (meta.cancel) the blade has to travel a wide arc (meta.minArc degrees, default
	-- 120), and a
	-- cut from above (meta.cut = "overhead") has to start with the blade raised over the head and
	-- hanging behind it. A punch-shaped cut (the arm pushed out along a line) fails both.
	if meta.tip and meta.strike and meta.hit and meta.swing ~= false then
		local limb = ALIAS[meta.limb] or meta.limb
		local side = limb == "Left Arm" and -1 or 1
		local function tipDir(w)
			local shoulder = w.parts.Torso * Vector3.new(side, 0.5, 0)
			return (w.parts[limb] * meta.tip - shoulder).Unit
		end
		local startW = world[math.floor(meta.strike[1]) + 1]
		local last = math.min(#world, math.floor((meta.cancel or #world) + 0.5) + 1)
		if startW and limb and world[1].parts[limb] then
			-- the arc the blade travels (summed frame to frame), not the angle between its ends: a
			-- diagonal cut from behind one shoulder to behind the other hip ends close to where it
			-- started, round the long way
			-- (the swing ends where the blade first comes to rest after the hit: the settle's bounces
			-- and the walk home are not part of the cut)
			local widest, prev, stretch, n = 0, tipDir(startW), 0, 0
			for i = math.floor(meta.strike[1]) + 2, last do
				local d = tipDir(world[i])
				local step = math.deg(math.acos(math.clamp(prev:Dot(d), -1, 1)))
				if world[i].frame > meta.hit and step < 1.5 then
					break
				end
				widest += step
				prev = d
				stretch += R6Rig.gap(limb, baked.frames[i].transforms[limb]).Magnitude
				n += 1
			end
			metrics.swingArc = widest
			-- the arm out at full stretch through the swing: its shoulder slid out of the socket
			metrics.swingStretch = n > 0 and stretch / n or 0
			if n > 0 and metrics.swingStretch < (meta.minStretch or 0) then
				table.insert(notes, string.format("swing: the sword arm is slid out only %.2f studs on average through the swing (want %.2f+): reach out at full stretch, the shoulder thrown out along the arc (pos), not tucked in like a punch", metrics.swingStretch, meta.minStretch))
			end
			if widest < (meta.minArc or 120) then
				table.insert(notes, string.format("swing: the blade travels only %.0f degrees of arc from the wind-up (frame %d) to the end of its follow-through (want %d+): a weapon is swung, not punched. Wind it up further back, keep the arm out at full stretch through the cut (spread / pos out), and carry it through past the target", widest, meta.strike[1], meta.minArc or 120))
			end
			if meta.cut == "overhead" then
				local head = startW.parts.Head.Position
				local tip = startW.parts[limb] * meta.tip
				metrics.windupTipHeight = tip.Y - head.Y
				if tip.Y < head.Y + 1.5 or tip.Z < head.Z - 0.5 then
					table.insert(notes, string.format("swing: an overhead cut starts with the blade %.1f above the head and %.1f behind it at frame %d (want 1.5+ above and the tip hanging behind): raise the sword all the way over the head before the cut", tip.Y - head.Y, tip.Z - head.Z, meta.strike[1]))
				end
			end
		end
	end

	-- overhead: above the shoulders and behind the back at once
	if not meta.overhead then
		local worst, at, arm = 0, nil, nil
		for _, w in world do
			for _, part in { "Left Arm", "Right Arm" } do
				local p = w.parts.Torso:PointToObjectSpace(R6Rig.tip(part, w.parts[part]))
				local score = math.min(p.Y - 1, p.Z - 0.3)
				if score > worst then
					worst, at, arm = score, w.frame, part
				end
			end
		end
		if at then
			table.insert(notes, string.format("overhead: %s swings over the head behind the back at frame %d (by %.2f studs). If it is not meant, two keys are more than 180 degrees apart and the blend took the long way round: key named angles (R6Clip interpolates those) or add a passing key; if it is meant, set meta.overhead", arm, at, worst))
		end
	end

	-- export: what Roblox will play from the exported keys
	do
		local tracks = R6Clip.reduce(baked)
		local worst, at, worstPart = 0, nil, nil
		for _, part in R6Rig.ORDER do
			local track = tracks[part]
			local k = 1
			for _, fr in baked.frames do
				while track[k + 1] and track[k + 1].time < fr.time - 1e-6 do
					k += 1
				end
				local a, b = track[k], track[k + 1] or track[k]
				local u = b.time > a.time and math.clamp((fr.time - a.time) / (b.time - a.time), 0, 1) or 0
				local played = blend(a.cf, b.cf, u)
				local err = angle(played, fr.transforms[part] or CFrame.identity)
				if err > worst then
					worst, at, worstPart = err, fr.frame, part
				end
			end
		end
		metrics.exportError = worst
		if worst > 1 then
			table.insert(notes, string.format("export: the exported keys play %s %.1f degrees off the clip at frame %d", worstPart, worst, at))
		end
	end

	if not meta.airborne then
		local dig, digAt, digLeg, hover, hoverAt = 0, 0, nil, 0, 0
		for _, w in world do
			local lowest = math.huge
			for _, leg in { "Right Leg", "Left Leg" } do
				local y = R6Rig.tip(leg, w.parts[leg]).Y + R6Rig.ROOT_HEIGHT
				lowest = math.min(lowest, y)
				if -y > dig then
					dig, digAt, digLeg = -y, w.frame, leg
				end
			end
			if lowest > hover then
				hover, hoverAt = lowest, w.frame
			end
		end
		metrics.dig, metrics.hover = dig, hover
		if dig > 0.1 then
			table.insert(notes, string.format("feet: %s sinks %.2f studs into the floor at frame %d (slide it up: pos.up +%.2f there, or ground = true)", digLeg, dig, digAt, dig))
		end
		if hover > 0.25 and not meta.hop then
			table.insert(notes, string.format("feet: both soles leave the floor by %.2f studs at frame %d (slide a leg down, or set meta.hop)", hover, hoverAt))
		end
	end
	return { ok = #notes == 0, notes = notes, metrics = metrics }
end

return R6Clip
