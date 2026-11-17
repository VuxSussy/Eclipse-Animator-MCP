-- Oriented boxes, not camera-space silhouettes. A small proximal hip band is the joint seam.
local M = {}
local DEFAULT = {
 Torso = Vector3.new(2, 2, 1),
 ["Right Leg"] = Vector3.new(1, 2, 1),
 ["Left Leg"] = Vector3.new(1, 2, 1),
}
local function axes(cf)
 return { cf.RightVector, cf.UpVector, -cf.LookVector }
end
-- Minimum separating translation in studs; zero means disjoint or touching.
function M.boxDepth(a, sizeA, b, sizeB)
 for _, size in { sizeA, sizeB } do
  for _, n in { size.X, size.Y, size.Z } do
   assert(n > 0 and n < math.huge, "positive finite body proxy sizes required")
  end
 end
 local aa, bb = axes(a), axes(b)
 local ha, hb = { sizeA.X / 2, sizeA.Y / 2, sizeA.Z / 2 }, { sizeB.X / 2, sizeB.Y / 2, sizeB.Z / 2 }
 local candidates = { aa[1], aa[2], aa[3], bb[1], bb[2], bb[3] }
 for _, u in aa do
  for _, v in bb do
   local cross = u:Cross(v)
   if cross.Magnitude > 1e-6 then
    table.insert(candidates, cross.Unit)
   end
  end
 end
 local delta, minimum = b.Position - a.Position, math.huge
 for _, axis in candidates do
  local ra, rb = 0, 0
  for i = 1, 3 do
   ra += ha[i] * math.abs(axis:Dot(aa[i]))
   rb += hb[i] * math.abs(axis:Dot(bb[i]))
  end
  local depth = ra + rb - math.abs(delta:Dot(axis))
  if depth <= 1e-6 then
   return 0
  end
  minimum = math.min(minimum, depth)
 end
 return minimum
end
function M.legTorso(parts, sizes)
 sizes = sizes or DEFAULT
 local torsoSize = sizes.Torso or DEFAULT.Torso
 local result = {}
 for _, name in { "Right Leg", "Left Leg" } do
  local size = sizes[name] or DEFAULT[name]
  -- Ignore only the upper 12.5% where stock hip blocks meet. The remaining thigh must be clear.
  local seam = size.Y * 0.125
  local core = parts[name] * CFrame.new(0, -seam / 2, 0)
  result[name] = M.boxDepth(parts.Torso, torsoSize, core, Vector3.new(size.X, size.Y - seam, size.Z))
 end
 return result
end
function M.audit(world, sizes)
 local worst = { ["Right Leg"] = { depth = 0, frame = 0 }, ["Left Leg"] = { depth = 0, frame = 0 } }
 for _, sample in world do
  for name, depth in M.legTorso(sample.parts, sizes) do
   if depth > worst[name].depth then
    worst[name] = { depth = depth, frame = sample.frame }
   end
  end
 end
 local notes = {}
 for _, name in { "Right Leg", "Left Leg" } do
  local hit = worst[name]
  if hit.depth > 0.025 then
   table.insert(notes, string.format("body: %s penetrates Torso by %.3f studs at frame %d beyond the hip seam; reduce the torso drop, adjust the thigh angle/forward spacing, then recheck floor and socket budgets", name, hit.depth, hit.frame))
  end
 end
 return { ok = #notes == 0, notes = notes, legs = worst }
end
return M
