# 柜台人物与固定背景分层 · 2026-09-29

用户要求换人时背景不动，所有店内柜台采用独立透明人物。此记录是素材与代码接入证据，真机截图和用户认可另记。

共生成 12 张空背景、27 张透明人物；莫莉与巴托复用已有透明立绘。原整张场景、人物原稿和源模型保留。餐厅和教会大厅原画本就没有实际人物，不重新绘制。

`HomeSceneArtwork` 将固定背景、当前人物、同一背景的柜台遮挡按顺序绘制；遮挡在 SwiftUI 中按柜台边沿裁切，不新增拼好的合成图片。人物先按 alpha 可见边界取图；最近八张人物的裁切缓存上限 24 MiB。此上限只约束该缓存，不代表整个应用或系统图片缓存内存上限。

四枚底栏人物/建筑/背包图标由原 62 pt 改为 54.56 pt（88%），文字、按钮区域和百工坊大小保持。169.6 曾改为 92%，用户认为还不够，当前再略减。

## 原画生成记录

### HomeCityHallEmpty20260929

类型：background；尺寸：1536 × 1024。

```text
Use case: precise-object-edit. Asset type: reusable empty interior background for a layered game counter scene. EDIT the reference image: remove EVERY person, face, body, hand, visitor and silhouette, including distant people outside windows, and naturally reconstruct the previously hidden shelves, chairs, architecture and floor. Keep the exact original camera angle, crop, counter height, desk surfaces, foreground objects, furniture, lighting, materials, color palette and all scenery. This is an empty shop/office, with absolutely no humans and no human shadows. Do not add any new people, ghosts, portraits, words, UI or watermarks. Keep newspapers, mugs, medical supplies, envelopes and other nonhuman props in their original places. Where a person held a prop, place the prop naturally on the desk or shelf instead. The counter should remain in the same position so separate transparent character sprites can later be inserted behind it. Preserve original aspect ratio and visual art style.
```

### HomePoliceOfficeEmpty20260929

类型：background；尺寸：1536 × 1024。

```text
Use case: precise-object-edit. Asset type: reusable empty interior background for a layered game counter scene. EDIT the reference image: remove EVERY person, face, body, hand, visitor and silhouette, including distant people outside windows, and naturally reconstruct the previously hidden shelves, chairs, architecture and floor. Keep the exact original camera angle, crop, counter height, desk surfaces, foreground objects, furniture, lighting, materials, color palette and all scenery. This is an empty shop/office, with absolutely no humans and no human shadows. Do not add any new people, ghosts, portraits, words, UI or watermarks. Keep newspapers, mugs, medical supplies, envelopes and other nonhuman props in their original places. Where a person held a prop, place the prop naturally on the desk or shelf instead. The counter should remain in the same position so separate transparent character sprites can later be inserted behind it. Preserve original aspect ratio and visual art style.
```

### HomePostOfficeEmpty20260929

类型：background；尺寸：1536 × 1024。

```text
Use case: precise-object-edit. Asset type: reusable empty interior background for a layered game counter scene. EDIT the reference image: remove EVERY person, face, body, hand, visitor and silhouette, including distant people outside windows, and naturally reconstruct the previously hidden shelves, chairs, architecture and floor. Keep the exact original camera angle, crop, counter height, desk surfaces, foreground objects, furniture, lighting, materials, color palette and all scenery. This is an empty shop/office, with absolutely no humans and no human shadows. Do not add any new people, ghosts, portraits, words, UI or watermarks. Keep newspapers, mugs, medical supplies, envelopes and other nonhuman props in their original places. Where a person held a prop, place the prop naturally on the desk or shelf instead. The counter should remain in the same position so separate transparent character sprites can later be inserted behind it. Preserve original aspect ratio and visual art style.
```

### HomeHarborOfficeEmpty20260929

类型：background；尺寸：1536 × 1024。

```text
Use case: precise-object-edit. Asset type: reusable empty interior background for a layered game counter scene. EDIT the reference image: remove EVERY person, face, body, hand, visitor and silhouette, including distant people outside windows, and naturally reconstruct the previously hidden shelves, chairs, architecture and floor. Keep the exact original camera angle, crop, counter height, desk surfaces, foreground objects, furniture, lighting, materials, color palette and all scenery. This is an empty shop/office, with absolutely no humans and no human shadows. Do not add any new people, ghosts, portraits, words, UI or watermarks. Keep newspapers, mugs, medical supplies, envelopes and other nonhuman props in their original places. Where a person held a prop, place the prop naturally on the desk or shelf instead. The counter should remain in the same position so separate transparent character sprites can later be inserted behind it. Preserve original aspect ratio and visual art style.
```

### HomeCommissionOfficeEmpty20260929

类型：background；尺寸：1536 × 1024。

```text
Use case: precise-object-edit. Asset type: reusable empty interior background for a layered game counter scene. EDIT the reference image: remove EVERY person, face, body, hand, visitor and silhouette, including distant people outside windows, and naturally reconstruct the previously hidden shelves, chairs, architecture and floor. Keep the exact original camera angle, crop, counter height, desk surfaces, foreground objects, furniture, lighting, materials, color palette and all scenery. This is an empty shop/office, with absolutely no humans and no human shadows. Do not add any new people, ghosts, portraits, words, UI or watermarks. Keep newspapers, mugs, medical supplies, envelopes and other nonhuman props in their original places. Where a person held a prop, place the prop naturally on the desk or shelf instead. The counter should remain in the same position so separate transparent character sprites can later be inserted behind it. Preserve original aspect ratio and visual art style.
```

### HomeClinicEmpty20260929

类型：background；尺寸：1536 × 1024。

```text
Use case: precise-object-edit. Asset type: reusable empty interior background for a layered game counter scene. EDIT the reference image: remove EVERY person, face, body, hand, visitor and silhouette, including distant people outside windows, and naturally reconstruct the previously hidden shelves, chairs, architecture and floor. Keep the exact original camera angle, crop, counter height, desk surfaces, foreground objects, furniture, lighting, materials, color palette and all scenery. This is an empty shop/office, with absolutely no humans and no human shadows. Do not add any new people, ghosts, portraits, words, UI or watermarks. Keep newspapers, mugs, medical supplies, envelopes and other nonhuman props in their original places. Where a person held a prop, place the prop naturally on the desk or shelf instead. The counter should remain in the same position so separate transparent character sprites can later be inserted behind it. Preserve original aspect ratio and visual art style.
```

### HomeOldStreetShopsEmpty20260929

类型：background；尺寸：1536 × 1024。

```text
Use case: precise-object-edit. Asset type: reusable empty interior background for a layered game counter scene. EDIT the reference image: remove EVERY person, face, body, hand, visitor and silhouette, including distant people outside windows, and naturally reconstruct the previously hidden shelves, chairs, architecture and floor. Keep the exact original camera angle, crop, counter height, desk surfaces, foreground objects, furniture, lighting, materials, color palette and all scenery. This is an empty shop/office, with absolutely no humans and no human shadows. Do not add any new people, ghosts, portraits, words, UI or watermarks. Keep newspapers, mugs, medical supplies, envelopes and other nonhuman props in their original places. Where a person held a prop, place the prop naturally on the desk or shelf instead. The counter should remain in the same position so separate transparent character sprites can later be inserted behind it. Preserve original aspect ratio and visual art style.
```

### HomeCopperMerchantEmpty20260929

类型：background；尺寸：1536 × 1024。

```text
Use case: precise-object-edit. Asset type: reusable empty interior background for a layered game counter scene. EDIT the reference image: remove EVERY person, face, body, hand, visitor and silhouette, including distant people outside windows, and naturally reconstruct the previously hidden shelves, chairs, architecture and floor. Keep the exact original camera angle, crop, counter height, desk surfaces, foreground objects, furniture, lighting, materials, color palette and all scenery. This is an empty shop/office, with absolutely no humans and no human shadows. Do not add any new people, ghosts, portraits, words, UI or watermarks. Keep newspapers, mugs, medical supplies, envelopes and other nonhuman props in their original places. Where a person held a prop, place the prop naturally on the desk or shelf instead. The counter should remain in the same position so separate transparent character sprites can later be inserted behind it. Preserve original aspect ratio and visual art style.
```

### HomeNewspaperOfficeEmpty20260929

类型：background；尺寸：1536 × 1024。

```text
Use case: precise-object-edit. Asset type: reusable empty interior background for a layered game counter scene. EDIT the reference image: remove EVERY person, face, body, hand, visitor and silhouette, including distant people outside windows, and naturally reconstruct the previously hidden shelves, chairs, architecture and floor. Keep the exact original camera angle, crop, counter height, desk surfaces, foreground objects, furniture, lighting, materials, color palette and all scenery. This is an empty shop/office, with absolutely no humans and no human shadows. Do not add any new people, ghosts, portraits, words, UI or watermarks. Keep newspapers, mugs, medical supplies, envelopes and other nonhuman props in their original places. Where a person held a prop, place the prop naturally on the desk or shelf instead. The counter should remain in the same position so separate transparent character sprites can later be inserted behind it. Preserve original aspect ratio and visual art style.
```

### HomeCafeEmpty20260929

类型：background；尺寸：941 × 1672。

```text
Use case: precise-object-edit. Asset type: reusable empty interior background for a layered game counter scene. EDIT the reference image: remove EVERY person, face, body, hand, visitor and silhouette, including distant people outside windows, and naturally reconstruct the previously hidden shelves, chairs, architecture and floor. Keep the exact original camera angle, crop, counter height, desk surfaces, foreground objects, furniture, lighting, materials, color palette and all scenery. This is an empty shop/office, with absolutely no humans and no human shadows. Do not add any new people, ghosts, portraits, words, UI or watermarks. Keep newspapers, mugs, medical supplies, envelopes and other nonhuman props in their original places. Where a person held a prop, place the prop naturally on the desk or shelf instead. The counter should remain in the same position so separate transparent character sprites can later be inserted behind it. Preserve original aspect ratio and visual art style.
```

### HomeCivilClerk20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: background-extraction. Asset type: independent transparent game character layer. Extract only the central woman in the green waistcoat, preserving her identity and outfit. Relaxed friendly standing pose with hands holding one sheet of paper at waist level. Single person only, framed from the TOP OF HEAD to mid-thigh, entire head and both arms and held props visible with a little transparent padding. Remove EVERY piece of the room, furniture, counter, floor, wall and background; all space around this person is actual alpha transparency, not a painted checkerboard or black/white color. Do not include anyone else. The figure will be placed behind an existing counter by code, so do not draw any desk or counter. Preserve original facial identity, gender, costume, lighting and rendering style. No text, UI or watermark.
```

### HomeHarborClerk20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: background-extraction. Asset type: independent transparent game character layer. Extract only the central male harbor officer in the navy coat, preserving his identity and outfit, holding a closed ledger. Single person only, framed from the TOP OF HEAD to mid-thigh, entire head and both arms and held props visible with a little transparent padding. Remove EVERY piece of the room, furniture, counter, floor, wall and background; all space around this person is actual alpha transparency, not a painted checkerboard or black/white color. Do not include anyone else. The figure will be placed behind an existing counter by code, so do not draw any desk or counter. Preserve original facial identity, gender, costume, lighting and rendering style. No text, UI or watermark.
```

### HomePoliceClerk20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: background-extraction. Asset type: independent transparent game character layer. Extract only the foreground female constable in navy uniform, preserving her identity and outfit, relaxed standing with hands near her belt. Single person only, framed from the TOP OF HEAD to mid-thigh, entire head and both arms and held props visible with a little transparent padding. Remove EVERY piece of the room, furniture, counter, floor, wall and background; all space around this person is actual alpha transparency, not a painted checkerboard or black/white color. Do not include anyone else. The figure will be placed behind an existing counter by code, so do not draw any desk or counter. Preserve original facial identity, gender, costume, lighting and rendering style. No text, UI or watermark.
```

### HomeCommissionClerk20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: background-extraction. Asset type: independent transparent game character layer. Extract only the central female registration clerk, preserving her identity and outfit, holding a wax sealed letter. Single person only, framed from the TOP OF HEAD to mid-thigh, entire head and both arms and held props visible with a little transparent padding. Remove EVERY piece of the room, furniture, counter, floor, wall and background; all space around this person is actual alpha transparency, not a painted checkerboard or black/white color. Do not include anyone else. The figure will be placed behind an existing counter by code, so do not draw any desk or counter. Preserve original facial identity, gender, costume, lighting and rendering style. No text, UI or watermark.
```

### HomeMerchant20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: background-extraction. Asset type: independent transparent game character layer. Extract only the central male copper merchant with dark hair, beard and teal waistcoat, preserving his identity, relaxed standing hands near belt; no counter. Single person only, framed from the TOP OF HEAD to mid-thigh, entire head and both arms and held props visible with a little transparent padding. Remove EVERY piece of the room, furniture, counter, floor, wall and background; all space around this person is actual alpha transparency, not a painted checkerboard or black/white color. Do not include anyone else. The figure will be placed behind an existing counter by code, so do not draw any desk or counter. Preserve original facial identity, gender, costume, lighting and rendering style. No text, UI or watermark.
```

### HomePostman20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: background-extraction. Asset type: independent transparent game character layer. Extract only the male postman, preserve his exact existing face, hairstyle, blue coat and two envelopes. Keep illustration style. Single person only, framed from the TOP OF HEAD to mid-thigh, entire head and both arms and held props visible with a little transparent padding. Remove EVERY piece of the room, furniture, counter, floor, wall and background; all space around this person is actual alpha transparency, not a painted checkerboard or black/white color. Do not include anyone else. The figure will be placed behind an existing counter by code, so do not draw any desk or counter. Preserve original facial identity, gender, costume, lighting and rendering style. No text, UI or watermark.
```

### HomeArchivist20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: background-extraction. Asset type: independent transparent game character layer. Extract only the young male archivist, preserve exact existing face, sandy hair, blue eyes, embroidered outfit and magnifying glass. Keep illustration style, upright relaxed pose. Single person only, framed from the TOP OF HEAD to mid-thigh, entire head and both arms and held props visible with a little transparent padding. Remove EVERY piece of the room, furniture, counter, floor, wall and background; all space around this person is actual alpha transparency, not a painted checkerboard or black/white color. Do not include anyone else. The figure will be placed behind an existing counter by code, so do not draw any desk or counter. Preserve original facial identity, gender, costume, lighting and rendering style. No text, UI or watermark.
```

### HomeCarpenter20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: background-extraction. Asset type: independent transparent game character layer. Extract only the male carpenter, preserve exact existing face, graying beard, brown apron, door drawing and hand tool. Keep illustration style. Single person only, framed from the TOP OF HEAD to mid-thigh, entire head and both arms and held props visible with a little transparent padding. Remove EVERY piece of the room, furniture, counter, floor, wall and background; all space around this person is actual alpha transparency, not a painted checkerboard or black/white color. Do not include anyone else. The figure will be placed behind an existing counter by code, so do not draw any desk or counter. Preserve original facial identity, gender, costume, lighting and rendering style. No text, UI or watermark.
```

### HomeEditor20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: background-extraction. Asset type: independent transparent game character layer. Extract only the foreground female editor, preserve exact face, dark hair and outfit, holding the newspaper open; keep warm lighting, no desk. Single person only, framed from the TOP OF HEAD to mid-thigh, entire head and both arms and held props visible with a little transparent padding. Remove EVERY piece of the room, furniture, counter, floor, wall and background; all space around this person is actual alpha transparency, not a painted checkerboard or black/white color. Do not include anyone else. The figure will be placed behind an existing counter by code, so do not draw any desk or counter. Preserve original facial identity, gender, costume, lighting and rendering style. No text, UI or watermark.
```

### HomePrinter20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: background-extraction. Asset type: independent transparent game character layer. Extract only the male printer at the right rear, with dark beard and ink stained apron. Turn him gently to face viewer, holding a loose sheet of newspaper; no printing press. Single person only, framed from the TOP OF HEAD to mid-thigh, entire head and both arms and held props visible with a little transparent padding. Remove EVERY piece of the room, furniture, counter, floor, wall and background; all space around this person is actual alpha transparency, not a painted checkerboard or black/white color. Do not include anyone else. The figure will be placed behind an existing counter by code, so do not draw any desk or counter. Preserve original facial identity, gender, costume, lighting and rendering style. No text, UI or watermark.
```

### HomeTailor20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: background-extraction. Asset type: independent transparent game character layer. Extract only the female tailor at left, preserve exact face and outfit with measuring tape, upright relaxed pose holding a small folded swatch; no desk. Single person only, framed from the TOP OF HEAD to mid-thigh, entire head and both arms and held props visible with a little transparent padding. Remove EVERY piece of the room, furniture, counter, floor, wall and background; all space around this person is actual alpha transparency, not a painted checkerboard or black/white color. Do not include anyone else. The figure will be placed behind an existing counter by code, so do not draw any desk or counter. Preserve original facial identity, gender, costume, lighting and rendering style. No text, UI or watermark.
```

### HomeNotary20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: stylized-concept. Asset type: independent transparent NPC layer for a game office counter. Create a SINGLE distinct character: An elderly woman with silver hair in a tidy bun, burgundy formal waistcoat and cream blouse, brass spectacles, holding a sealed legal scroll. The input image is ONLY a reference for the warm painterly cinematic lighting, historical fantasy costume materials and visual style; do not copy any existing person's face. Portrait straight on from top of head through mid-thigh, both arms and props fully visible, eye level front three-quarter view, pleasant natural greeting expression. Single character with actual alpha transparency around every edge; no room, desk, furniture, floor, shadow backdrop, other people, typography, UI or watermark. Soft golden light from upper left. Ample transparent padding. This figure will be inserted behind a separate counter background.
```

### HomeStampClerk20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: stylized-concept. Asset type: independent transparent NPC layer for a game office counter. Create a SINGLE distinct character: A middle aged bald man with a neat moustache, charcoal waistcoat, white shirt, holding a brass seal stamp. The input image is ONLY a reference for the warm painterly cinematic lighting, historical fantasy costume materials and visual style; do not copy any existing person's face. Portrait straight on from top of head through mid-thigh, both arms and props fully visible, eye level front three-quarter view, pleasant natural greeting expression. Single character with actual alpha transparency around every edge; no room, desk, furniture, floor, shadow backdrop, other people, typography, UI or watermark. Soft golden light from upper left. Ample transparent padding. This figure will be inserted behind a separate counter background.
```

### HomeLaborClerk20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: stylized-concept. Asset type: independent transparent NPC layer for a game office counter. Create a SINGLE distinct character: A young adult man with red curly hair and freckles, russet worker's waistcoat over cream shirt, holding a small employment register. The input image is ONLY a reference for the warm painterly cinematic lighting, historical fantasy costume materials and visual style; do not copy any existing person's face. Portrait straight on from top of head through mid-thigh, both arms and props fully visible, eye level front three-quarter view, pleasant natural greeting expression. Single character with actual alpha transparency around every edge; no room, desk, furniture, floor, shadow backdrop, other people, typography, UI or watermark. Soft golden light from upper left. Ample transparent padding. This figure will be inserted behind a separate counter background.
```

### HomeReliefClerk20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: stylized-concept. Asset type: independent transparent NPC layer for a game office counter. Create a SINGLE distinct character: A mature woman with dark braided hair and a compassionate face, olive green coat and ivory scarf, holding a small bundle of clean cloth. The input image is ONLY a reference for the warm painterly cinematic lighting, historical fantasy costume materials and visual style; do not copy any existing person's face. Portrait straight on from top of head through mid-thigh, both arms and props fully visible, eye level front three-quarter view, pleasant natural greeting expression. Single character with actual alpha transparency around every edge; no room, desk, furniture, floor, shadow backdrop, other people, typography, UI or watermark. Soft golden light from upper left. Ample transparent padding. This figure will be inserted behind a separate counter background.
```

### HomeHarborArchivist20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: stylized-concept. Asset type: independent transparent NPC layer for a game office counter. Create a SINGLE distinct character: An older man with close cropped white hair, small round spectacles, dark blue waistcoat, holding a rolled maritime chart. The input image is ONLY a reference for the warm painterly cinematic lighting, historical fantasy costume materials and visual style; do not copy any existing person's face. Portrait straight on from top of head through mid-thigh, both arms and props fully visible, eye level front three-quarter view, pleasant natural greeting expression. Single character with actual alpha transparency around every edge; no room, desk, furniture, floor, shadow backdrop, other people, typography, UI or watermark. Soft golden light from upper left. Ample transparent padding. This figure will be inserted behind a separate counter background.
```

### HomePhotographer20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: stylized-concept. Asset type: independent transparent NPC layer for a game office counter. Create a SINGLE distinct character: An adult woman with short auburn hair, navy high neck jacket and mustard scarf, holding a vintage folding camera. The input image is ONLY a reference for the warm painterly cinematic lighting, historical fantasy costume materials and visual style; do not copy any existing person's face. Portrait straight on from top of head through mid-thigh, both arms and props fully visible, eye level front three-quarter view, pleasant natural greeting expression. Single character with actual alpha transparency around every edge; no room, desk, furniture, floor, shadow backdrop, other people, typography, UI or watermark. Soft golden light from upper left. Ample transparent padding. This figure will be inserted behind a separate counter background.
```

### HomePawnbroker20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: stylized-concept. Asset type: independent transparent NPC layer for a game office counter. Create a SINGLE distinct character: An elderly broad shouldered man with a thick grey moustache, plum waistcoat, brass watch chain, holding a small jewelry loupe. The input image is ONLY a reference for the warm painterly cinematic lighting, historical fantasy costume materials and visual style; do not copy any existing person's face. Portrait straight on from top of head through mid-thigh, both arms and props fully visible, eye level front three-quarter view, pleasant natural greeting expression. Single character with actual alpha transparency around every edge; no room, desk, furniture, floor, shadow backdrop, other people, typography, UI or watermark. Soft golden light from upper left. Ample transparent padding. This figure will be inserted behind a separate counter background.
```

### HomeDyeClerk20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: stylized-concept. Asset type: independent transparent NPC layer for a game office counter. Create a SINGLE distinct character: A woman in her thirties with black hair tied back, indigo apron with ink stains over white blouse, holding a folded dyed fabric swatch. The input image is ONLY a reference for the warm painterly cinematic lighting, historical fantasy costume materials and visual style; do not copy any existing person's face. Portrait straight on from top of head through mid-thigh, both arms and props fully visible, eye level front three-quarter view, pleasant natural greeting expression. Single character with actual alpha transparency around every edge; no room, desk, furniture, floor, shadow backdrop, other people, typography, UI or watermark. Soft golden light from upper left. Ample transparent padding. This figure will be inserted behind a separate counter background.
```

### HomeRetiredPrinter20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: stylized-concept. Asset type: independent transparent NPC layer for a game office counter. Create a SINGLE distinct character: A lean elderly man with grey stubble, flat cloth cap and brown apron, holding a small wooden type block. The input image is ONLY a reference for the warm painterly cinematic lighting, historical fantasy costume materials and visual style; do not copy any existing person's face. Portrait straight on from top of head through mid-thigh, both arms and props fully visible, eye level front three-quarter view, pleasant natural greeting expression. Single character with actual alpha transparency around every edge; no room, desk, furniture, floor, shadow backdrop, other people, typography, UI or watermark. Soft golden light from upper left. Ample transparent padding. This figure will be inserted behind a separate counter background.
```

### HomeNorn20260929

类型：character；尺寸：941 × 1672。

```text
Use case: background-extraction. Asset type: transparent game NPC portrait. Keep ONLY the one main character and their held personal props from this reference. Preserve the exact original facial identity, age, gender, hairstyle, colors, costume, linework and illustration style. Remove all room scenery, buildings, sky, walls, furniture, background lights and gradients. Actual alpha transparency around the character, no solid or checkerboard backdrop. Portrait from the complete top of head to mid-thigh, both arms and personal held props fully included, hands natural, centered with transparent padding. Do not add another person, text, room, counter, UI or watermark. It will be composited behind an existing desk in a separate game room layer.
```

### HomeOdelle20260929

类型：character；尺寸：941 × 1672。

```text
Use case: background-extraction. Asset type: transparent game NPC portrait. Keep ONLY the one main character and their held personal props from this reference. Preserve the exact original facial identity, age, gender, hairstyle, colors, costume, linework and illustration style. Remove all room scenery, buildings, sky, walls, furniture, background lights and gradients. Actual alpha transparency around the character, no solid or checkerboard backdrop. Portrait from the complete top of head to mid-thigh, both arms and personal held props fully included, hands natural, centered with transparent padding. Do not add another person, text, room, counter, UI or watermark. It will be composited behind an existing desk in a separate game room layer.
```

### HomeVera20260929

类型：character；尺寸：941 × 1672。

```text
Use case: background-extraction. Asset type: transparent game NPC portrait. Keep ONLY the one main character and their held personal props from this reference. Preserve the exact original facial identity, age, gender, hairstyle, colors, costume, linework and illustration style. Remove all room scenery, buildings, sky, walls, furniture, background lights and gradients. Actual alpha transparency around the character, no solid or checkerboard backdrop. Portrait from the complete top of head to mid-thigh, both arms and personal held props fully included, hands natural, centered with transparent padding. Do not add another person, text, room, counter, UI or watermark. It will be composited behind an existing desk in a separate game room layer.
```

### HomeEli20260929

类型：character；尺寸：941 × 1671。

```text
Use case: background-extraction. Asset type: transparent game NPC portrait. Keep ONLY the one main character and their held personal props from this reference. Preserve the exact original facial identity, age, gender, hairstyle, colors, costume, linework and illustration style. Remove all room scenery, buildings, sky, walls, furniture, background lights and gradients. Actual alpha transparency around the character, no solid or checkerboard backdrop. Portrait from the complete top of head to mid-thigh, both arms and personal held props fully included, hands natural, centered with transparent padding. Do not add another person, text, room, counter, UI or watermark. It will be composited behind an existing desk in a separate game room layer.
```

### HomeMohr20260929

类型：character；尺寸：1024 × 1536。

```text
Use case: background-extraction. Asset type: transparent game NPC portrait. Keep ONLY the one main character and their held personal props from this reference. Preserve the exact original facial identity, age, gender, hairstyle, colors, costume, linework and illustration style. Remove all room scenery, buildings, sky, walls, furniture, background lights and gradients. Actual alpha transparency around the character, no solid or checkerboard backdrop. Portrait from the complete top of head to mid-thigh, both arms and personal held props fully included, hands natural, centered with transparent padding. Do not add another person, text, room, counter, UI or watermark. It will be composited behind an existing desk in a separate game room layer.
```

### HomeTavernEmpty20260929

类型：background；尺寸：1024 × 1536。

```text
Edit the reference into a reusable empty tavern background. Remove both actual human characters (the female bartender and seated male card player) completely, reconstruct their hidden room/bar/chair surfaces naturally. Keep the exact camera crop, room geometry, table heights, front bar and tables, chairs, barrels, lamps, wall notices, window view and lighting. No actual living people or silhouettes anywhere. Printed illustrations on old wanted notices may remain as props. Preserve aspect ratio, visual style, all foreground furniture and objects. No UI or new text.
```

### HomeTavernPanoramaEmpty20260929

类型：background；尺寸：1672 × 941。

```text
Edit the reference into a reusable empty tavern background. Remove both actual human characters (the female bartender and seated male card player) completely, reconstruct their hidden room/bar/chair surfaces naturally. Keep the exact camera crop, room geometry, table heights, front bar and tables, chairs, barrels, lamps, wall notices, window view and lighting. No actual living people or silhouettes anywhere. Printed illustrations on old wanted notices may remain as props. Preserve aspect ratio, visual style, all foreground furniture and objects. No UI or new text.
```

### HomeTavernKeeper20260929

类型：character；尺寸：1024 × 1536。

```text
Extract ONLY the female bartender on the left of the reference into a standalone transparent character sprite. Preserve her brown braided hair, golden eyes, white blouse, dark bodice, red sash, friendly face and anime illustration style. Pose upright, slight friendly lean, one hand on hip; portrait top of complete head to mid-thigh, both arms entirely visible, ample transparent padding. Remove room, wall notices, bar, tables, background, seated male and all other props. Actual alpha transparency around character, no solid color or checkerboard. No counter or furniture, no text, no watermark.
```

### HomeOldSailor20260929

类型：character；尺寸：1024 × 1536。

```text
Create one transparent character layer for a fantasy harbor game: an elderly dock sailor with windburned face, bushy grey beard, weathered blue pea coat, knitted dark cap and white sea scarf, friendly shrewd eyes. Holding a small fan of plain old playing cards at waist height. Warm detailed painterly semi realistic illustration matching historic European coastal harbor interiors, golden light from upper left. Full head to mid-thigh, both arms and hands fully included, centered with transparent margin. Actual alpha transparency, no floor, backdrop, scenery, counter or other people, no text or watermark.
```
