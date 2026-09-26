"""Render a few sample frames from render.py to check layout / contrast before the full pass."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render import frame_at

TIMES = [0.6, 1.8, 2.8, 3.2, 4.5, 6.0, 7.9, 8.4, 10.0, 12.4, 12.7, 14.0, 16.8, 17.4, 18.5, 19.6]

out = Path(__file__).resolve().parent / "previews"
out.mkdir(exist_ok=True)
for t in TIMES:
    img = frame_at(t).convert("RGB")
    img.save(out / f"t_{t:05.2f}.png")
    print("wrote", t)
