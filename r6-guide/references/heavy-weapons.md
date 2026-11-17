# Heavy weapons: mass, commitment and recovery

Read before authoring a heavy sword/greatsword. Choose a heavy-specific accessible reference; a katana/one-hand slash only establishes a different move, not the heavy archetype. Slowing that clip, widening the mesh or adding hit-stop does not establish weight. Observe the complete load, strike, overswing and recovery. Record observations separately from chosen R6 timing.

Before keying, save a `REFERENCE.visualBrief` JSON with `archetype="heavy"`, observation date, and `sources` containing URL, title, creator, rig, `status="viewed"` and timestamped observations. Use an accessible R6 heavy preview first; when unavailable/unverified, document the search and observe non-R6 heavy footage. The pack gate requires this record; it cannot prove the author actually watched, so inspect the cited moments. Never reuse a measured light slash as evidence of heavy style.

For this user's exaggerated heavy-sword brief, every attack is a whole-body effort:

- Start the load visibly: lower/drag the point or bear the blade near a supported shoulder, shift support and wind the trunk against the strike. Avoid a permanently floating, chest-high two-hand guard.
- Accelerate into one committed cut. Hips/chest/shoulders drive the weapon together; the weapon pulls the upper body after impact. It must pass well through the target line into a visibly different outside/low/behind finish.
- Show overswing and braking, then a separate recovery/regrip. Do not snap directly back to a ready pose or treat four strikes as a light katana flurry.
- Grip is phase-dependent. In this brief, the support hand releases during the overswing/recovery and catches the handle before the next powered load. Keep the dominant hand attached. Two hands may remain on the grip where a chosen reference/style calls for it; do not turn this preference into a claim that all real heavy weapons require release.
- When both hands should grip, measure them throughout that declared interval. In release intervals, measure separation and regrip at the marker; never label an accidentally detached hand as an intentional release after the fact.
- A slow load, short powered release, long follow-through and recovery must be visible at full speed, with the whole sword in the camera. Readable post-hit follow-through can replace a frozen contact pose for an arc; distinguish moving follow-through from a pause at impact.
- Keep rigid R6 thighs outside the torso and the weapon outside the floor. A deep knee bend cannot be copied by burying a block leg in the waist. Use modest grounded steps, pelvis spacing and torso turn instead.

## Shipping evidence

Use `meta.gripWindows={{startFrame,endFrame},...}` plus `Grip`/`Release` markers when grip changes. Outside these windows is explicitly released; include both sides of every regrip transition in visual inspection. Each Hit must be inside a valid grip interval for this two-hand power profile. Set `meta.heavy.gripStyle="regrip"` only for an intentionally releasing profile; continuous two-hand styles do not require a release.

For this pack, use an explicit `meta.heavy` profile with load/Hit/follow-through/recovery frames and minimum load duration, blade arc after Hit, trunk turn through the cut, post-Hit trunk turn and recovery duration. `pack` measures these from baked geometry and rejects compact cuts. These are authored acceptance thresholds for the requested game style, not biomechanical constants or permission to weaken the motion/body/grip gates.

A ground-stopped cleave is a separate case: validate actual ground contact/braking/recoil instead of demanding continued travel through the floor. Do not silently bypass the follow-through requirement. Any exception needs declared physical intent and equivalent visual/numeric evidence.

Inspect load, Hit, end of overswing and recovery from front and side. Four similar chest-level contact screenshots are insufficient to judge a heavy moveset. The full-speed Studio replay decides whether the requested sense of mass is present; a numeric PASS alone does not.
