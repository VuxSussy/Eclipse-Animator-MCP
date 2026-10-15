-- Eclipse Animator MCP bridge: long-polls the local MCP server and runs its commands in Studio.
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local AssetService = game:GetService("AssetService")
local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

if RunService:IsRunning() then
	return
end

local URL = "http://127.0.0.1:" .. (plugin:GetSetting("EclipseMCPPort") or 44755)

-- status window, so you can see the AI is connected and what it did
local widget = plugin:CreateDockWidgetPluginGuiAsync(
	"EclipseAnimatorMCP",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 320, 220, 260, 140)
)
widget.Title = "Eclipse Animator MCP"
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundColor3 = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
label.TextColor3 = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.MainText)
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.TextWrapped = true
label.Font = Enum.Font.Gotham
label.TextSize = 14
label.Parent = widget
local button = plugin:CreateToolbar("Eclipse Animator MCP"):CreateButton("AI Status", "Show the Eclipse Animator MCP status window", "")
button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

local connected, log = false, {}
local function render()
	label.Text = (connected and "● Connected to the AI app\n" or "○ Waiting for the AI app (open Claude)...\n")
		.. "\n"
		.. table.concat(log, "\n")
end
local function note(line)
	table.insert(log, 1, os.date("%H:%M ") .. line)
	log[7] = nil
	render()
end
render()

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
	error("rig not found: " .. tostring(name) .. ". Call list_rigs to see the rigs in Workspace.", 0)
end

-- root part and its joints ordered parents-first
-- A joint is a Motor6D or, on rigs from Roblox's avatar joint upgrade, an AnimationConstraint.
-- Both pose Part1 as Part0 * C0 * Transform * C1:Inverse().
-- shortcut: no Bone rigs, add Bones when a skinned rig needs it.
local function asJoint(d)
	if d:IsA("Motor6D") and d.Part0 and d.Part1 then
		return { inst = d, Name = d.Name, Part0 = d.Part0, Part1 = d.Part1, C0 = d.C0, C1 = d.C1 }
	end
	local a0, a1 = d:IsA("AnimationConstraint") and d.Attachment0, d:IsA("AnimationConstraint") and d.Attachment1
	if a0 and a1 and a0.Parent:IsA("BasePart") and a1.Parent:IsA("BasePart") then
		return { inst = d, Name = d.Name, Part0 = a0.Parent, Part1 = a1.Parent, C0 = a0.CFrame, C1 = a1.CFrame }
	end
end

local function rigJoints(rig)
	local children, isChild = {}, {}
	for _, d in rig:GetDescendants() do
		local j = not d:FindFirstAncestor("AnimSaves") and asJoint(d)
		if j then
			children[j.Part0] = children[j.Part0] or {}
			table.insert(children[j.Part0], j)
			isChild[j.Part1] = true
		end
	end
	local root = rig:FindFirstChild("HumanoidRootPart")
	if not (root and children[root]) then
		for part in children do
			if not isChild[part] then
				root = part
			end
		end
	end
	local order, queue, seen = {}, { root }, {}
	while #queue > 0 do
		local part = table.remove(queue, 1)
		for _, m in children[part] or {} do
			if not seen[m.Part1] then
				seen[m.Part1] = true
				table.insert(order, m)
				table.insert(queue, m.Part1)
			end
		end
	end
	return root, order
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

local function getSequence(rig, name)
	local saves = rig:FindFirstChild("AnimSaves")
	local seq = saves and saves:FindFirstChild(name)
	if not (seq and seq:IsA("KeyframeSequence")) then
		error("no animation named " .. tostring(name) .. " on " .. rig.Name .. ". Call list_rigs to see its animations.", 0)
	end
	return seq
end

local function saveSequence(rig, seq)
	local recording = ChangeHistoryService:TryBeginRecording("Eclipse MCP: save " .. seq.Name)
	local saves = animSaves(rig)
	local old = saves:FindFirstChild(seq.Name)
	if old then
		old:Destroy()
	end
	seq.Parent = saves
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	note("Saved " .. seq.Name .. " on " .. rig.Name)
	return { saved = seq:GetFullName(), keyframes = #seq:GetKeyframes() }
end

-- frames: { { time, poses = { [partName] = { cf, easing?, direction? } } } } -> KeyframeSequence
local function buildSequence(rig, name, loop, priority, frames)
	local parents = {}
	for _, m in select(2, rigJoints(rig)) do
		parents[m.Part1.Name] = m.Part0.Name
	end
	local seq = Instance.new("KeyframeSequence")
	seq.Name = name
	seq.Loop = loop == true
	seq.Priority = Enum.AnimationPriority[priority or "Action"]
	for _, frame in frames do
		local kf = Instance.new("Keyframe")
		kf.Time = frame.time
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
		for part, p in frame.poses do
			if not parents[part] then
				error("no joint drives part " .. part .. " in " .. rig.Name .. ". Use the part names from list_rigs.", 0)
			end
			local pose = poseFor(part)
			pose.Weight = 1
			pose.CFrame = p.cf
			pose.EasingStyle = Enum.PoseEasingStyle[p.easing or "Linear"]
			pose.EasingDirection = Enum.PoseEasingDirection[p.direction or "In"]
		end
		kf.Parent = seq
	end
	return seq
end

-- Retarget: body points in character space (X right, Y up, facing -Z) -> joint rotations.
local DOWN, FORWARD = Vector3.new(0, -1, 0), Vector3.new(0, 0, -1)
local RECIPES = {
	LowerTorso = { right = { "lHip", "rHip" }, up = { "hipC", "shC" } },
	UpperTorso = { right = { "lShoulder", "rShoulder" }, up = { "hipC", "shC" } },
	Torso = { right = { "lShoulder", "rShoulder" }, up = { "hipC", "shC" } },
	Head = { right = { "lEar", "rEar" }, forward = { "earC", "nose" } },
}
for s, Side in { l = "Left", r = "Right" } do
	RECIPES[Side .. "UpperArm"] = { aim = { s .. "Shoulder", s .. "Elbow" }, axis = DOWN }
	RECIPES[Side .. "LowerArm"] = { aim = { s .. "Elbow", s .. "Wrist" }, axis = DOWN }
	RECIPES[Side .. "Hand"] = { aim = { s .. "Wrist", s .. "HandTip" }, axis = DOWN }
	RECIPES[Side .. " Arm"] = { aim = { s .. "Shoulder", s .. "Wrist" }, axis = DOWN }
	RECIPES[Side .. "UpperLeg"] = { aim = { s .. "Hip", s .. "Knee" }, axis = DOWN }
	RECIPES[Side .. "LowerLeg"] = { aim = { s .. "Knee", s .. "Ankle" }, axis = DOWN }
	RECIPES[Side .. "Foot"] = { aim = { s .. "Heel", s .. "Toe" }, axis = FORWARD }
	RECIPES[Side .. " Leg"] = { aim = { s .. "Hip", s .. "Ankle" }, axis = DOWN }
end

local function dir(pts, pair)
	local a, b = pts[pair[1]], pts[pair[2]]
	local v = a and b and b - a
	return v and v.Magnitude > 1e-6 and v.Unit or nil
end

local function arc(a, b) -- shortest rotation taking unit vector a to unit vector b
	local axis, d = a:Cross(b), math.clamp(a:Dot(b), -1, 1)
	if axis.Magnitude < 1e-6 then
		return d > 0 and CFrame.identity
			or CFrame.fromAxisAngle(a:Cross(math.abs(a.X) < 0.9 and Vector3.xAxis or Vector3.yAxis).Unit, math.pi)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(d))
end

-- shortcut: rotations only, no root motion; add hip translation when moves need to travel.
-- prev: each part's world rotation in the previous frame, so aims stay continuous (no flips near 180 degrees)
local function solveFrame(root, order, rest, pts, prev)
	pts.hipC = pts.lHip and pts.rHip and (pts.lHip + pts.rHip) / 2
	pts.shC = pts.lShoulder and pts.rShoulder and (pts.lShoulder + pts.rShoulder) / 2
	pts.earC = pts.lEar and pts.rEar and (pts.lEar + pts.rEar) / 2
	local cf, poses = { [root] = CFrame.identity }, {}
	for _, m in order do
		local q, p = m.Part0, m.Part1
		local base = cf[q] * m.C0 * m.C1:Inverse()
		local r, want = RECIPES[p.Name], nil
		if r and r.aim then
			local d = dir(pts, r.aim)
			local from = prev[p] or base.Rotation
			want = d and arc(from:VectorToWorldSpace(r.axis), d) * from
		elseif r then
			local right, other = dir(pts, r.right), dir(pts, r.up or r.forward)
			if right and other then
				local x, y, z
				if r.up then
					y = other
					x = (right - y * right:Dot(y)).Unit
					z = x:Cross(y)
				else
					x = right
					z = -(other - x * other:Dot(x)).Unit
					y = z:Cross(x)
				end
				want = CFrame.fromMatrix(Vector3.zero, x, y, z) * rest[p].Rotation
			end
		end
		local t = want and m.C0.Rotation:Inverse() * cf[q].Rotation:Inverse() * want * m.C1.Rotation or CFrame.identity
		cf[p] = cf[q] * m.C0 * t * m.C1:Inverse()
		prev[p] = cf[p].Rotation
		if want then
			poses[p.Name] = { cf = t }
		end
	end
	return poses
end

local function fk(root, order, transforms)
	local cf = { [root] = CFrame.identity }
	for _, m in order do
		cf[m.Part1] = cf[m.Part0] * m.C0 * (transforms[m] or CFrame.identity) * m.C1:Inverse()
	end
	return cf
end

-- frames: { { t, p = { [point] = Vector3 } } } -> KeyframeSequence on rig
local function retarget(rig, name, loop, frames)
	local root, order = rigJoints(rig)
	local rest, prev = fk(root, order, {}), {}
	local out = {}
	for _, f in frames do
		table.insert(out, { time = f.t, poses = solveFrame(root, order, rest, f.p, prev) })
	end
	return buildSequence(rig, name, loop, "Action", out)
end

local function getAnimator(rig)
	local controller = rig:FindFirstChildWhichIsA("Humanoid") or rig:FindFirstChildWhichIsA("AnimationController")
	local animator = controller:FindFirstChildWhichIsA("Animator")
	if animator then
		return animator, false
	end
	animator = Instance.new("Animator")
	animator.Parent = controller
	return animator, true
end

-- Sample an R15 animation on a stock R15 body, as body points for retarget().
local function samplePoints(seq, fps)
	local body = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	body:PivotTo(CFrame.new(0, -10000, 0))
	body.Parent = workspace
	local ok, result = pcall(function()
		local root, order = rigJoints(body)
		local anim = Instance.new("Animation")
		anim.AnimationId = KeyframeSequenceProvider:RegisterKeyframeSequence(seq)
		local animator = getAnimator(body)
		local track = animator:LoadAnimation(anim)
		track:Play(0)
		local length = 0
		for _, kf in seq:GetKeyframes() do
			length = math.max(length, kf.Time)
		end
		local joint, frames = {}, {}
		for _, m in order do
			joint[m.Name] = m
		end
		for i = 0, math.floor(length * fps + 0.5) do
			local t = math.min(i / fps, length)
			track.TimePosition = t
			animator:StepAnimations(0)
			local transforms = {}
			for _, m in order do
				transforms[m] = m.inst.Transform
			end
			local cf = fk(root, order, transforms)
			local function at(jointName)
				local m = joint[jointName]
				return m and (cf[m.Part0] * m.C0).Position
			end
			local function on(partName, offset)
				local part = body:FindFirstChild(partName)
				return part and cf[part] and cf[part] * offset
			end
			local p = { nose = on("Head", Vector3.new(0, 0, -0.5)), lEar = on("Head", Vector3.new(-0.5, 0, 0)), rEar = on("Head", Vector3.new(0.5, 0, 0)) }
			for s, Side in { l = "Left", r = "Right" } do
				p[s .. "Shoulder"], p[s .. "Elbow"], p[s .. "Wrist"] = at(Side .. "Shoulder"), at(Side .. "Elbow"), at(Side .. "Wrist")
				p[s .. "Hip"], p[s .. "Knee"], p[s .. "Ankle"] = at(Side .. "Hip"), at(Side .. "Knee"), at(Side .. "Ankle")
				p[s .. "HandTip"] = on(Side .. "Hand", Vector3.new(0, -0.3, 0))
				p[s .. "Heel"], p[s .. "Toe"] = on(Side .. "Foot", Vector3.new(0, 0, 0.3)), on(Side .. "Foot", Vector3.new(0, 0, -0.3))
			end
			table.insert(frames, { t = t, p = p })
		end
		track:Stop(0)
		return frames
	end)
	body:Destroy()
	if not ok then
		error(result, 0)
	end
	return result
end

-- bundle id -> its animations, or a single animation asset id
local function packAnimations(id)
	local ok, details = pcall(AssetService.GetBundleDetailsAsync, AssetService, id)
	if not ok then
		return "Animation " .. id, { { name = "Animation " .. id, id = "rbxassetid://" .. id } }
	end
	local list = {}
	for _, item in details.Items do
		if item.Type == "Asset" then
			local loaded, model = pcall(InsertService.LoadAsset, InsertService, item.Id)
			if loaded then
				local anims = {}
				for _, a in model:GetDescendants() do
					if a:IsA("Animation") then
						table.insert(anims, a)
					end
				end
				for i, a in anims do
					table.insert(list, { name = item.Name .. (#anims > 1 and " " .. i or ""), id = a.AnimationId })
				end
				model:Destroy()
			end
		end
	end
	return details.Name, list
end

local handlers = {}

function handlers.list_rigs()
	local rigs = {}
	for _, d in workspace:GetDescendants() do
		if isRig(d) then
			local parts, anims = {}, {}
			for _, m in select(2, rigJoints(d)) do
				table.insert(parts, m.Part1.Name)
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
	local seq = getSequence(findRig(args.rig), args.name)
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
	table.sort(keyframes, function(a, b)
		return a.time < b.time
	end)
	return { loop = seq.Loop, priority = seq.Priority.Name, keyframes = keyframes }
end

function handlers.save_animation(args)
	local rig = findRig(args.rig)
	local frames = {}
	for _, k in args.keyframes do
		local poses = {}
		for part, p in k.poses do
			local pos, rot = p.pos or { 0, 0, 0 }, p.rot or { 0, 0, 0 }
			poses[part] = {
				cf = CFrame.new(pos[1], pos[2], pos[3]) * CFrame.fromEulerAnglesXYZ(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3])),
				easing = p.easing,
				direction = p.direction,
			}
		end
		table.insert(frames, { time = k.time, poses = poses })
	end
	return saveSequence(rig, buildSequence(rig, args.name, args.loop, args.priority, frames))
end

local previewing = {}
function handlers.preview_animation(args)
	local rig = findRig(args.rig)
	local seq = getSequence(rig, args.name)
	if previewing[rig] then
		previewing[rig]()
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = KeyframeSequenceProvider:RegisterKeyframeSequence(seq)
	local animator, temporary = getAnimator(rig)
	local track = animator:LoadAnimation(anim)
	track.Looped = true
	track:Play(0)
	local conn
	local function stop()
		conn:Disconnect()
		previewing[rig] = nil
		track:Stop(0)
		track:Destroy()
		for _, m in select(2, rigJoints(rig)) do
			m.inst.Transform = CFrame.identity -- leave the rig in its rest pose
		end
		if temporary then
			animator:Destroy()
		end
	end
	local left = args.seconds or 6
	conn = RunService.Heartbeat:Connect(function(dt)
		left -= dt
		if left <= 0 or not rig.Parent then
			return stop()
		end
		animator:StepAnimations(dt)
	end)
	previewing[rig] = stop
	game:GetService("Selection"):Set({ rig })
	note("Previewing " .. seq.Name)
	return { playing = seq.Name, seconds = args.seconds or 6, tip = "Look at the rig in the Studio viewport." }
end

function handlers.retarget(args)
	local rig = findRig(args.rig)
	local frames = {}
	for _, f in args.frames do
		local p = {}
		for n, v in f.p do
			p[n] = Vector3.new(v[1], v[2], v[3])
		end
		table.insert(frames, { t = f.t, p = p })
	end
	return saveSequence(rig, retarget(rig, args.name, args.loop, frames))
end

function handlers.import_pack(args)
	local rig = findRig(args.rig)
	local parts = {}
	for _, m in select(2, rigJoints(rig)) do
		parts[m.Part1.Name] = true
	end
	local packName, list = packAnimations(args.id)
	if #list == 0 then
		error("no animations found in pack " .. args.id, 0)
	end
	local results = {}
	for _, a in list do
		local ok, result = pcall(function()
			local seq = KeyframeSequenceProvider:GetKeyframeSequenceAsync(a.id):Clone() -- the original is a shared cache entry
			if #seq:GetKeyframes() == 0 then
				error("Roblox returned an empty animation; restart Studio and try again", 0)
			end
			local direct = true
			for _, pose in seq:GetDescendants() do
				if pose:IsA("Pose") and pose.Weight > 0 and not parts[pose.Name] then
					direct = false -- the pack was made for another body type (e.g. R15 pack on an R6 rig)
				end
			end
			if direct then
				seq.Name = a.name
				return saveSequence(rig, seq)
			end
			return saveSequence(rig, retarget(rig, a.name, seq.Loop, samplePoints(seq, 30)))
		end)
		table.insert(results, ok and result or { failed = a.name, error = tostring(result) })
	end
	return { pack = packName, animations = results }
end

local active = true
plugin.Unloading:Connect(function()
	active = false
	for _, stop in previewing do
		stop()
	end
end)

task.spawn(function()
	while active do
		local ok, res = pcall(HttpService.RequestAsync, HttpService, { Url = URL .. "/poll", Method = "GET" })
		if connected ~= (ok and res.StatusCode < 300) then
			connected = not connected
			render()
		end
		if ok and res.StatusCode == 200 then
			local cmd = HttpService:JSONDecode(res.Body)
			local handler = handlers[cmd.tool]
			local good, out = pcall(function()
				assert(handler, "unknown tool " .. tostring(cmd.tool))
				return handler(cmd.args or {})
			end)
			if not good then
				note("Error: " .. tostring(out))
			end
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
