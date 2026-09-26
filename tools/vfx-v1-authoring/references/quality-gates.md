# Commercial acceptance gates

## Hard gates

- Exactly five review frames show the archetype’s readable progression: anticipation/formation, development or travel, contact/activation, peak, and decay. Stationary aura, burst, or storm effects do not need fake translation.
- Motion is continuous at 1× and 0.30×; no stepped position changes.
- No magenta material, black rectangle, detached anchor, static full-screen card, or regular placeholder geometry.
- No duplicate hit, gameplay mutation, persistent light, orphan object, live particle emitter, material leak, or Effekseer handle after completion/interruption/replay.
- Every Resources path resolves and every generated/imported asset has provenance.
- iPhone 13 report targets 60 fps, averages at least 55 fps, keeps p95 frame time at or below 20 ms, records particle/draw-call/peak-memory measurements, and separately reports zero orphan roots, lights, emitters, materials, and Effekseer handles after natural completion, interruption, and replay.

The lock command validates this report shape. Particle, draw-call, and memory values must be measured and nonnegative; tighten their numeric ceilings when the project establishes device-wide budgets instead of inventing thresholds from desktop capture.

## Visual review

- Readable primary silhouette at phone size.
- At least three depth-separated jobs: core, shape/direction, impact/decay.
- Palette has controlled value hierarchy; white-hot cores are small and intentional.
- Foreground and background impact layers make contact feel volumetric. The peak may visually engulf the actor without disabling the actor renderer.
- Decay explains where energy went; it does not simply disappear.

## Status language

Call an unapproved output a `candidate`. Call it `approved` only after explicit human approval and lock creation. Distinguish desktop preview, device performance report, Unity iOS export, native build, installation, and actual launch.
