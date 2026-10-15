import { test } from 'node:test'
import assert from 'node:assert/strict'
import { enhance } from './enhance.js'

const wave = {
  loop: true,
  priority: 'Action',
  keyframes: [
    { time: 0, poses: { Arm: { rot: [0, 0, 0] }, Head: { rot: [0, 0, 0] } } },
    { time: 0.5, poses: { Arm: { rot: [0, 0, 100] } } },
    { time: 1, poses: { Arm: { rot: [0, 0, 10] }, Head: { rot: [5, 0, 0] } } },
  ],
}

test('exaggerate, ease and speed', () => {
  const out = enhance(wave, { exaggerate: 1.5, overshoot: 0, speed: 2, fixLoop: false })
  assert.deepEqual(out.keyframes.map(k => k.time), [0, 0.25, 0.5])
  assert.deepEqual(out.keyframes[1].poses.Arm.rot, [0, 0, 150])
  assert.equal(out.keyframes[1].poses.Arm.easing, 'Cubic')
  assert.equal(out.keyframes[1].poses.Arm.direction, 'InOut')
})

test('overshoot adds a settle key and keeps the target', () => {
  const out = enhance(wave, { exaggerate: 1, overshoot: 0.2, ease: false, fixLoop: false })
  const arm = out.keyframes.filter(k => k.poses.Arm).map(k => [k.time, k.poses.Arm.rot[2]])
  // 0.5: 100 overshoots to 120, settles back to 100 at 0.65; 1.0 is the loop end, no room to settle
  assert.deepEqual(arm, [[0, 0], [0.5, 120], [0.65, 100], [1, 10]])
})

test('fixLoop closes the loop per part', () => {
  const out = enhance(wave, { exaggerate: 1, overshoot: 0, ease: false })
  assert.deepEqual(out.keyframes.at(-1).poses.Arm.rot, [0, 0, 0])
  assert.deepEqual(out.keyframes.at(-1).poses.Head.rot, [0, 0, 0])
})

test('pushed poses never pass 180 degrees', () => {
  const big = { loop: false, keyframes: [{ time: 0, poses: { Arm: { rot: [0, 0, 0] } } }, { time: 1, poses: { Arm: { rot: [0, 0, 160] } } }, { time: 2, poses: { Arm: { rot: [0, 0, 0] } } }] }
  for (const k of enhance(big).keyframes) assert.ok(Math.abs(k.poses.Arm.rot[2]) <= 175, String(k.poses.Arm.rot))
})
