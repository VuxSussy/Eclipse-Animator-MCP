-- R6Rig: the math every other module stands on. Pure functions over CFrames, no services, so it runs
-- in Studio, in a game and offline in Lune (tools/check.luau).
--
-- Conventions (character space = HumanoidRootPart space): +X right, +Y up, -Z forward.
-- A joint's Transform T poses its Part1 as  Part1 = Part0 * C0 * T * C1:Inverse().
-- A Pose.CFrame in a KeyframeSequence is exactly that T.

local R6Rig = {}

local function cf(...)
	return CFrame.new(...)
end

-- The stock R6 joints. Every R6 character made by Roblox has these values (checked against the
-- Eclipse Animator and R6 movement system rigs).
R6Rig.JOINTS = {
	Torso = {
		motor = "RootJoint",
		part0 = "HumanoidRootPart",
		C0 = cf(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		C1 = cf(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	},
	Head = {
		motor = "Neck",
		part0 = "Torso",
		C0 = cf(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		C1 = cf(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	},
	["Right Arm"] = {
		motor = "Right Shoulder",
		part0 = "Torso",
		C0 = cf(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		C1 = cf(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	},
	["Left Arm"] = {
		motor = "Left Shoulder",
		part0 = "Torso",
		C0 = cf(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		C1 = cf(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	},
	["Right Leg"] = {
		motor = "Right Hip",
		part0 = "Torso",
		C0 = cf(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		C1 = cf(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	},
	["Left Leg"] = {
		motor = "Left Hip",
		part0 = "Torso",
		C0 = cf(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		C1 = cf(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	},
}

-- Parents first.
R6Rig.ORDER = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
R6Rig.LIMBS = { "Right Arm", "Left Arm", "Right Leg", "Left Leg" }

-- The point each part "ends" in, in its own space: the fist, the sole, the face.
R6Rig.TIP = {
	["Right Arm"] = Vector3.new(0, -1, 0),
	["Left Arm"] = Vector3.new(0, -1, 0),
	["Right Leg"] = Vector3.new(0, -1, 0),
	["Left Leg"] = Vector3.new(0, -1, 0),
	Head = Vector3.new(0, 0, -0.5),
	Torso = Vector3.new(0, 1, 0),
}

-- HumanoidRootPart sits 3 studs above the floor on a standing R6 body (2-stud legs + half the torso).
R6Rig.ROOT_HEIGHT = 3

local SIDE = { ["Right Arm"] = 1, ["Left Arm"] = -1, ["Right Leg"] = 1, ["Left Leg"] = -1 }
R6Rig.SIDE = SIDE

local function joint(part)
	local j = R6Rig.JOINTS[part]
	if not j then
		error("Not an R6 part: " .. tostring(part), 3)
	end
	return j
end

-- Joints of a real rig, read from its Motor6Ds, so scaled or custom R6 bodies work too.
-- Falls back to the stock table for anything missing.
function R6Rig.fromModel(model)
	local out = {}
	for part, j in R6Rig.JOINTS do
		local owner = model:FindFirstChild(j.part0)
		local motor = owner and owner:FindFirstChild(j.motor)
		if motor and motor:IsA("Motor6D") then
			out[part] = { motor = j.motor, part0 = j.part0, C0 = motor.C0, C1 = motor.C1, instance = motor }
		else
			out[part] = j
		end
	end
	return out
end

local rad = math.rad

-- Angles named the way an animator talks, in degrees, relative to the parent part:
--   Torso  lean (forward +), twist (turn left +), tilt (top to the right +), plus pos offsets
--   Head   nod (down +), turn (left +), tilt (right +)
--   Arms   raise (swing forward/up +), spread (away from the body +), swing (sweep across the front +),
--          twist (front of the limb turned inward +)
--   Legs   raise (kick forward +), spread (outward +), twist (toes inward +)
-- Returns the rotation about the joint pivot, in the parent's space.
function R6Rig.rotation(part, a)
	a = a or {}
	if part == "Torso" or part == "Head" then
		local forward = rad(a.lean or a.nod or 0)
		local turn = rad(a.twist or a.turn or 0)
		local tilt = rad(a.tilt or 0)
		return CFrame.Angles(0, turn, 0) * CFrame.Angles(-forward, 0, 0) * CFrame.Angles(0, 0, -tilt)
	end
	local s = SIDE[part]
	if not s then
		error("Not an R6 part: " .. tostring(part), 2)
	end
	local raise, spread = rad(a.raise or 0), rad(a.spread or 0)
	local swing, twist = rad(a.swing or 0), rad(a.twist or 0)
	return CFrame.Angles(0, swing * s, 0)
		* CFrame.Angles(raise, 0, 0)
		* CFrame.Angles(0, 0, spread * s)
		* CFrame.Angles(0, twist * s, 0)
end

-- Rotation (and offset, in the parent's space) about the joint pivot -> joint Transform.
function R6Rig.toTransform(part, rotation, offset, joints)
	local j = (joints and joints[part]) or joint(part)
	local r0 = j.C0.Rotation
	local move = offset and CFrame.new(offset) or CFrame.identity
	return r0:Inverse() * move * (rotation or CFrame.identity) * r0
end

-- Joint Transform -> rotation and offset in the parent's space (the inverse of toTransform).
function R6Rig.fromTransform(part, transform, joints)
	local j = (joints and joints[part]) or joint(part)
	local r0 = j.C0.Rotation
	local m = r0 * transform * r0:Inverse()
	return m.Rotation, m.Position
end

-- Named angles -> Transform. pos = {forward, up, right} in studs, in the parent's space, works on
-- every part: on the torso it moves the body against the root (drop, lunge), on a limb or the head
-- it slides the part out of its socket (a shoulder thrown into a punch, a leg riding up into the
-- torso as the body sinks).
function R6Rig.pose(part, a, joints)
	a = a or {}
	local offset = nil
	if a.pos then
		local p = a.pos
		offset = Vector3.new(p.right or 0, p.up or 0, -(p.forward or 0))
	end
	return R6Rig.toTransform(part, R6Rig.rotation(part, a), offset, joints)
end

-- Forward kinematics. transforms: part -> Transform (missing = rest). root: HumanoidRootPart CFrame
-- (default identity, i.e. results in character space). Returns part -> CFrame.
function R6Rig.fk(transforms, root, joints)
	transforms = transforms or {}
	local world = { HumanoidRootPart = root or CFrame.identity }
	for _, part in R6Rig.ORDER do
		local j = (joints and joints[part]) or R6Rig.JOINTS[part]
		local parent = world[j.part0]
		world[part] = parent * j.C0 * (transforms[part] or CFrame.identity) * j.C1:Inverse()
	end
	return world
end

-- Where a part's joint pivot is, given its parent's CFrame.
function R6Rig.pivot(part, parentCFrame, joints)
	local j = (joints and joints[part]) or joint(part)
	return parentCFrame * j.C0.Position
end

-- Tip of a part (fist, sole, face) given the part's CFrame.
function R6Rig.tip(part, partCFrame)
	return partCFrame * (R6Rig.TIP[part] or Vector3.zero)
end

-- Length from the joint pivot to the tip (arm 1.58, leg 2.06 on stock R6).
function R6Rig.reach(part, joints)
	local j = (joints and joints[part]) or joint(part)
	return ((R6Rig.TIP[part] or Vector3.zero) - j.C1.Position).Magnitude
end

-- Shortest rotation taking unit vector a onto unit vector b.
function R6Rig.arc(a, b)
	local d = math.clamp(a:Dot(b), -1, 1)
	local axis = a:Cross(b)
	if axis.Magnitude < 1e-7 then
		if d > 0 then
			return CFrame.identity
		end
		local other = math.abs(a.X) < 0.9 and Vector3.xAxis or Vector3.yAxis
		return CFrame.fromAxisAngle(a:Cross(other).Unit, math.pi)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(d))
end

local function planar(v, n)
	return v - n * v:Dot(n)
end

-- Turn a limb about its pivot so its pivot->tip line runs along `direction` (parent space of
-- `parentCFrame`). This is retargeting math for R15ToR6 (copying where an R15 limb points), not a
-- way to author clips: R6Clip has no IK. opts.front: where the limb's front (-Z) should face;
-- opts.from: the previous rotation, so the roll stays continuous frame to frame.
-- Returns the Transform and the rotation in the parent's space.
function R6Rig.orient(part, parentCFrame, direction, opts, joints)
	opts = opts or {}
	local j = (joints and joints[part]) or joint(part)
	if direction.Magnitude < 1e-6 then
		return CFrame.identity, CFrame.identity
	end
	local want = parentCFrame.Rotation:Inverse() * direction.Unit
	local restRot = j.C0.Rotation * j.C1.Rotation:Inverse()
	local from = opts.from or CFrame.identity
	local limb = ((R6Rig.TIP[part] or Vector3.yAxis) - j.C1.Position).Unit
	local now = (from * restRot) * limb
	local rotation = R6Rig.arc(now.Unit, want) * from
	if opts.front then
		local front = (rotation * restRot) * Vector3.new(0, 0, -1)
		local a, b = planar(front, want), planar(parentCFrame.Rotation:Inverse() * opts.front, want)
		if a.Magnitude > 1e-4 and b.Magnitude > 1e-4 then
			a, b = a.Unit, b.Unit
			rotation = CFrame.fromAxisAngle(want, math.atan2(a:Cross(b):Dot(want), a:Dot(b))) * rotation
		end
	end
	return R6Rig.toTransform(part, rotation, nil, joints), rotation
end

-- How far a part has been slid out of its socket by a Transform, in the parent's space (+X right,
-- +Y up, -Z forward). Roblox turns a part about its joint, so rotation alone gives zero here.
function R6Rig.gap(part, transform, joints)
	local j = (joints and joints[part]) or joint(part)
	return j.C0.Rotation * transform.Position
end

-- How far each part may leave its socket before it stops reading as one body, in studs. Measured
-- on the user's R6 movement system (arms 0.15 idle, 0.4 walk, 0.7 run; legs ride up into the
-- torso 0.5-1.5 when the body drops) and on Creator Store R6 punch packs (the striking arm 0.5-1.4
-- out at contact). R6Clip.audit warns past these; raise them per clip with opts.budget.
R6Rig.GAP = {
	["Right Arm"] = 1.0,
	["Left Arm"] = 1.0,
	["Right Leg"] = 1.5,
	["Left Leg"] = 1.5,
	Head = 0.15,
}

-- Frame-rate independent smoothing: fraction of the gap to close this frame for a given rate (1/s).
function R6Rig.smooth(rate, dt)
	return 1 - math.exp(-rate * dt)
end

-- Damped spring, exact for any dt (no explosion on lag spikes). Works on numbers and Vector3s.
-- frequency in Hz, damping ratio: 1 = critical (no overshoot), 0.3..0.6 = lively bounce.
local Spring = {}
Spring.__index = Spring
R6Rig.Spring = Spring

function Spring.new(value, frequency, damping)
	return setmetatable({ value = value, target = value, velocity = value * 0, frequency = frequency or 4, damping = damping or 0.6 }, Spring)
end

function Spring:step(dt)
	local w = 2 * math.pi * self.frequency
	local z = self.damping
	local x = self.value - self.target
	local v = self.velocity
	local nx, nv
	if z < 1 then
		local wd = w * math.sqrt(1 - z * z)
		local e = math.exp(-z * w * dt)
		local c, s = math.cos(wd * dt), math.sin(wd * dt)
		local b = (v + x * z * w) / wd
		nx = e * (x * c + b * s)
		nv = e * (-x * wd * s + b * wd * c) - z * w * nx
	else
		local e = math.exp(-w * dt)
		nx = (x + (v + w * x) * dt) * e
		nv = (v - (v + w * x) * w * dt) * e
	end
	self.value = self.target + nx
	self.velocity = nv
	return self.value
end

function Spring:impulse(velocity)
	self.velocity += velocity
end

return R6Rig
