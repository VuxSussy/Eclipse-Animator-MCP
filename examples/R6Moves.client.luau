-- R6Moves: plays the R6 kit's Walk, Run and Dash animations on the player's R6 character.
-- Walk and Run follow the movement speed, hold Shift to sprint, press Q to dash (W/A/S/D picks the direction).
-- Clips come from ReplicatedStorage.R6Animations. In Studio they play straight from the KeyframeSequences;
-- in a published game, upload each one and put its id in an "AnimationId" attribute on the KeyframeSequence.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local folder = game:GetService("ReplicatedStorage"):WaitForChild("R6Animations")

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local root = character:WaitForChild("HumanoidRootPart")
if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
	warn("R6Moves: this character is R15. Set Game Settings > Avatar > Avatar Type to R6.")
	return
end
local animator = humanoid:WaitForChild("Animator")

local WALK_SPEED, SPRINT_SPEED = 16, 27 -- the kit's movement system: walk, Shift sprint at 27
local DASH = { -- clip, studs travelled (measured in the kit's playtests)
	Forward = { "DashForward", 16.5 },
	Back = { "DashBack", 12.5 },
	Left = { "DashLeft", 13.4 },
	Right = { "DashRight", 13.4 },
}
local DASH_TIME, DASH_COOLDOWN = 0.3, 0.6

local function load(name)
	local ks = folder:WaitForChild(name)
	local id = ks:GetAttribute("AnimationId")
	if not id and RunService:IsStudio() then
		id = KeyframeSequenceProvider:RegisterKeyframeSequence(ks)
	end
	if not id then
		warn("R6Moves: " .. name .. " needs an uploaded AnimationId attribute to play outside Studio")
		return nil
	end
	local anim = Instance.new("Animation")
	anim.Name = name
	anim.AnimationId = id
	return animator:LoadAnimation(anim)
end

local walk, run = load("Walk"), load("Run")
local dashes = {}
for dir, info in DASH do
	dashes[dir] = load(info[1])
end

-- Walk / Run from the real speed
local current
local dashing = false
local function setMove(track, speed)
	if current ~= track then
		if current then
			current:Stop(0.2)
		end
		current = track
		if track then
			track:Play(0.2)
		end
	end
	if track then
		track:AdjustSpeed(speed)
	end
end
humanoid.Running:Connect(function(speed)
	if dashing then
		return -- the dash clip owns the body until it ends
	end
	if speed < 0.5 then
		setMove(nil)
		return
	end
	local backwards = root.AssemblyLinearVelocity:Dot(root.CFrame.LookVector) < -0.5 * speed
	if humanoid.WalkSpeed >= 20 then
		setMove(run, speed / SPRINT_SPEED * 1.3)
	else
		setMove(walk, (backwards and -1 or 1) * speed / 14.5)
	end
end)
humanoid.StateChanged:Connect(function(_, state)
	if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Climbing then
		setMove(nil)
	end
end)

-- Dash: a short burst along the ground, the clip times it (travel starts at its "Go" marker)
local lastDash = -math.huge
local function dash()
	if os.clock() - lastDash < DASH_COOLDOWN or humanoid.Health <= 0 then
		return
	end
	lastDash = os.clock()
	local key = UserInputService:IsKeyDown(Enum.KeyCode.A) and "Left"
		or UserInputService:IsKeyDown(Enum.KeyCode.D) and "Right"
		or UserInputService:IsKeyDown(Enum.KeyCode.S) and "Back"
		or "Forward"
	local look = (root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
	local right = (root.CFrame.RightVector * Vector3.new(1, 0, 1)).Unit
	local dir = ({ Forward = look, Back = -look, Left = -right, Right = right })[key]
	local track = dashes[key]
	humanoid.AutoRotate = false
	dashing = true
	task.delay(track and track.Length > 0 and track.Length * 0.8 or DASH_TIME, function()
		dashing = false
	end)
	if track then
		setMove(nil)
		track:Play(0.05)
	end
	local function burst()
		local velocity = Instance.new("LinearVelocity")
		velocity.Attachment0 = root:FindFirstChild("RootAttachment") or Instance.new("Attachment", root)
		velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		velocity.PrimaryTangentAxis = Vector3.xAxis
		velocity.SecondaryTangentAxis = Vector3.zAxis
		velocity.PlaneVelocity = Vector2.new(dir.X, dir.Z) * (DASH[key][2] / DASH_TIME)
		velocity.MaxForce = 1e6
		velocity.Parent = root
		task.delay(DASH_TIME, function()
			velocity:Destroy()
			humanoid.AutoRotate = true
		end)
	end
	local started = false
	local conn
	if track then
		conn = track:GetMarkerReachedSignal("Go"):Connect(function()
			if not started then
				started = true
				burst()
			end
		end)
	end
	task.delay(0.12, function()
		if conn then
			conn:Disconnect()
		end
		if not started then
			started = true
			burst()
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q then
		dash()
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		humanoid.WalkSpeed = SPRINT_SPEED
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		humanoid.WalkSpeed = WALK_SPEED
	end
end)
humanoid.WalkSpeed = WALK_SPEED
