-- R6Study: measure an R6 animation the way you need to copy it. Point it at any R6
-- KeyframeSequence (a Creator Store pack, the user's own rig, the user's movement system) and it
-- answers the questions that matter when you imitate a clip:
--   when   length, where the strike peaks (share of the move), how many frames the release and the
--          hold take, which easing styles the poses use
--   how far  each part's rotation reach, the torso's drop and lunge, and how far every limb LEAVES
--          its socket (the "gap": translation the clip adds on top of the rotation)
--
--   local seq = Sequence.read(ks)
--   local report = R6Study.measure(seq)          -- numbers
--   print(R6Study.format(report))                -- a short table to read
--
-- The gap is the translation in the joint's Transform: how far the shoulder, hip or neck point has
-- been pushed out of (or into) the torso. Rotation alone never makes a gap.

local R6Rig = require(script.Parent.R6Rig)
local Sequence = require(script.Parent.Sequence)

local R6Study = {}

-- How far a part's joint has been slid away from its socket, in the parent's space (+X right, +Y up,
-- -Z forward). Roblox rotates a part about its joint (C0), so a pure rotation leaves this at zero;
-- anything here is translation the animator added on purpose. joints: R6Rig.fromModel(rig) for a
-- custom rig, else stock.
R6Study.gap = R6Rig.gap

-- How far the part LOOKS detached: the smallest slide left over when the rotation is taken about
-- any point on the limb's upper half (or the head's lower half). Tools that rotate a block about its
-- own centre add joint translation that is not a visible gap; this number ignores it.
function R6Study.visible(part, transform, joints)
	if part == "Torso" then
		return 0
	end
	local j = (joints and joints[part]) or R6Rig.JOINTS[part]
	local from, to = -0.5, 1
	if part == "Head" then
		from, to = -0.5, 0
	end
	local best = math.huge
	for i = 0, 15 do
		local y = from + (to - from) * i / 15
		local p = j.C1:Inverse() * Vector3.new(0, y, 0)
		best = math.min(best, (transform * p - p).Magnitude)
	end
	return best
end

local function round(x, n)
	local m = 10 ^ (n or 2)
	return math.floor(x * m + 0.5) / m
end

-- seq: Sequence.read(ks). opts.fps (60), opts.joints.
function R6Study.measure(seq, opts)
	opts = opts or {}
	local fps = opts.fps or 60
	local steps = math.max(1, math.floor(seq.length * fps + 0.5))
	local frames = {}
	for i = 0, steps do
		local transforms = Sequence.sample(seq, i / fps)
		frames[i] = { transforms = transforms, world = R6Rig.fk(transforms, nil, opts.joints) }
	end

	local report = {
		name = seq.name,
		length = seq.length,
		frames = steps,
		loop = seq.loop,
		priority = seq.priority,
		markers = seq.markers,
		parts = {},
		strikes = {},
	}
	local analysis = Sequence.analyze(seq, fps)
	report.keyframes, report.dense, report.easing = analysis.keyframes, analysis.dense, analysis.easing

	-- rotation reach and socket gaps
	for _, part in R6Rig.ORDER do
		local reach, gapMax, gapAt, gapSum, gapVec = 0, 0, 0, 0, Vector3.zero
		local visMax, visSum = 0, 0
		local first = frames[0].transforms[part] or CFrame.identity
		for i = 0, steps do
			local t = frames[i].transforms[part] or CFrame.identity
			reach = math.max(reach, Sequence.angleBetween(CFrame.identity, t))
			local g
			if part == "Torso" then
				-- the body's own travel against the root: drop and lunge
				g = frames[i].world.Torso.Position
			else
				g = R6Study.gap(part, t, opts.joints)
			end
			gapSum += g.Magnitude
			local v = R6Study.visible(part, t, opts.joints)
			visMax, visSum = math.max(visMax, v), visSum + v
			if g.Magnitude > gapMax then
				gapMax, gapAt, gapVec = g.Magnitude, i, g
			end
		end
		report.parts[part] = {
			reach = reach, -- degrees from the rig's rest pose at its furthest
			fromFirst = analysis.parts[part] and analysis.parts[part].reach or 0,
			gap = gapMax, -- studs the socket point is off at its furthest
			gapAvg = gapSum / (steps + 1),
			gapFrame = gapAt,
			gapDir = gapVec, -- parent space: +X right, +Y up, -Z forward
			visible = visMax, -- studs it looks pulled out of the socket at its furthest
			visibleAvg = visSum / (steps + 1),
			keyed = first ~= nil and seq.tracks[part] ~= nil,
		}
	end

	-- torso posture over the clip
	local lowest, lunge, lean = 0, 0, 0
	for i = 0, steps do
		local torso = frames[i].world.Torso
		lowest = math.min(lowest, torso.Position.Y)
		lunge = math.max(lunge, -torso.Position.Z)
		lean = math.max(lean, math.deg(math.acos(math.clamp(torso.UpVector.Y, -1, 1))))
	end
	report.torso = { drop = -lowest, lunge = lunge, lean = lean }

	-- a held weapon strikes from its own tip: opts.tips = { ["Right Arm"] = Vector3.new(0, -1, -4) }
	local function tipOf(part, cf)
		local t = opts.tips and opts.tips[part]
		return t and cf * t or R6Rig.tip(part, cf)
	end
	-- sweeps: where each limb's tip crosses the centre line in front, and its fastest frame
	report.sweeps = {}
	for _, part in R6Rig.LIMBS do
		if seq.tracks[part] then
			local fastest, fastAt, speedMax, cross, crossX = 0, 0, 0, nil, math.huge
			for i = 1, steps do
				local a, b = tipOf(part, frames[i - 1].world[part]), tipOf(part, frames[i].world[part])
				local speed = (b - a).Magnitude
				if speed > speedMax then
					speedMax, fastAt = speed, i
				end
				if b.Z < -0.8 and math.abs(b.X) < crossX and ((a.X < 0) ~= (b.X < 0) or math.abs(b.X) < 0.3) then
					crossX, cross = math.abs(b.X), i
				end
			end
			fastest = speedMax * fps
			report.sweeps[part] = { fastest = fastest, fastAt = fastAt, cross = cross }
		end
	end
	-- every limb's strike shape: the tip's travel forward (-Z) in character space
	for _, part in R6Rig.LIMBS do
		if not seq.tracks[part] then
			continue
		end
		local ext = {}
		for i = 0, steps do
			ext[i] = -tipOf(part, frames[i].world[part]).Z
		end
		local peakI = 0
		for i = 0, steps do
			if ext[i] > ext[peakI] + 1e-4 then
				peakI = i
			end
		end
		local lowI = 0
		for i = 0, peakI do
			if ext[i] < ext[lowI] - 1e-4 then
				lowI = i
			end
		end
		local span = ext[peakI] - ext[lowI]
		if span < 0.6 then
			continue -- this limb does not strike forward
		end
		local arrive = peakI
		for i = lowI, peakI do
			if ext[i] >= ext[lowI] + 0.9 * span then
				arrive = i
				break
			end
		end
		local holdEnd = arrive
		while holdEnd < steps and ext[holdEnd + 1] >= ext[peakI] - 0.15 * span do
			holdEnd += 1
		end
		local torso = frames[arrive].world.Torso
		table.insert(report.strikes, {
			limb = part,
			load = lowI, -- frame of the deepest chamber
			hit = arrive, -- frame the tip has covered 90% of its travel
			share = steps > 0 and arrive / steps or 0, -- where the hit sits in the move
			release = arrive - lowI, -- frames from chamber to contact
			hold = holdEnd - arrive, -- frames the tip stays near its extreme
			reach = span, -- studs the tip travels forward
			tipForward = ext[peakI], -- studs in front of the root at the extreme
			gapAtHit = R6Study.gap(part, frames[arrive].transforms[part] or CFrame.identity, opts.joints),
			torsoTwist = math.deg(math.atan2(-torso.LookVector.X, -torso.LookVector.Z)),
			torsoLean = math.deg(math.acos(math.clamp(torso.UpVector.Y, -1, 1))),
			lunge = -torso.Position.Z,
		})
	end
	return report
end

local function vec(v)
	return string.format("(%+.2f, %+.2f, %+.2f)", v.X, v.Y, v.Z)
end

function R6Study.format(r)
	local lines = {
		string.format(
			"%s  %.3fs (%d frames @60)  loop=%s  %s  %d keyframes%s",
			r.name,
			r.length,
			r.frames,
			tostring(r.loop),
			r.priority,
			r.keyframes,
			r.dense and " dense/baked" or ""
		),
	}
	local e = {}
	for s, n in r.easing do
		table.insert(e, s .. "=" .. n)
	end
	table.sort(e)
	table.insert(lines, "  easing: " .. table.concat(e, ", "))
	for _, m in r.markers do
		table.insert(lines, string.format("  marker %s at %.3fs (frame %d)", m.name, m.t, math.floor(m.t * 60 + 0.5)))
	end
	table.insert(lines, string.format("  torso: drops %.2f, lunges %.2f, leans up to %.0f°", r.torso.drop, r.torso.lunge, r.torso.lean))
	table.insert(lines, "  part          rot reach   gap max (frame, dir right/up/fwd-)   gap avg   visible max/avg")
	for _, part in R6Rig.ORDER do
		local p = r.parts[part]
		if part ~= "Torso" then
			table.insert(
				lines,
				string.format(
					"  %-12s %7.0f°    %.2f (f%d, %s)   %.2f      %.2f / %.2f",
					part,
					p.reach,
					p.gap,
					p.gapFrame,
					vec(p.gapDir),
					p.gapAvg,
					p.visible,
					p.visibleAvg
				)
			)
		end
	end
	for _, part in R6Rig.LIMBS do
		local w = r.sweeps and r.sweeps[part]
		if w and w.fastest > 20 then
			table.insert(lines, string.format("  sweep  %-10s fastest %.0f studs/s at f%d, crosses the centre line in front at %s", part, w.fastest, w.fastAt, w.cross and ("f" .. w.cross) or "never"))
		end
	end
	for _, s in r.strikes do
		table.insert(
			lines,
			string.format(
				"  strike %-10s chamber f%d -> hit f%d (%.0f%% in), release %d f, hold %d f, tip travels %.2f to %.2f fwd, gap at hit %s, torso twist %.0f° lean %.0f° lunge %.2f",
				s.limb,
				s.load,
				s.hit,
				s.share * 100,
				s.release,
				s.hold,
				s.reach,
				s.tipForward,
				vec(s.gapAtHit),
				s.torsoTwist,
				s.torsoLean,
				s.lunge
			)
		)
	end
	return table.concat(lines, "\n")
end

-- A joint Transform -> the named angles and pos that rebuild it in R6Clip (exactly: the rotation
-- is split into the same Y-X-Z order R6Rig.rotation composes, with twist left at 0).
-- Every rotation has two Y-X-Z splits, (x, y, z) and (180 - x, y + 180, z + 180), and each angle is
-- only known up to 360. R6Clip interpolates the angles, so the choice matters: an arm overhead read
-- as swing -179 next to a key at +179 would spin a full turn. `prev` (the entry of the frame before)
-- picks the split and the wrap closest to it; without it, the split with the smallest angles.
local function wrapNear(a, ref)
	return a + 360 * math.floor((ref - a) / 360 + 0.5)
end

function R6Study.entry(part, transform, prev)
	local rot, offset = R6Rig.fromTransform(part, transform)
	return R6Study.entryFromRotation(part, rot, offset, prev)
end

-- The same split for a rotation (and offset) already in the parent's space.
function R6Study.entryFromRotation(part, rot, offset, prev)
	offset = offset or Vector3.zero
	local rx, ry, rz = rot:ToEulerAnglesYXZ()
	rx, ry, rz = math.deg(rx), math.deg(ry), math.deg(rz)
	local options = { { rx, ry, rz }, { 180 - rx, ry + 180, rz + 180 } }
	local keys
	local side = 1
	if part == "Torso" then
		keys = { "lean", "twist", "tilt" }
	elseif part == "Head" then
		keys = { "nod", "turn", "tilt" }
	else
		keys = { "raise", "swing", "spread" }
		side = R6Rig.SIDE[part]
	end
	local function toEntry(o)
		local e = {}
		if part == "Torso" or part == "Head" then
			e[keys[1]], e[keys[2]], e[keys[3]] = -o[1], o[2], -o[3]
		else
			e.raise, e.swing, e.spread = o[1], o[2] * side, o[3] * side
		end
		for _, k in keys do
			e[k] = wrapNear(e[k], prev and prev[k] or 0)
		end
		return e
	end
	local best, bestCost
	for _, o in options do
		local e = toEntry(o)
		local cost = 0
		for _, k in keys do
			cost += math.abs(e[k] - (prev and prev[k] or 0))
		end
		if not bestCost or cost < bestCost - 1e-6 then
			best, bestCost = e, cost
		end
	end
	if offset.Magnitude > 0.005 then
		best.pos = { forward = -offset.Z, up = offset.Y, right = offset.X }
	end
	return best
end

-- The key poses of a clip at the given frames (60 fps), as R6Clip pose tables.
-- opts.rootLegs: write the legs the way R6Clip's pelvis reads them (space = "root", the pelvis
-- taking opts.hips = 0.35 of the torso's turn, ground = true), so the same pose comes back: the
-- angle against the pelvis and the slide in root space minus the pelvis's own socket slide.
-- Mocap and many packs key legs against the torso; keyed that way under a different torso, a deep
-- fold or a turn crosses them into an X.
function R6Study.keyPoses(seq, frames, fps, opts)
	fps = fps or 60
	opts = opts or {}
	-- walk every frame (not only the keys) so each angle stays continuous through the clip
	local out, prev, want = {}, {}, {}
	local last = 0
	for _, f in frames do
		want[f] = true
		last = math.max(last, f)
	end
	for f = 0, last do
		local transforms = Sequence.sample(seq, f / fps)
		local pose = {}
		local torsoRot = R6Rig.fromTransform("Torso", transforms.Torso or CFrame.identity)
		local pelvisRot = Sequence.blend(CFrame.identity, torsoRot, opts.hips or 0.35)
		local torsoCF = R6Rig.fk({ Torso = transforms.Torso or CFrame.identity }).Torso
		for _, part in R6Rig.ORDER do
			if seq.tracks[part] then
				local isLeg = part == "Left Leg" or part == "Right Leg"
				if opts.rootLegs and isLeg then
					local legRot, legOff = R6Rig.fromTransform(part, transforms[part] or CFrame.identity)
					-- R6Clip slides the socket to the pelvis by this much; take it back out
					local hipC0 = R6Rig.JOINTS[part].C0.Position
					local pelvisSlide = (CFrame.new(torsoCF.Position) * pelvisRot) * hipC0 - torsoCF * hipC0
					local rootOff = torsoRot * legOff - pelvisSlide
					local e = R6Study.entryFromRotation(part, pelvisRot:Inverse() * torsoRot * legRot, rootOff, prev[part])
					e.space, e.ground = "root", true
					e.hips = opts.hips
					pose[part] = e
				else
					pose[part] = R6Study.entry(part, transforms[part] or CFrame.identity, prev[part])
				end
				prev[part] = pose[part]
			end
		end
		if want[f] then
			table.insert(out, { frame = f, pose = pose })
		end
	end
	return out
end

-- The fewest key frames that rebuild the clip within `tolerance` degrees (a slid part counts 10
-- degrees per stud), interpolating named angles the way R6Clip does. Ramer-Douglas-Peucker over
-- frames. upTo: only fit frames 0..upTo (a symmetric cycle's first half, mirrored by the caller).
function R6Study.fitKeys(seq, tolerance, upTo, fps)
	fps = fps or 60
	tolerance = tolerance or 3
	local R6Clip = require(script.Parent.R6Clip)
	local last = upTo or math.floor(seq.length * fps + 0.5)
	local entries, transforms = {}, {}
	for f = 0, last do
		transforms[f] = Sequence.sample(seq, f / fps)
		entries[f] = {}
		for _, part in R6Rig.ORDER do
			if seq.tracks[part] then
				entries[f][part] = R6Study.entry(part, transforms[f][part] or CFrame.identity, f > 0 and entries[f - 1][part] or nil)
			end
		end
	end
	local keep = { [0] = true, [last] = true }
	local function split(i, j)
		if j - i < 2 then
			return
		end
		local worst, at = 0, nil
		for k = i + 1, j - 1 do
			local u = (k - i) / (j - i)
			for part in entries[k] do
				local guess = R6Rig.pose(part, R6Clip.lerpEntry(entries[i][part], entries[j][part], u))
				local real = transforms[k][part] or CFrame.identity
				local err = Sequence.angleBetween(guess, real) + (guess.Position - real.Position).Magnitude * 10
				if err > worst then
					worst, at = err, k
				end
			end
		end
		if worst > tolerance then
			keep[at] = true
			split(i, at)
			split(at, j)
		end
	end
	split(0, last)
	local frames = {}
	for f in keep do
		table.insert(frames, f)
	end
	table.sort(frames)
	return frames
end

local ALIAS = { ["Right Arm"] = "RightArm", ["Left Arm"] = "LeftArm", ["Right Leg"] = "RightLeg", ["Left Leg"] = "LeftLeg" }

-- Key poses as Lua source to paste into a clip.
function R6Study.formatKeys(keys)
	local lines = {}
	local function num(x)
		return string.format("%g", round(x, 1))
	end
	for _, k in keys do
		local parts = {}
		for _, part in R6Rig.ORDER do
			local e = k.pose[part]
			if e then
				local fields = {}
				for _, name in { "lean", "twist", "tilt", "nod", "turn", "raise", "spread", "swing" } do
					if e[name] and math.abs(e[name]) >= 0.05 then
						table.insert(fields, name .. " = " .. num(e[name]))
					end
				end
				if e.space then
					table.insert(fields, string.format("space = %q", e.space))
				end
				if e.ground then
					table.insert(fields, "ground = true")
				end
				if e.hips then
					table.insert(fields, "hips = " .. string.format("%g", e.hips))
				end
				if e.pos then
					local p = {}
					for _, axis in { "forward", "up", "right" } do
						if math.abs(e.pos[axis]) >= 0.005 then
							table.insert(p, axis .. " = " .. string.format("%g", round(e.pos[axis], 2)))
						end
					end
					if #p > 0 then
						table.insert(fields, "pos = { " .. table.concat(p, ", ") .. " }")
					end
				end
				table.insert(parts, string.format("\t\t%s = { %s },", ALIAS[part] or part, table.concat(fields, ", ")))
			end
		end
		table.insert(lines, string.format("\t[%d] = {\n%s\n\t},", k.frame, table.concat(parts, "\n")))
	end
	return "{\n" .. table.concat(lines, "\n") .. "\n}"
end

R6Study.round = round

return R6Study
