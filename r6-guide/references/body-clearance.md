# Thigh / torso clearance

The user's two screenshots show a folded leg buried horizontally inside the torso and an upper thigh hidden behind the lower torso. The previous audit checked crossed legs, socket translations and sole height; those checks do not detect thigh/torso intersections. Grounding can push the whole thigh upward after a body drop while staying inside the old slide budget.

## Shipping gate

Use `R6Quality.audit(baked, meta, bodySizes)`, not R6Clip.audit alone. It retains all existing motion checks and adds R6Collision: oriented boxes with all separating axes, on every baked frame including airborne poses and transitions. A camera-space overlap alone does not fail. Standard sizes are Torso 2×2×1, legs 1×2×1; supply the actual Vector3 sizes keyed by part name for a scaled/custom rig.

The upper 12.5% of the leg is the hip connection seam (0.25 stud for a 2-stud leg). The rest of the thigh must remain clear of the torso: penetration above 0.025 stud fails. This small numerical tolerance is not a posing allowance. Reports name the leg, worst frame and penetration depth. `airborne`, `stride` and `legsMayCross` do not bypass this check.

## Repair the pose

1. Reduce torso drop and extreme inward/upward thigh rotation. A rigid R6 leg cannot reproduce a deep bent knee.
2. Key modest forward/outward spacing and suitable pelvis weighting while keeping the hip attached and a support foot grounded.
3. Recheck socket budgets, floor contact, crossed legs and the whole interpolated path. Do not fix torso clipping by detaching a leg, burying a foot or hovering.
4. Inspect front and side views around the worst frame. A raised leg needs space in front/outside the torso, not a fold through the waist.

This checks block geometry, not mesh/clothing triangles. Custom rigs need representative proxy sizes and inspection in the actual rig. The old movement references intentionally telescope some thighs into the torso; keep their provenance, but repair those poses before shipping through this new gate. Passing the older math/motion suite does not newly certify those examples for body clearance.

## Regression checks

Run `lune run check_quality` from tools. It checks touching boxes, a known overlap, a rotated AABB false positive, rest pose/hip seam, both reported failure patterns, a raised leg clear in front, a failure only in a transition frame, world-rotation invariance, airborne detection, custom body sizes and a grounded crouch repaired by reducing the drop.

`python3 check_pack_quality.py` also exercises the real pack command: a clear fixture exports, a buried thigh is rejected, and that failed build leaves an earlier valid export unchanged. The fixtures represent the failure types; the screenshots do not provide enough 3D data to reconstruct their exact poses.
