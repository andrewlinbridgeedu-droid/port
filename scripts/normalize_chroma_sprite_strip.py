#!/usr/bin/env python3
"""Convert a green-screen horizontal strip into anchored RGBA game frames.

This is for painted mobile-game sprites (not pixel art): every slot is keyed,
cropped, resized with one shared scale, and aligned to the same bottom-center
anchor so animation never changes apparent character size or foot position.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--frames", type=int, required=True)
    parser.add_argument("--frame-size", type=int, default=512)
    parser.add_argument("--padding", type=int, default=20)
    parser.add_argument(
        "--source-alpha",
        action="store_true",
        help="Input already has a validated alpha channel; skip chroma removal.",
    )
    parser.add_argument(
        "--target-height",
        type=int,
        help=(
            "Normalize the tallest frame to this exact pixel height. Useful "
            "for matching an approved idle clip without changing its anchor."
        ),
    )
    parser.add_argument("--prefix", default="frame")
    parser.add_argument(
        "--largest-component-only",
        action="store_true",
        help="Remove detached generation debris and keep the main sprite body.",
    )
    return parser.parse_args()


def remove_green(image: Image.Image) -> Image.Image:
    source = image.convert("RGBA")
    output = Image.new("RGBA", source.size)
    keyed: list[tuple[int, int, int, int]] = []

    for red, green, blue, alpha in source.getdata():
        dominance = green - max(red, blue)
        if green > 72 and dominance > 12:
            # Generated chroma backgrounds are not perfectly flat. A soft
            # transition retains antialiased brass edges without a green halo.
            retained = max(0.0, min(1.0, (70.0 - dominance) / 48.0))
            alpha = int(alpha * retained)
            if alpha:
                green = min(green, max(red, blue) + 10)
        keyed.append((red, green, blue, alpha))

    output.putdata(keyed)
    return output


def content_box(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A").point(lambda value: 255 if value > 8 else 0)
    box = alpha.getbbox()
    if box is None:
        raise ValueError("No sprite content detected after chroma keying")
    return box


def keep_largest_component(image: Image.Image) -> Image.Image:
    """Keep the largest 8-connected alpha component in a keyed slot."""
    width, height = image.size
    alpha = image.getchannel("A")
    active = bytearray(1 if value > 8 else 0 for value in alpha.getdata())
    visited = bytearray(width * height)
    largest: list[int] = []

    for seed in range(width * height):
        if not active[seed] or visited[seed]:
            continue
        visited[seed] = 1
        stack = [seed]
        component: list[int] = []
        while stack:
            index = stack.pop()
            component.append(index)
            x, y = index % width, index // width
            for ny in range(max(0, y - 1), min(height, y + 2)):
                for nx in range(max(0, x - 1), min(width, x + 2)):
                    neighbor = ny * width + nx
                    if active[neighbor] and not visited[neighbor]:
                        visited[neighbor] = 1
                        stack.append(neighbor)
        if len(component) > len(largest):
            largest = component

    if not largest:
        return image
    keep = bytearray(width * height)
    for index in largest:
        keep[index] = 1
    pixels = list(image.getdata())
    image.putdata([
        pixel if keep[index] else (pixel[0], pixel[1], pixel[2], 0)
        for index, pixel in enumerate(pixels)
    ])
    return image


def main() -> None:
    args = arguments()
    if args.frames < 1 or args.frame_size < 1:
        raise SystemExit("frames and frame-size must be positive")

    strip = Image.open(args.input).convert("RGBA")
    slots: list[Image.Image] = []
    boxes: list[tuple[int, int, int, int]] = []
    step = strip.width / args.frames
    for index in range(args.frames):
        left = round(index * step)
        right = round((index + 1) * step)
        source = strip.crop((left, 0, right, strip.height))
        keyed = source if args.source_alpha else remove_green(source)
        if args.largest_component_only:
            keyed = keep_largest_component(keyed)
        slots.append(keyed)
        boxes.append(content_box(keyed))

    max_width = max(right - left for left, _, right, _ in boxes)
    max_height = max(bottom - top for _, top, _, bottom in boxes)
    available = args.frame_size - args.padding * 2
    if args.target_height is not None:
        if args.target_height < 1 or args.target_height > available:
            raise SystemExit("target-height must fit inside frame-size and padding")
        shared_scale = min(
            args.target_height / max_height,
            available / max_width,
        )
    else:
        shared_scale = min(available / max_width, available / max_height)

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    for index, (slot, box) in enumerate(zip(slots, boxes), start=1):
        sprite = slot.crop(box)
        width = max(1, round(sprite.width * shared_scale))
        height = max(1, round(sprite.height * shared_scale))
        sprite = sprite.resize((width, height), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (args.frame_size, args.frame_size), (0, 0, 0, 0))
        x = (args.frame_size - width) // 2
        y = args.frame_size - args.padding - height
        canvas.alpha_composite(sprite, (x, y))
        canvas.save(out_dir / f"{args.prefix}{index:02d}.png", optimize=True)


if __name__ == "__main__":
    main()
