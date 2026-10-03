"""Prepare wider I2V references for the user's full-body throw request."""
import hashlib, json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[2]
base = root / 'docs/development/hero-ai-animation-20261002'
out = base / 'motion-library/full-body'
out.mkdir(exist_ok=True)
outfits = ['mistport-night', 'starlight-magician', 'midnight-carnival']
style = (
    '[Static shot] Animate the supplied detailed hand-painted 2D fantasy character. '
    'Preserve his hairstyle, slender proportions, original costume colors, gold embroidery, '
    'jewels, fabric folds and fine ink lines. No glossy CGI, no plastic 3D look. '
    'A locked full-body camera sees him from behind, with the broad empty margins in this image. '
    'He may turn naturally to a rear three-quarter angle during the gesture, but never turns '
    'all the way toward the viewer. Keep the entire moving body, fingers, coat tails and boots '
    'inside the frame. The camera and plain warm-gray background never move. '
    'One coherent athletic action with a short wind-up, a very decisive release and natural '
    'follow-through, then return to a balanced relaxed standing pose. '
    'Legs, pelvis, ribcage, shoulders and arms move together as one anatomical chain. '
    'The feet must visibly step and transfer weight; this must not be an arm-only wave. '
    'Boots make clear contact with the floor, no floating. Hair, coat and ribbons lag behind '
    'the body then settle. No camera movement, cuts, zoom, text, scenery, particles or glow. '
)
actions = [
    {
        'id': '03-overarm-throw', 'title': '踏步过肩投掷',
        'suggestedSpell': '身份错置', 'runtimeSkillID': 'identityDisplacement',
        'motionPrompt': (
            'A powerful forward OVERARM THROW of one small dark tarot card. '
            'Starting relaxed, he shifts his right foot back half a step, flexes both knees, '
            'and winds his right hand up beside and just behind his right ear, with a bent elbow. '
            'The torso coils slightly to the right; the left arm points toward the target ahead. '
            'He then plants the LEFT foot forward, drives his right hip and shoulder forward, '
            'and throws the card OVER the right shoulder toward an unseen target straight ahead '
            'and away from the camera. The rear heel lifts as weight transfers to the front leg. '
            'The throwing arm follows down across the front of his chest, partly occluded by '
            'his torso from this rear camera. His whole body leans forward briefly, then recovers '
            'and brings the feet back to a balanced stance. The released card is tiny and flies '
            'away quickly; the full-body throw is the focus. No giant props or additional cards.'
        )
    },
    {
        'id': '05-sidearm-cast', 'title': '侧跨转腰甩投',
        'suggestedSpell': '双影追猎', 'runtimeSkillID': 'mirrorPursuit',
        'motionPrompt': (
            'A sweeping SIDEARM CARD THROW powered by a lateral step and waist rotation. '
            'He first lowers his center of gravity, bending both knees and gathering his right '
            'hand beside his right hip while holding one small dark tarot card. '
            'He makes a clear step to the LEFT, plants the left boot, rotates his pelvis and '
            'chest toward the target ahead, and whips the right forearm forward at waist height '
            'to release the card. The right elbow stays softly bent, not hyperextended. '
            'The left arm opens at low height for balance; the right heel pivots naturally. '
            'The sweeping follow-through turns the upper body to a rear three-quarter angle '
            'and fans the coat tails. He then draws the rear foot inward, straightens and settles '
            'into a relaxed stable stance. It is a quick athletic casting step, not a dance, '
            'not a spin and not a standing symmetrical arm wave. Keep both hands in frame.'
        )
    }
]
for action in actions:
    action['prompt'] = style + ' ACTION: ' + action['motionPrompt']
    action['suggestedPreviewRate'] = 3
    for outfit in outfits:
        folder = out / (action['id'] + '-' + outfit)
        folder.mkdir(exist_ok=True)
        source = root / 'docs/development/hero-refinement-20261001/v4/reference' / (outfit + '-back-4k.png')
        character = Image.open(source).convert('RGBA')
        canvas = Image.new('RGBA', (3200, 4400), (218, 216, 211, 255))
        canvas.alpha_composite(character, ((3200 - character.width)//2, (4400 - character.height)//2))
        canvas.convert('RGB').save(folder / 'input.png')
        metadata = {'model': 'MiniMax-Hailuo-2.3', 'duration': 6, 'resolution': '1080P',
            'prompt_optimizer': False, 'prompt': action['prompt'], 'input': 'input.png',
            'inputSHA256': hashlib.sha256((folder / 'input.png').read_bytes()).hexdigest(),
            'source': str(source.relative_to(root)), 'sourceSHA256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'inputPreparation': 'Original character pixels unchanged; wider and taller gray canvas for complete step/throw framing.',
            'suggestedSpell': action['suggestedSpell'], 'runtimeSkillID': action['runtimeSkillID']}
        (folder / 'request.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
(out / 'actions.json').write_text(json.dumps({'outfits': outfits, 'actions': actions,
    'scope': 'Two candidate full-body gestures per outfit, to select into the five-per-outfit library.'}, ensure_ascii=False, indent=2) + '\n')
print('Prepared six full-body throw references and prompts.')
