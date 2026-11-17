# Staff-casting mage motion reference

## Sources opened and watched

**MythforgeGames — Wand / Magic staff / Mage Animations Pack**
Author video: https://www.youtube.com/watch?v=jISAbyZNVjg
Pack page: https://www.fab.com/listings/ff47494c-99a5-4ac4-83ad-59e212acc8b9
Author's announcement: https://forums.unrealengine.com/t/talesofgalendora-wand-magic-staff-mage-animation-pack/2658761

Watched in the browser, paused at about 7, 12, 17 and 22 seconds of the 32-second montage. The video shows several performers at once; this is not a keyframe measurement of a single clip.

Usable observations: the staff is held standing beside the body; shoulders and chest open asymmetrically, the feet never stand stiffly parallel; the torso leans and shifts its weight; the hand holding the staff and the free hand do not move as one block; some variants drop the centre of gravity a lot. Not every performer in the montage does the same move, and the video has both wands and staffs.

**R6 Magic Casting Animation Pack — RobloxAnimations**
https://robloxanimations.com/product/magic-casting-animation-pack-r6
R6 version checked: the public preview has only thumbnails, no R6 video to measure on that page. So the pack's name and sales text are not used as evidence that R6 motion was watched. The licensed files were not bought or downloaded.

**9CG — Mage Animation Pack for Unreal Engine**
https://www.youtube.com/watch?v=jBJqzE7r8BY
Opened for comparison, but the watched sections show Combo Attack, Attack Air to Floor and Walk Combat; those melee sections are not used as a model for this ranged spell set.

## Adapting to R6

These are new keys inspired by the shapes and phase offsets of the humanoid sources, not a retarget or a copy of the pack's keys. There are no measured angles or exact release timings from the sources. The numbers below are design choices for this R6 set.

| Move | New shape | Load / Cast / Hold / end key at 60 FPS |
|---|---|---|
| Bolt | Staff beside the shoulder, chest counter-turns slightly, then points the staff head; left hand opens beside the body | load to f12 / Cast 18 / hold 10f / key 50 + head trail 2 |
| Sigil Volley | Left hand goes through 3 arc poses in front of the chest; staff held at the side, then aimed | load to f18 / Cast 24 / hold 10f / key 58 +2 |
| Gather Orb | Both hands gather in to the chest, centre of gravity drops, then the spell is pushed out; torso turns from -18 to +18 degrees | load to f22 / Cast 28 / hold 12f / key 64 +2 |
| Ritual Beam | Both hands raised high, staff upright in front of the shoulder, torso leans back slightly, then drives toward the spell and holds the channel | load to f30 / Cast 38 / hold 20f / key 84 +2 |

The sigil-drawing, gathering and channel-holding gestures are design interpretations, not attributed to a named clip in the video. Unlike the old version: the four moves do not share one Cast shape; the left hand has its own role and rhythm; the joint seams are kept so the moves can chain as a combo. Total 264f = 4.4 seconds, longer than the 188f version so the gestures and the charge-up read.

R6 limits: no elbows, wrists or fingers. Sigils are suggested with the shoulder and short hand slides, not finger gestures. The staff is held rigidly in the right hand, its head at (0,-1,-3.2) in Right Arm space.

## Rule for reuse in the skill

For ranged staff casting, never use the jab/cross/sword slash as the reference for the motion language. Find a real mage video or clip first. If you only read a product page, say that the motion was not watched. If only humanoid sources exist, state what was observed, what was designed, and the limits of the R6 adaptation. The Cast marker is the spell's release; the hit is the projectile reaching its target. Check the free hand's pose, the loading, the weight shift, where the staff head points, the channel hold and the recovery; a structural audit does not by itself prove the pose reads as a mage.
