-- Sequence: read any KeyframeSequence (R6, R15, custom), evaluate it at any time the way Roblox
-- does, and measure it. Measuring good animations is how the numbers in this skill were learned:
-- key spacing, easing, how far each joint travels, where it holds and where it snaps.

local Ease = require(script.Parent.Ease)

local Sequence = {}

local function enumName(v)
	return (tostring(v):gsub("^Enum%.[%w]+%.", ""))
end

-- KeyframeSequence -> { name, loop, priority, length, tracks = part -> {{t, cf, ease}}, markers }
-- A Pose with Weight 0 is a placeholder holding the hierarchy, not a key.
function Sequence.read(ks)
	local tracks, markers, length = {}, {}, 0
	for _, kf in ks:GetChildren() do
		if kf.ClassName ~= "Keyframe" then
			continue
		end
		length = math.max(length, kf.Time)
		for _, d in kf:GetDescendants() do
			if d.ClassName == "Pose" and d.Weight > 0 then
				tracks[d.Name] = tracks[d.Name] or {}
				table.insert(tracks[d.Name], {
					t = kf.Time,
					cf = d.CFrame,
					style = enumName(d.EasingStyle),
					dir = enumName(d.EasingDirection),
					ease = Ease.pose(d.EasingStyle, d.EasingDirection),
				})
			elseif d.ClassName == "KeyframeMarker" then
				table.insert(markers, { t = kf.Time, name = d.Name, value = d.Value })
			end
		end
	end
	for _, track in tracks do
		table.sort(track, function(a, b)
			return a.t < b.t
		end)
	end
	table.sort(markers, function(a, b)
		return a.t < b.t
	end)
	return {
		name = ks.Name,
		loop = ks.Loop,
		priority = enumName(ks.Priority),
		length = length,
		tracks = tracks,
		markers = markers,
	}
end

-- ToAxisAngle can answer with an angle past 180 degrees; fold it so turns take the short way.
-- In Roblox (not in Lune) a near-identity rotation comes back as a ZERO axis with a tiny nonzero
-- angle, and CFrame.fromAxisAngle on a zero axis is NaN even at angle 0: treat it as no turn.
function Sequence.axisAngle(rotation)
	local axis, angle = rotation:ToAxisAngle()
	if angle ~= angle or axis.Magnitude < 1e-6 or axis.Magnitude ~= axis.Magnitude then
		return Vector3.yAxis, 0
	end
	angle = angle % (2 * math.pi)
	if angle > math.pi then
		angle -= 2 * math.pi
	end
	return axis, angle
end

-- Interpolate two CFrames, extrapolating past 0..1 for overshoot curves.
function Sequence.blend(a, b, alpha)
	if alpha == 0 then
		return a
	elseif alpha == 1 then
		return b
	end
	local axis, angle = Sequence.axisAngle(a.Rotation:Inverse() * b.Rotation)
	local rot = a.Rotation
	if angle == angle and math.abs(angle) > 1e-9 then
		rot = a.Rotation * CFrame.fromAxisAngle(axis, angle * alpha)
	end
	return CFrame.new(a.Position + (b.Position - a.Position) * alpha) * rot
end

function Sequence.evaluate(track, t)
	if not track or #track == 0 then
		return CFrame.identity
	end
	if t <= track[1].t then
		return track[1].cf
	end
	local last = track[#track]
	if t >= last.t then
		return last.cf
	end
	local lo, hi = 1, #track
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if track[mid].t <= t then
			lo = mid
		else
			hi = mid
		end
	end
	local a, b = track[lo], track[hi]
	local span = b.t - a.t
	local alpha = span > 0 and a.ease((t - a.t) / span) or 1
	return Sequence.blend(a.cf, b.cf, alpha)
end

-- part -> Transform at time t
function Sequence.sample(seq, t)
	local out = {}
	for part, track in seq.tracks do
		out[part] = Sequence.evaluate(track, t)
	end
	return out
end

local function angleBetween(a, b)
	local _, angle = Sequence.axisAngle(a.Rotation:Inverse() * b.Rotation)
	return math.deg(math.abs(angle))
end
Sequence.angleBetween = angleBetween

-- What makes this clip tick: spacing, easing, travel, speed peaks and holds per part.
-- fps is the measuring rate (60 = one Roblox frame).
function Sequence.analyze(seq, fps)
	fps = fps or 60
	local keyTimes, styles = {}, {}
	for _, track in seq.tracks do
		for _, k in track do
			keyTimes[k.t] = true
			local s = k.style .. "/" .. k.dir
			styles[s] = (styles[s] or 0) + 1
		end
	end
	local keyCount = 0
	for _ in keyTimes do
		keyCount += 1
	end
	local report = {
		name = seq.name,
		loop = seq.loop,
		priority = seq.priority,
		length = seq.length,
		keyframes = keyCount,
		dense = keyCount >= seq.length * 30,
		easing = styles,
		markers = seq.markers,
		parts = {},
	}
	local steps = math.max(1, math.floor(seq.length * fps + 0.5))
	for part, track in seq.tracks do
		local prev = Sequence.evaluate(track, 0)
		local rest = prev
		local travel, peak, peakAt, holdRun, holds, extreme = 0, 0, 0, 0, 0, 0
		for i = 1, steps do
			local t = i / fps
			local cf = Sequence.evaluate(track, t)
			local step = angleBetween(prev, cf)
			travel += step
			if step > peak then
				peak, peakAt = step, t
			end
			if step < 0.5 then
				holdRun += 1
			else
				if holdRun >= 4 then
					holds += 1
				end
				holdRun = 0
			end
			extreme = math.max(extreme, angleBetween(rest, cf))
			prev = cf
		end
		if holdRun >= 4 then
			holds += 1
		end
		report.parts[part] = {
			keys = #track,
			travel = travel, -- total degrees moved
			reach = extreme, -- furthest from its first pose, degrees
			peakSpeed = peak * fps, -- degrees per second at the fastest frame
			peakAt = peakAt,
			holds = holds, -- stretches of 4+ frames moving under 0.5 degrees a frame
		}
	end
	return report
end

function Sequence.format(report)
	local lines = {
		string.format(
			"%s  %.3fs  loop=%s  %s  %d keyframes%s",
			report.name,
			report.length,
			tostring(report.loop),
			report.priority,
			report.keyframes,
			report.dense and " (dense/baked)" or ""
		),
	}
	local e = {}
	for s, n in report.easing do
		table.insert(e, s .. "=" .. n)
	end
	table.sort(e)
	table.insert(lines, "  easing: " .. table.concat(e, ", "))
	for _, m in report.markers do
		table.insert(lines, string.format("  marker %s at %.3fs", m.name, m.t))
	end
	local names = {}
	for part in report.parts do
		table.insert(names, part)
	end
	table.sort(names)
	for _, part in names do
		local p = report.parts[part]
		table.insert(
			lines,
			string.format(
				"  %-14s reach %5.1f°  travel %6.1f°  peak %6.0f°/s at %.3fs  holds %d",
				part,
				p.reach,
				p.travel,
				p.peakSpeed,
				p.peakAt,
				p.holds
			)
		)
	end
	return table.concat(lines, "\n")
end

return Sequence
