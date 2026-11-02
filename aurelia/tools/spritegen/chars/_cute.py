"""Shared pixel-face helpers for the cute monsters (painted AFTER downsampling, pixel by pixel)."""

DARK = (38, 22, 40)
WHITE = (255, 255, 255)


def put(buf, x, y, col, ok_mats):
    h, w = buf["filled"].shape
    if 0 <= x < w and 0 <= y < h and buf["filled"][y, x] and buf["mat"][y, x] in ok_mats:
        buf["rgba"][y, x, :3] = col


def eyes(buf, ok, fx, fy, expr, ew, eh, ex, dark=DARK, glint=WHITE, brow=(66, 34, 40)):
    """Two eyes centred on (fx, fy). ew x eh pixels each, ex = centre-to-outer-edge distance."""
    xl = fx - ex
    xr = fx + ex - ew + 1
    y0 = fy

    def both(pts, col):
        for dx, dy in pts:
            put(buf, xl + dx, y0 + dy, col, ok)
            put(buf, xr + (ew - 1 - dx), y0 + dy, col, ok)

    block = [(dx, dy) for dx in range(ew) for dy in range(eh)]
    if expr in ("neutral", "happy_open"):
        both(block, dark)
        both([(0, 0)], glint)
        if eh >= 4:
            both([(ew - 1, eh - 1)], (150, 130, 190))
    elif expr == "blink":
        both([(dx, eh // 2) for dx in range(ew)], dark)
    elif expr == "angry":
        both([(dx, dy) for dx in range(ew) for dy in range(1, eh)], dark)
        both([(ew - 1, 1)], glint)
        outer = [(-1, -2), (0, -2)]
        inner = [(dx, -1) for dx in range(1, ew + 1)]
        both(outer + inner, brow)
    elif expr == "hurt":
        if eh >= 4:
            both([(0, 0), (1, 1), (1, 2), (0, 3)], dark)
        else:
            both([(0, 0), (1, 1), (0, 2)], dark)
    elif expr == "dead":
        both([(-1 + 0, 0), (1, 0), (0, 1), (-1, 2), (1, 2)] if ew == 2 else [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)], dark)
    elif expr == "happy":
        both([(0, 1), (1, 0)] + ([(2, 1)] if ew >= 3 else []), dark)
    else:
        both(block, dark)
