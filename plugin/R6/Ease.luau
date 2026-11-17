-- Ease: timing curves. Roblox poses only know Linear, Constant, Elastic, Cubic, Bounce and CubicV2;
-- everything else here (back/overshoot, settle, bezier, expo snaps) is baked into dense keys by
-- R6Clip, the way Moon Animator and Eclipse Animator export their curves.
--
-- Ease.get(spec) -> function(t) for t in 0..1 (may leave 0..1 for overshoot curves).
-- spec: "linear" | "constant" | "<style><In|Out|InOut>" (sine quad cubic quart quint expo circ back
--       elastic bounce) | "snap" | "settle" | "heavyIn" | "heavyOut" | "heavy" | { bezier = {x1, y1, x2, y2} }
--       | { back = overshoot, dir = "out" } | { settle = 0.15 } (overshoot share) | function(t)

local Ease = {}

local pi = math.pi

local IN = {
	linear = function(t)
		return t
	end,
	sine = function(t)
		return 1 - math.cos(t * pi / 2)
	end,
	quad = function(t)
		return t * t
	end,
	cubic = function(t)
		return t * t * t
	end,
	quart = function(t)
		return t ^ 4
	end,
	quint = function(t)
		return t ^ 5
	end,
	expo = function(t)
		return t <= 0 and 0 or 2 ^ (10 * (t - 1))
	end,
	circ = function(t)
		return 1 - math.sqrt(math.max(0, 1 - t * t))
	end,
}

local function bounceOut(t)
	local n, d = 7.5625, 2.75
	if t < 1 / d then
		return n * t * t
	elseif t < 2 / d then
		t -= 1.5 / d
		return n * t * t + 0.75
	elseif t < 2.5 / d then
		t -= 2.25 / d
		return n * t * t + 0.9375
	end
	t -= 2.625 / d
	return n * t * t + 0.984375
end
IN.bounce = function(t)
	return 1 - bounceOut(1 - t)
end
IN.elastic = function(t)
	if t <= 0 or t >= 1 then
		return t <= 0 and 0 or 1
	end
	return -(2 ^ (10 * t - 10)) * math.sin((t * 10 - 10.75) * (2 * pi / 3))
end

local function backIn(s)
	return function(t)
		return t * t * ((s + 1) * t - s)
	end
end

local function out(f)
	return function(t)
		return 1 - f(1 - t)
	end
end

local function inOut(f)
	return function(t)
		if t < 0.5 then
			return f(2 * t) / 2
		end
		return 1 - f(2 * (1 - t)) / 2
	end
end

local function directed(f, dir)
	dir = string.lower(dir or "in")
	if dir == "out" then
		return out(f)
	elseif dir == "inout" then
		return inOut(f)
	end
	return f
end

-- CSS-style cubic bezier through (0,0) (x1,y1) (x2,y2) (1,1). Eclipse's default is 0.42,0,0.58,1.
function Ease.bezier(x1, y1, x2, y2)
	local function axis(a, b, u)
		local v = 1 - u
		return 3 * v * v * u * a + 3 * v * u * u * b + u * u * u
	end
	return function(t)
		if t <= 0 or t >= 1 then
			return t <= 0 and 0 or 1
		end
		local lo, hi = 0, 1
		for _ = 1, 30 do
			local mid = (lo + hi) / 2
			if axis(x1, x2, mid) < t then
				lo = mid
			else
				hi = mid
			end
		end
		return axis(y1, y2, (lo + hi) / 2)
	end
end

-- Arrive, pass the target by `overshoot` (share of the move), swing back and rest exactly at 1.
-- One visible bounce, peaking 40% into the segment. The weight of a fist that stops on a jaw.
function Ease.settle(overshoot)
	overshoot = math.clamp(overshoot or 0.12, 0.001, 0.6)
	local w = 2 * pi * 1.25
	local d = -math.log(overshoot) / 0.4
	return function(t)
		if t >= 1 then
			return 1
		end
		return 1 - math.exp(-d * t) * math.cos(w * t)
	end
end

-- For long recoveries: ease in and out over the whole distance, drift a little past the pose in
-- the last half and come back to rest. `overshoot` is the size of that drift (0.1 = about 4% past).
-- Ease.settle arrives at 20% of the segment, fine for short hits, a pop over a long move.
function Ease.recover(overshoot)
	overshoot = overshoot or 0.08
	local base = inOut(IN.cubic)
	return function(t)
		if t >= 1 then
			return 1
		end
		return base(t) + overshoot * math.sin(pi * math.max(0, (t - 0.5) * 2))
	end
end

local NAMED = {
	linear = IN.linear,
	constant = function(t)
		return t >= 1 and 1 or 0
	end,
	-- the strike curve: leaves the chamber at full speed and brakes into the pose. Give it 3-4
	-- frames at 60 fps; over 1-2 frames any curve is a pop.
	snap = out(IN.cubic),
	settle = Ease.settle(0.12),
	recover = Ease.recover(0.08),
	smooth = Ease.bezier(0.42, 0, 0.58, 1),
	-- weight curves: uneven speed is what reads as mass
	-- heavyIn (names are matched lowercase): slow to get going, then a hard surge (a heavy limb or weapon swung into a strike)
	heavyin = Ease.bezier(0.65, 0, 0.85, 0.45),
	-- heavyOut: arrives fast, then a long slow drift into the pose (a body coming to rest)
	heavyout = Ease.bezier(0.1, 0.6, 0.25, 1),
	-- heavy: inertia at the start, a firm brake at the end (a big body move between poses)
	heavy = Ease.bezier(0.65, 0, 0.25, 1),
}

function Ease.get(spec)
	if spec == nil then
		return IN.linear
	end
	local kind = typeof and typeof(spec) or type(spec)
	if kind == "function" then
		return spec
	end
	if kind == "table" then
		if spec.bezier then
			return Ease.bezier(table.unpack(spec.bezier))
		elseif spec.back then
			return directed(backIn(spec.back), spec.dir or "out")
		elseif spec.recover then
			return Ease.recover(spec.recover)
		elseif spec.settle then
			return Ease.settle(spec.settle)
		elseif spec.style then
			return Ease.get(spec.style .. (spec.dir or ""))
		end
		error("Unknown ease spec", 2)
	end
	local key = string.lower(spec)
	if NAMED[key] then
		return NAMED[key]
	end
	for _, dir in { "inout", "out", "in" } do
		if #key > #dir and string.sub(key, -#dir) == dir then
			local style = string.sub(key, 1, #key - #dir)
			if style == "back" then
				return directed(backIn(1.70158), dir)
			end
			if IN[style] then
				return directed(IN[style], dir)
			end
		end
	end
	error("Unknown ease: " .. tostring(spec), 2)
end

-- Roblox's own pose easing, for reading KeyframeSequences. The easing on a pose shapes the segment
-- that leaves it. CubicV2 matches TweenService; legacy Cubic runs with In and Out swapped (that is
-- why CubicV2 exists). Elastic and Bounce follow the same swapped legacy convention here; sample
-- through the Animator in Studio when exactness matters.
function Ease.pose(style, direction)
	style = tostring(style):gsub("^Enum%.PoseEasingStyle%.", "")
	direction = tostring(direction):gsub("^Enum%.PoseEasingDirection%.", "")
	if style == "Linear" then
		return IN.linear
	elseif style == "Constant" then
		return NAMED.constant
	elseif style == "CubicV2" then
		return directed(IN.cubic, direction)
	end
	local swapped = direction == "In" and "Out" or direction == "Out" and "In" or direction
	if style == "Cubic" then
		return directed(IN.cubic, swapped)
	elseif style == "Elastic" then
		return directed(IN.elastic, swapped)
	elseif style == "Bounce" then
		return directed(IN.bounce, swapped)
	end
	return IN.linear
end

-- Which specs Roblox can play natively (for sparse, editable exports). Others must be baked.
function Ease.native(spec)
	if spec == nil or spec == "linear" then
		return "Linear", "In"
	elseif spec == "constant" then
		return "Constant", "In"
	end
	if type(spec) ~= "string" then
		return nil
	end
	local key = string.lower(spec)
	local map = { cubicin = "In", cubicout = "Out", cubicinout = "InOut" }
	if map[key] then
		return "CubicV2", map[key]
	end
	return nil
end

return Ease
