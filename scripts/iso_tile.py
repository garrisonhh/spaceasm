import os
import sys
import pygame as pg

"""
cli tool to generate an isometric block from a square image

TODO borders?
"""

def asset_path(fname):
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "..\\assets\\" + fname)

def load_image(fname):
    return pg.image.load(asset_path(fname))

def image_input(which):
    return load_image(input("(%s) enter relative path to \\assets\\:\n> " % (which,)))

"""
each pixel is spread out over a 4x1 area, so image gets a lot larger (but zero info lost!)
size w, h -> (w * 4, h * 4 - 1)
    - if side is different (topw * 4, toph * 2 + sideh * 2 - 1)
"""
def convert_lossless(top, side):
    tw, th = top.get_size()
    sw, sh = side.get_size()

    if tw != th: raise Exception("top must be square.")
    if sw != tw: raise Exception("top width, height and side width must all be the same.")

    surf = pg.Surface((tw * 4, (th * 2 - 1) + (sh * 2)), flags = pg.SRCALPHA)

    for y in range(th):
        for x in range(tw):
            c = top.get_at((x, y))

            sy = x + y
            sx = (tw + x - y) * 2
            for i in range(-2, 2):
                surf.set_at((sx + i, sy), c)

    for y in range(sh):
        for x in range(sw):
            s1 = x * 2, th + y * 2 + x
            s2 = (th + x) * 2, (th * 2 - 1) + y * 2 - x

            pg.draw.rect(surf, side.get_at((x, y)), (*s1, 2, 2))
            pg.draw.rect(surf, side.get_at((x, y)), (*s2, 2, 2))

    return surf

def main():
    if not (3 <= len(sys.argv) <= 5):
        raise Exception("bad arguments; valid arguments: \\top \\side \\dest\n\\top \\dest\n-m \\map \\size \\dest")

    pg.init()
    pg.display.set_mode(flags=pg.HIDDEN)

    if sys.argv[1] == '-m': # tilemap
        tmap = load_image(sys.argv[2])

        size = int(sys.argv[3])
        w, h = int(tmap.get_width() / size), int(tmap.get_height() / size)
        bdims = (size * 4, size * 4 - 1)
        surf = pg.Surface((bdims[0] * w, bdims[1] * h), flags = pg.SRCALPHA)

        for y in range(h):
            for x in range(w):
                tile = tmap.subsurface((x * size, y * size, size, size))
                surf.blit(convert_lossless(tile, tile), (x * bdims[0], y * bdims[1]))

        pg.image.save(surf, asset_path(sys.argv[4]))
    else: # 1 block
        top = load_image(sys.argv[1])

        side = None
        if len(sys.argv) == 4:
            side = load_image(sys.argv[2])
        else:
            side = top.copy()

        surf = convert_lossless(top, side)

        pg.image.save(surf, asset_path(sys.argv[3]))

if __name__ == '__main__':
    main()
