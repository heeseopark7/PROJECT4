import numpy as np
from PIL import Image
def invert_hc(im):
    a = np.asarray(im.convert('RGB')).astype(np.float32) / 255.0
    n = 1.0 - a
    hsv = np.asarray(Image.fromarray((n * 255).astype(np.uint8)).convert('HSV')).astype(np.float32)
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    h = (h + 128) % 256                       # keep the original hue
    lo, hi = np.percentile(v, 0.5), np.percentile(v, 99.5)
    v = np.clip((v - lo) / max(hi - lo, 1) * 255, 0, 255)
    sat = s > 70                               # colored text: darken for print contrast
    v = np.where(sat, v * 0.62, v)
    s = np.where(sat, np.minimum(s * 1.15, 255), s)
    bg = (v > 215) & (s < 60)                  # near-white background -> pure white
    v = np.where(bg, 255, v); s = np.where(bg, 0, s)
    out = np.stack([h, s, v], -1).astype(np.uint8)
    return Image.fromarray(out, 'HSV').convert('RGB')
