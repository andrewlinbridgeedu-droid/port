# 诺恩与奥黛尔：待机、受击、倒地补充prompt

2026-10-14。接[完整handoff](</Volumes/andrew's SSD/Downloads/mindstone-game/docs/development/HANDOFF_GAME_AND_BANK_20261014.md>)。**现有诺恩提灯施法、奥黛尔投瓶与治疗三段已经收到，不要求重新生成同类攻击。** 以下仅为缺少的六段独立动作，尚未收到对应新视频、尚未接入运行时。

使用各自已有的背面全身图作为首帧参考；不能换成新人物或新服装。每条可独立复制。保持灰底、锁定镜头和脚底位置，不让人物在倒地时被原来的站姿画框切掉。待机需首尾闭环；受击快速明确并回位；倒地结束停住，不能自行复活。

## 诺恩 · 待机

```text
Use the attached rear-view character image as the exact visual reference. Preserve his face, hair, greatcoat, gloves, belts, boots and brass lantern unchanged.

8-second seamless idle loop, 24 fps. Locked camera, full body including boots and lantern, rear view, plain uniform medium-gray background. He breathes naturally, subtly shifts his weight, and lets the lantern sway gently. His coat tails settle softly. Feet remain in place. The final pose matches the first pose exactly.

No walking, turning toward the camera, attacks, added effects, camera movement, zoom, costume changes or cropped body parts.
```

## 诺恩 · 受击

```text
Use the attached rear-view character image as the exact visual reference. Preserve his clothing, proportions and brass lantern unchanged.

8 seconds, 24 fps. Locked camera, full body, rear view, uniform medium-gray background. Start in the reference stance. At 1 second, one unseen heavy impact strikes his upper torso: his shoulders jerk backward, knees bend, and he takes one short stagger step. The lantern swings with inertia but stays firmly in his hand. He regains balance and returns to the exact starting position by 4 seconds, then holds a breathing idle.

One sharp hit reaction only. No attacker, wounds, blood, magic effects, counterattack, camera movement or costume changes.
```

## 诺恩 · 倒地

```text
Use the attached rear-view character image as the exact visual reference. Preserve his clothing, proportions and brass lantern unchanged.

8 seconds, 24 fps. Locked camera, rear view, uniform medium-gray background and floor. Frame wide enough to keep his entire body visible throughout the fall. Start standing. At 1 second, his strength gives out: knees buckle, one knee touches the floor, and he collapses naturally toward screen-left onto his side. The lantern remains in his hand and rests on the floor beside him without breaking. Complete the fall by 4 seconds. Hold the same fallen pose until the end.

No recovery, revival, disappearance, dissolve, blood, attacker, added effects, camera movement or cropped limbs.
```

## 奥黛尔 · 待机

```text
Use the attached rear-view character image as the exact visual reference. Preserve her blue hair, scarf, embroidered robe, white dress, belts, boots and glass flask unchanged.

8-second seamless idle loop, 24 fps. Locked camera, full body, rear view, plain uniform medium-gray background. She breathes gently, shifts her weight slightly, and makes a small natural adjustment to her grip on the flask. Her scarf and robe sway subtly and settle. Feet remain in place. The final pose matches the first pose exactly.

No walking, turning toward the camera, casting, throwing, added effects, camera movement, zoom, costume changes or cropped body parts.
```

## 奥黛尔 · 受击

```text
Use the attached rear-view character image as the exact visual reference. Preserve her hair, scarf, clothing, proportions and glass flask unchanged.

8 seconds, 24 fps. Locked camera, full body, rear view, uniform medium-gray background. Start in the reference stance. At 1 second, one unseen impact strikes her shoulder: her torso twists sharply away, she staggers one short step, and draws the flask close to protect it. Her scarf and sleeves follow the sudden movement. She steadies herself and returns to the exact starting position by 4 seconds, then holds a breathing idle.

One clear hit reaction only. The flask stays in her hand. No attacker, blood, casting, throwing, added effects, camera movement or costume changes.
```

## 奥黛尔 · 倒地

```text
Use the attached rear-view character image as the exact visual reference. Preserve her hair, scarf, clothing, proportions and glass flask unchanged.

8 seconds, 24 fps. Locked camera, rear view, uniform medium-gray background and floor. Frame wide enough to keep her entire body visible throughout the fall. Start standing. At 1 second, her strength gives out: her knees bend, she briefly reaches down with her free hand, then collapses naturally toward screen-right onto her side. Her scarf and robe settle on the floor. The flask remains in her hand and rests beside her without breaking. Complete the fall by 4 seconds and remain down until the end.

No standing up, revival, disappearance, dissolve, blood, attacker, added effects, camera movement or cropped limbs.
```

## 接入注意

8秒为原片生成长度，不是最终受击或施法必须播放8秒。挑有效帧、调整演出时长，不改Swift的CD/伤害时钟。精确视频取帧须限制请求时间误差，不能用距离很远的关键帧代替动作中段。抠图只写新输出，保留当前仍需的原片；替换运行资源后重新导出Unity再构建宿主。
