-- Runs the plugin's R6 modules offline in Lune: lune run test/r6.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local dir = "plugin/R6/"
local loaded = {}
local parent = setmetatable({}, { __index = function(_, name) return { __module = name } end })
local function load(name)
	if loaded[name] then
		return loaded[name]
	end
	local env = setmetatable({
		script = { Name = name, Parent = parent },
		require = function(t) return load(t.__module) end,
		CFrame = roblox.CFrame, Vector3 = roblox.Vector3, Instance = roblox.Instance, Enum = roblox.Enum,
		Color3 = roblox.Color3, Vector2 = roblox.Vector2, NumberSequence = roblox.NumberSequence, typeof = typeof,
	}, { __index = getfenv and getfenv() or _G })
	loaded[name] = luau.load(fs.readFile(dir .. name .. ".luau"), { debugName = name, environment = env })()
	return loaded[name]
end

local Bridge = load("R6Bridge")
local failed = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	print((ok and "ok   " or "FAIL ") .. name .. (ok and "" or ": " .. tostring(err)))
	if not ok then failed += 1 end
end
local function json(v) return serde.encode("json", v) end

test("build a clip from named angles, audited and JSON-safe", function()
	local ks, audit = Bridge.build({
		name = "Wave",
		keys = {
			{ frame = 0, pose = { RightArm = { raise = 0 } } },
			{ frame = 20, pose = { RightArm = { raise = 160, spread = 20, pos = { up = 0.2 } }, Head = { turn = 10 } }, ease = { settle = 0.1 } },
			{ frame = 40, pose = { RightArm = { raise = 140, spread = 30 } } },
			{ frame = 60, pose = { RightArm = { raise = 0 }, Head = { turn = 0 } } },
		},
		markers = { { frame = 20, name = "Wave" } },
	})
	assert(ks.ClassName == "KeyframeSequence" and #ks:GetChildren() > 2, "keyframes")
	assert(type(audit.ok) == "boolean" and type(audit.notes) == "table", "audit shape")
	assert(audit.seconds > 1, "medium weight stretches a one-shot: " .. audit.seconds)
	json(audit)
end)

test("weight none keeps the keyed timing", function()
	local _, audit = Bridge.build({ name = "T", weight = "none", keys = { { frame = 0, pose = { Head = { nod = 0 } } }, { frame = 30, pose = { Head = { nod = 20 } } } } })
	assert(audit.seconds == 0.5, tostring(audit.seconds))
end)

test("a non-R6 part is refused", function()
	local ok, err = pcall(Bridge.build, { name = "X", keys = { { frame = 0, pose = { UpperTorso = { lean = 5 } } } } })
	assert(not ok and string.find(tostring(err), "Not an R6 part"), tostring(err))
end)

test("every kit clip builds and passes the motion audit", function()
	-- The newer body-clearance gate (R6Quality) flags thighs in the torso on most upstream kit
	-- clips; the kit's own motion audit is what they were built against. Bridge.kit reports both.
	local R6Clip = load("R6Clip")
	for _, name in Bridge.kitNames() do
		local ks, audit = Bridge.kit(name)
		assert(ks.Name == name and type(audit.notes) == "table", name)
		local c = Bridge.KIT[name][name]()
		local motion = R6Clip.audit(c:bake(), c.meta)
		assert(motion.ok, name .. ": " .. table.concat(motion.notes, "; "))
	end
end)

test("study measures a clip and fits its keys", function()
	local ks = Bridge.kit("Jab")
	local r = Bridge.study(ks, { fit = 4 })
	assert(#r.text > 50 and #r.keys >= 3, "study output")
	json(r)
end)

test("smooth rebuilds a clip on the curve, keeps length and markers", function()
	local ks = Bridge.kit("Cross")
	local before = Bridge.study(ks, {})
	local out, audit = Bridge.smooth(ks, { name = "Cross Smooth" })
	assert(out.Name == "Cross Smooth", out.Name)
	assert(math.abs(audit.seconds - before.length) < 0.02, audit.seconds .. " vs " .. before.length)
	assert(#audit.markers == #before.markers, "markers kept")
end)

if failed > 0 then
	error(failed .. " R6 test(s) failed")
end
