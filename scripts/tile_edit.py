import os
import pygame as pg
import math

"""
tool for generating a .json to hold tile info
the UI code is garbage. do not look too closely.

how to use:
- click a tile on the tilemap to choose it
- name it, choose a palette foreground and background, and click save
- click a tile on the left panel and press the delete key to delete it

"""

FILEPATH = PALPATH = TSIZE = None
STUFF = {}

def asset_path(fname):
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "..\\assets\\" + fname)

def load_palette():
    palette = []

    with open(PALPATH, "r") as f:
        for line in f.readlines()[3:]:
            palette.append([int(v) for v in line.split()])

    return palette

def check_f(fpath, ext):
    if not fpath.endswith(ext):
        raise Exception("that's not a %s file, not cool my dude" % (ext,))
    return fpath

# todo json stuff

def main():
    global FILEPATH, PALPATH, TSIZE, STUFF
    FILEPATH = check_f(asset_path("urizen_basic.png"), ".png") # input("please enter tilemap filepath in \\assets\\: ")
    PALPATH = check_f(asset_path("elemental.pal"), ".pal") # input("please enter palette filepath in \\assets\\: ")
    TSIZE = 12, 12

    scale = 3
    ux, uy = 200, 50

    pg.init()
    pal = load_palette()
    img = pg.image.load(FILEPATH)
    screen = pg.display.set_mode((img.get_width() * scale + ux, img.get_height() * scale + uy))
    pg.display.set_caption("tile editor")
    font = pg.font.SysFont("InputMono", 20)
    timer = pg.time.Clock()
    t = 0

    panel = screen.subsurface((0, uy, ux, screen.get_height() - uy))

    bar = screen.subsurface((0, 0, screen.get_width(), uy))

    textbox = (uy + 10, 10, 180, 30)
    text = "~name~"

    in_box = lambda x, y, box: (box[0] <= x < box[0] + box[2]) and (box[1] <= y < box[1] + box[3])
    can_type = False

    select = (0, 0)

    while True:
        for e in pg.event.get():
            if e.type == pg.QUIT:
                pg.quit()
                exit(0)
            elif e.type == pg.MOUSEBUTTONDOWN:
                if e.button == 1:
                    can_type = in_box(*e.pos, textbox)

                    if in_box(*e.pos, (ux, uy, screen.get_width() - ux, screen.get_height() - uy)):
                        select = (int((e.pos[0] - ux) / (TSIZE[0] * scale)), int((e.pos[1] - uy) / (TSIZE[1] * scale)))
                    #elif in_box()
            elif e.type == pg.KEYDOWN:
                if e.key == pg.K_ESCAPE or e.key == pg.K_RETURN:
                    can_type = False

        timer.tick(30)
        t = (t + timer.get_time()) % 1000

        screen.fill((0, 0, 0))

        # upd bar
        bar.fill((50, 50, 50))

        pg.draw.rect(bar, [75*can_type]*3, textbox)
        bar.blit(font.render(text, 1, (255, 255, 255)), (textbox[0] + 5, textbox[1] + 5))

        # upd panel
        panel.fill((25, 25, 25))

        # upd image
        screen.blit(pg.transform.scale(img, (img.get_width() * 3, img.get_height() * 3)), (ux, uy))

        # this draws the squiggly select circle :)
        center = [(ux,uy)[i] + (select[i] + .5) * (TSIZE[i] * scale) for i in range(2)]
        pg.draw.polygon(screen, (200, 150, 25),
            [(center[0] + math.cos((i/50) * math.pi) * (TSIZE[0] * .8 * scale) * (1 + math.sin((t/500 + i/5) * math.pi) * .05),
              center[1] + math.sin((i/50) * math.pi) * (TSIZE[1] * .8 * scale) * (1 + math.sin((t/500 + i/5) * math.pi) * .05)) for i in range(100)], 5)

        pg.display.flip()

if __name__ == '__main__':
    main()
