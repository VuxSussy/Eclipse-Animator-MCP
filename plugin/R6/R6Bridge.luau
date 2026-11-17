-- R6Bridge: the Eclipse Animator MCP's door into the R6 kit (R6Clip, R6Quality, R6Study...).
-- Takes plain JSON-shaped tables from the MCP server and returns plain tables back.
-- Not part of the upstream kit: scripts/sync-r6.js leaves this file alone.
local R6Clip = require(script.Parent.R6Clip)
local R6Quality = require(script.Parent.R6Quality)
local R6Study = require(script.Parent.R6Study)
local R6Rig = require(script.Parent.R6Rig)
local Sequence = require(script.Parent.Sequence)
local CombatMoves = require(script.Parent.CombatMoves)
local Locomotion = require(script.Parent.Locomotion)

local Bridge = {}

-- what the MCP picks when the AI does not say: the skill's recommended feel
Bridge.DEFAULTS = { curve = "auto", tension = 0.45, weight = "medium" }

local function vec(v)
	if type(v) == "table" and #v == 3 then
		return Vector3.new(v[1], v[2], v[3])
	end
	return v
end

-- JSON-safe copy: Vector3 -> {x,y,z}, CFrame -> position, numbers rounded, functions dropped
local function plain(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "number" then
		return v == v and math.round(v * 1000) / 1000 or nil
	elseif t == "string" or t == "boolean" then
		return v
	elseif t == "Vector3" then
		return { plain(v.X), plain(v.Y), plain(v.Z) }
	elseif t == "CFrame" then
		return plain(v.Position)
	elseif t == "table" and depth < 6 then
		local out = {}
		for k, x in v do
			out[typeof(k) == "number" and k or tostring(k)] = plain(x, depth + 1)
		end
		return out
	end
	return nil
end
Bridge.plain = plain

local function meta(m)
	m = table.clone(m or {})
	if m.tip then
		m.tip = vec(m.tip)
	end
	return m
end

local function option(spec, key)
	local v = spec[key]
	if v == nil then
		return Bridge.DEFAULTS[key]
	end
	if v == "none" or v == false then
		return nil
	end
	return v
end

-- spec: { name, loop?, priority?, fps?, curve?, tension?, weight?, budget?, meta?,
--         keys = { { frame, pose, ease? } }, markers? = { { frame, name, value? } }, lead? = { part = frames } }
function Bridge.clip(spec)
	assert(type(spec.keys) == "table" and #spec.keys > 0, "keys: at least one key pose")
	local c = R6Clip.new(spec.name, {
		fps = spec.fps,
		loop = spec.loop,
		priority = spec.priority,
		curve = option(spec, "curve"),
		tension = option(spec, "tension") or 0,
		weight = option(spec, "weight"),
		budget = spec.budget,
		meta = meta(spec.meta),
	})
	for _, k in spec.keys do
		c:key(k.frame, k.pose or {}, k.ease)
	end
	for _, m in spec.markers or {} do
		c:marker(m.frame, m.name, m.value)
	end
	for part, frames in spec.lead or {} do
		c:lead(part, frames)
	end
	return c
end

local function summary(baked, audit)
	local m = audit.metrics or {}
	return {
		ok = audit.ok,
		notes = audit.notes,
		seconds = plain(baked.frames[#baked.frames].time),
		markers = plain(baked.markers),
		worstDegPerFrame = plain(m.worstDegPerFrame),
		slides = plain(m.gap),
	}
end

-- -> KeyframeSequence, audit summary
function Bridge.build(spec, bodySizes)
	local c = Bridge.clip(spec)
	local baked = c:bake({ step = spec.step })
	local audit = R6Quality.audit(baked, c.meta, bodySizes)
	return R6Clip.toKeyframeSequence(baked), summary(baked, audit)
end

-- A saved KeyframeSequence -> measurements, and optionally its key poses as R6Clip pose tables.
-- opts: { keys = { frames } | nil, fit = tolerance | nil, tip = { part, x, y, z }? }
function Bridge.study(ks, opts)
	opts = opts or {}
	local seq = Sequence.read(ks)
	local mopts = {}
	if opts.tip then
		mopts.tips = { [opts.tip[1]] = Vector3.new(opts.tip[2], opts.tip[3], opts.tip[4]) }
	end
	local report = R6Study.measure(seq, mopts)
	local out = { text = R6Study.format(report), length = plain(seq.length), markers = plain(seq.markers) }
	local frames = opts.keys
	if not frames and opts.fit then
		frames = R6Study.fitKeys(seq, opts.fit)
	end
	if frames then
		out.keys = plain(R6Study.keyPoses(seq, frames, 60, { rootLegs = opts.rootLegs }))
	end
	return out
end

-- Rebuild an existing R6 animation on the kit's curve: fit the fewest keys that reproduce it,
-- then play them through curve = "auto" with tension (and weight when asked). Markers are kept.
-- opts: { name, tolerance?, tension?, weight?, keepEasing? }
function Bridge.smooth(ks, opts)
	local seq = Sequence.read(ks)
	local frames = R6Study.fitKeys(seq, opts.tolerance or 3)
	local keys = {}
	for _, k in R6Study.keyPoses(seq, frames, 60) do
		table.insert(keys, { frame = k.frame, pose = k.pose })
	end
	local markers = {}
	for _, m in seq.markers do
		table.insert(markers, { frame = math.round(m.t * 60), name = m.name, value = m.value })
	end
	return Bridge.build({
		name = opts.name,
		loop = seq.loop,
		priority = seq.priority,
		curve = "auto",
		tension = opts.tension,
		weight = opts.weight or "none", -- keep the original timing unless asked
		keys = keys,
		markers = markers,
		meta = opts.meta,
	})
end

Bridge.KIT = {}
for _, n in CombatMoves.LIST do
	Bridge.KIT[n] = CombatMoves
end
for _, n in Locomotion.LIST do
	Bridge.KIT[n] = Locomotion
end

function Bridge.kitNames()
	local names = table.clone(CombatMoves.LIST)
	table.move(Locomotion.LIST, 1, #Locomotion.LIST, #names + 1, names)
	return names
end

-- A ready clip from the kit, by name -> KeyframeSequence, audit summary
function Bridge.kit(name)
	local from = Bridge.KIT[name]
	if not from then
		error("no kit animation named " .. tostring(name) .. ". Kit: " .. table.concat(Bridge.kitNames(), ", "), 0)
	end
	local c = from[name]()
	local baked = c:bake()
	local audit = R6Quality.audit(baked, c.meta)
	return R6Clip.toKeyframeSequence(baked), summary(baked, audit)
end

-- Is this model a six-part R6 body the kit can drive?
function Bridge.isR6(model)
	for part, j in R6Rig.JOINTS do
		local owner = model:FindFirstChild(j.part0)
		local motor = owner and owner:FindFirstChild(j.motor)
		if not (motor and motor:IsA("Motor6D") and model:FindFirstChild(part)) then
			return false
		end
	end
	return true
end

return Bridge
