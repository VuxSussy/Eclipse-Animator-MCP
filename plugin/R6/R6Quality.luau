-- Shipping gate: retain the original motion audit, then check visible thigh/torso geometry.
local Clip = require(script.Parent.R6Clip)
local Collision = require(script.Parent.R6Collision)
local M = {}
function M.audit(baked, meta, bodySizes)
 local motion = Clip.audit(baked, meta)
 local body = Collision.audit(Clip.world(baked), bodySizes)
 for _, note in body.notes do
  table.insert(motion.notes, note)
 end
 motion.metrics.bodyLegs = body.legs
 motion.ok = motion.ok and body.ok
 return motion
end
return M
