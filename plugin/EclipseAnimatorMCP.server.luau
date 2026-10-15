-- Eclipse Animator MCP bridge: long-polls the local MCP server and runs its commands in Studio.
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	return
end

local URL = "http://127.0.0.1:" .. (plugin:GetSetting("EclipseMCPPort") or 44755)

local function round(n)
	return math.round(n * 1e4) / 1e4
end

local function isRig(m)
	return m:IsA("Model") and (m:FindFirstChildWhichIsA("Humanoid") or m:FindFirstChildWhichIsA("AnimationController")) ~= nil
end

local function findRig(name)
	for _, d in workspace:GetDescendants() do
		if isRig(d) and (d:GetFullName() == name or d.Name == name) then
			return d
		end
	end
	error("rig not found: " .. tostring(name), 0)
end

-- Part1 name -> Part0 name, i.e. the Pose hierarchy a KeyframeSequence must mirror.
-- shortcut: Motor6D rigs only (no Bone rigs), add Bones when a skinned rig needs it.
local function joints(rig)
	local parents = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 and not d:FindFirstAncestor("AnimSaves") then
			parents[d.Part1.Name] = d.Part0.Name
		end
	end
	return parents
end

local function animSaves(rig)
	local folder = rig:FindFirstChild("AnimSaves")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "AnimSaves"
		folder.Parent = rig
	end
	return folder
end

local handlers = {}

function handlers.list_rigs()
	local rigs = {}
	for _, d in workspace:GetDescendants() do
		if isRig(d) then
			local parts, anims = {}, {}
			for part in joints(d) do
				table.insert(parts, part)
			end
			table.sort(parts)
			local saves = d:FindFirstChild("AnimSaves")
			for _, s in saves and saves:GetChildren() or {} do
				if s:IsA("KeyframeSequence") then
					table.insert(anims, s.Name)
				end
			end
			table.insert(rigs, { rig = d:GetFullName(), parts = parts, animations = anims })
		end
	end
	return rigs
end

function handlers.get_animation(args)
	local saves = findRig(args.rig):FindFirstChild("AnimSaves")
	local seq = saves and saves:FindFirstChild(args.name)
	if not (seq and seq:IsA("KeyframeSequence")) then
		error("no KeyframeSequence named " .. tostring(args.name) .. " in AnimSaves", 0)
	end
	local keyframes = {}
	for _, kf in seq:GetKeyframes() do
		local poses = {}
		local function walk(list)
			for _, p in list do
				if p.Weight > 0 then
					local rx, ry, rz = p.CFrame:ToEulerAnglesXYZ()
					local pos = p.CFrame.Position
					poses[p.Name] = {
						pos = { round(pos.X), round(pos.Y), round(pos.Z) },
						rot = { round(math.deg(rx)), round(math.deg(ry)), round(math.deg(rz)) },
						easing = p.EasingStyle.Name,
						direction = p.EasingDirection.Name,
					}
				end
				walk(p:GetSubPoses())
			end
		end
		walk(kf:GetPoses())
		table.insert(keyframes, { time = kf.Time, poses = poses })
	end
	table.sort(keyframes, function(a, b) return a.time < b.time end)
	return { loop = seq.Loop, priority = seq.Priority.Name, keyframes = keyframes }
end

function handlers.save_animation(args)
	local rig = findRig(args.rig)
	local parents = joints(rig)
	local seq = Instance.new("KeyframeSequence")
	seq.Name = args.name
	seq.Loop = args.loop == true
	seq.Priority = Enum.AnimationPriority[args.priority or "Action"]
	for _, k in args.keyframes do
		local kf = Instance.new("Keyframe")
		kf.Time = k.time
		local made = {}
		local function poseFor(part)
			if not made[part] then
				local pose = Instance.new("Pose")
				pose.Name = part
				pose.Weight = 0 -- structural parent only, unless keyed below
				pose.Parent = parents[part] and poseFor(parents[part]) or kf
				made[part] = pose
			end
			return made[part]
		end
		for part, p in k.poses do
			if not parents[part] then
				error("no Motor6D drives part " .. part .. " in " .. rig:GetFullName(), 0)
			end
			local pos, rot = p.pos or { 0, 0, 0 }, p.rot or { 0, 0, 0 }
			local pose = poseFor(part)
			pose.Weight = 1
			pose.CFrame = CFrame.new(pos[1], pos[2], pos[3])
				* CFrame.fromEulerAnglesXYZ(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
			pose.EasingStyle = Enum.PoseEasingStyle[p.easing or "Linear"]
			pose.EasingDirection = Enum.PoseEasingDirection[p.direction or "In"]
		end
		kf.Parent = seq
	end

	local recording = ChangeHistoryService:TryBeginRecording("Eclipse MCP: save " .. args.name)
	local saves = animSaves(rig)
	local old = saves:FindFirstChild(args.name)
	if old then
		old:Destroy()
	end
	seq.Parent = saves
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	return { saved = seq:GetFullName(), keyframes = #args.keyframes }
end

local active = true
plugin.Unloading:Connect(function()
	active = false
end)

task.spawn(function()
	while active do
		local ok, res = pcall(HttpService.RequestAsync, HttpService, { Url = URL .. "/poll", Method = "GET" })
		if ok and res.StatusCode == 200 then
			local cmd = HttpService:JSONDecode(res.Body)
			local handler = handlers[cmd.tool]
			local good, out = pcall(function()
				assert(handler, "unknown tool " .. tostring(cmd.tool))
				return handler(cmd.args or {})
			end)
			pcall(HttpService.RequestAsync, HttpService, {
				Url = URL .. "/result",
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = HttpService:JSONEncode({ id = cmd.id, ok = good, result = good and out or nil, error = not good and tostring(out) or nil }),
			})
		elseif not ok or res.StatusCode ~= 204 then
			task.wait(2) -- server not running yet
		end
	end
end)
