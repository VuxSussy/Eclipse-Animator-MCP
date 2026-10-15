// Animation enhancer: pure transforms on the JSON shape get_animation returns.

const ZERO = [0, 0, 0]
const key = t => Math.round(t * 1e4) / 1e4

// keyframes -> { part: [{ time, pos, rot, easing, direction }] }
function toTracks(keyframes) {
  const tracks = {}
  for (const kf of keyframes) {
    for (const [part, p] of Object.entries(kf.poses)) {
      (tracks[part] ??= []).push({ time: kf.time, pos: p.pos ?? ZERO, rot: p.rot ?? ZERO, easing: p.easing ?? 'Linear', direction: p.direction ?? 'In' })
    }
  }
  for (const t of Object.values(tracks)) t.sort((a, b) => a.time - b.time)
  return tracks
}

function toKeyframes(tracks) {
  const byTime = new Map()
  for (const [part, track] of Object.entries(tracks)) {
    for (const { time, ...pose } of track) {
      const t = key(time)
      if (!byTime.has(t)) byTime.set(t, { time: t, poses: {} })
      byTime.get(t).poses[part] = pose
    }
  }
  return [...byTime.values()].sort((a, b) => a.time - b.time)
}

const lerp3 = (a, b, k) => a.map((v, i) => v + (b[i] - v) * k)
const dist = (a, b) => Math.hypot(...a.map((v, i) => v - b[i]))
// past 180 degrees Roblox interpolates the short way round, so a pushed pose would swing backwards
const clampRot = r => r.map(v => Math.max(-175, Math.min(175, v)))

/**
 * @param anim { loop, priority, keyframes }
 * @param o.exaggerate  scale every pose away from rest (1 = unchanged)
 * @param o.ease        turn Linear keys into Cubic InOut
 * @param o.overshoot   0..0.5, push big moves past their target then settle back
 * @param o.speed       playback speed multiplier
 * @param o.fixLoop     on looping animations, make each part end where it starts
 */
export function enhance(anim, { exaggerate = 1.15, ease = true, overshoot = 0.15, speed = 1, fixLoop = true } = {}) {
  if (!(speed > 0)) throw new Error('speed must be > 0')
  const tracks = toTracks(anim.keyframes)
  const end = Math.max(...anim.keyframes.map(k => k.time))

  for (const [part, track] of Object.entries(tracks)) {
    let out = track.map(k => ({
      ...k,
      pos: k.pos.map(v => v * exaggerate),
      rot: clampRot(k.rot.map(v => v * exaggerate)),
      ...(ease && k.easing === 'Linear' ? { easing: 'Cubic', direction: 'InOut' } : {}),
    }))

    if (anim.loop && fixLoop && out.length > 1 && out.at(-1).time === end && out[0].time === 0) {
      out.at(-1).pos = out[0].pos
      out.at(-1).rot = out[0].rot
    }

    if (overshoot > 0) {
      const withSettle = []
      out.forEach((k, i) => {
        const prev = out[i - 1], next = out[i + 1]
        // overshoot only moves of 15+ degrees that have room to settle before the next key
        const room = next ? (next.time - k.time) / 2 : anim.loop ? 0 : 0.15
        if (!prev || room < 0.04 || dist(prev.rot, k.rot) < 15) return withSettle.push(k)
        const settle = Math.min(0.15, room)
        withSettle.push({ ...k, rot: clampRot(lerp3(prev.rot, k.rot, 1 + overshoot)), pos: lerp3(prev.pos, k.pos, 1 + overshoot), easing: 'Cubic', direction: 'Out' })
        withSettle.push({ ...k, time: k.time + settle, easing: 'Cubic', direction: 'InOut' })
      })
      out = withSettle
    }

    tracks[part] = out.map(k => ({ ...k, time: k.time / speed }))
  }

  return { ...anim, keyframes: toKeyframes(tracks) }
}
