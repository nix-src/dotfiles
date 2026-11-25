#!/usr/bin/env python3
"""Генератор минималистичных анимированных обоев.

Сетка тусклых точек на почти чёрном фоне, по которой медленно дрейфуют два
мягких «пятна света». Анимация зациклена без шва. Только stdlib + ffmpeg.

    generate.py OUT_DIR [--size 1920x1080] [--fps 20] [--seconds 24]

Создаёт OUT_DIR/drift.mp4 (видео для mpvpaper) и OUT_DIR/drift.png (кадр
для экрана блокировки и SDDM).
"""
import argparse
import math
import os
import random
import subprocess
import sys

BG = 11            # фон  (#0b0b0b)
DOT = 34           # базовая яркость точки
GLOW = 140          # прибавка яркости в центре пятна
SPACING = 36       # шаг сетки, px


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("out_dir")
    ap.add_argument("--size", default="1920x1080")
    ap.add_argument("--fps", type=int, default=20)
    ap.add_argument("--seconds", type=int, default=24)
    args = ap.parse_args()

    w, h = (int(v) for v in args.size.lower().split("x"))
    frames = args.fps * args.seconds
    os.makedirs(args.out_dir, exist_ok=True)
    video = os.path.join(args.out_dir, "drift.mp4")
    still = os.path.join(args.out_dir, "drift.png")

    rnd = random.Random(7)
    ox = (w % SPACING) // 2 + SPACING // 2
    oy = (h % SPACING) // 2 + SPACING // 2
    dots = [(x, y, rnd.random()) for y in range(oy, h, SPACING) for x in range(ox, w, SPACING)]
    sigma2 = 2 * (min(w, h) * 0.28) ** 2

    def blobs(t: float):
        a = 2 * math.pi * t
        # Лиссажу с целыми частотами -> бесшовная петля
        return (
            (w * (0.5 + 0.32 * math.cos(a)),        h * (0.5 + 0.30 * math.sin(2 * a))),
            (w * (0.5 + 0.30 * math.sin(a + 1.9)),  h * (0.5 + 0.28 * math.cos(a + 0.7))),
        )

    def render(t: float) -> bytes:
        buf = bytearray([BG]) * (w * h)
        (b1x, b1y), (b2x, b2y) = blobs(t)
        tw = 2 * math.pi * t
        for x, y, ph in dots:
            g = math.exp(-((x - b1x) ** 2 + (y - b1y) ** 2) / sigma2) \
                + 0.7 * math.exp(-((x - b2x) ** 2 + (y - b2y) ** 2) / sigma2)
            v = DOT + GLOW * min(g, 1.0) + 5 * math.sin(3 * tw + ph * 6.283)
            c = int(max(BG, min(255, v)))
            e = (c + BG) // 2
            i = y * w + x
            buf[i] = c
            buf[i - 1] = buf[i + 1] = buf[i - w] = buf[i + w] = e
        return bytes(buf)

    enc = subprocess.Popen(
        ["ffmpeg", "-loglevel", "error", "-y",
         "-f", "rawvideo", "-pix_fmt", "gray", "-s", f"{w}x{h}", "-r", str(args.fps), "-i", "-",
         "-c:v", "libx264", "-preset", "medium", "-crf", "24", "-pix_fmt", "yuv420p",
         "-movflags", "+faststart", video],
        stdin=subprocess.PIPE,
    )
    for n in range(frames):
        enc.stdin.write(render(n / frames))
    enc.stdin.close()
    if enc.wait() != 0:
        print("ffmpeg: ошибка кодирования видео", file=sys.stderr)
        return 1

    png = subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-y",
         "-f", "rawvideo", "-pix_fmt", "gray", "-s", f"{w}x{h}", "-i", "-",
         "-frames:v", "1", still],
        input=render(0.0),
    )
    return png.returncode


if __name__ == "__main__":
    sys.exit(main())
