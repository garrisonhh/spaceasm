import os
import pygame as pg
import math

"""
tool for generating a .json to hold tile info
the UI code is garbage don't investigate lol

how to use:
- click a tile on the tilemap to choose it
- name it
- click the palette checkbox to enable palette
    - choose a fg (left click) and bg (right click) palette color
- click save
- click a tile on the left panel and press the delete key to delete it
"""

PALENABLE = False
FILEPATH = PALPATH = TSIZE = SCALE = None
STUFF = [] # list of tuple: (name, {"preview" : surf, "loc" : select, "fg" : fg, "bg" : bg})

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

def toggle_palenable():
    global PALENABLE
    PALENABLE = not PALENABLE

# used to update preview
def make_preview(img, select, scsize, fgcolor, bgcolor):
    surf = img.subsurface((select[0] * TSIZE[0], select[1] * TSIZE[1], *TSIZE))

    preview = None

    if PALENABLE:
        preview = pg.Surface(surf.get_size())
        preview.fill(bgcolor)

        # this is slower than using a pixelarray, but I don't feel like figuring out that whole deal rn
        for y in range(surf.get_height()):
            for x in range(surf.get_width()):
                if surf.get_at((x, y))[0] > 128: # checks red channel
                    preview.set_at((x, y), fgcolor)
    else:
        preview = surf

    return pg.transform.scale(preview, scsize)

def save_tmap():
    pass # todo json stuff here

def main():
    global FILEPATH, PALPATH, TSIZE, SCALE, STUFF
    FILEPATH = check_f(asset_path("urizen_basic.png"), ".png") # input("please enter tilemap filepath in \\assets\\: ")
    PALPATH = check_f(asset_path("elemental.pal"), ".pal") # input("please enter palette filepath in \\assets\\: ")
    TSIZE = 12, 12 # input()
    SCALE = 3 # input()

    ux, uy = 200, 100

    pg.init()
    pal = load_palette()
    img = pg.image.load(FILEPATH)
    screen = pg.display.set_mode((max(img.get_width() * SCALE + ux, 800), max(img.get_height() * SCALE + uy, 600)))
    pg.display.set_caption("tile editor")
    font = pg.font.SysFont("Consolas", 24)
    smallfont = pg.font.SysFont("Consolas", 16)
    timer = pg.time.Clock()
    t = 0

    panel = screen.subsurface((0, uy, ux, screen.get_height() - uy))

    bar = screen.subsurface((0, 0, screen.get_width(), uy))

    savetxt = font.render("save", 1, (255, 255, 255))
    savebox = (uy, 10, savetxt.get_width() + 20, 40)
    savehl = False

    textbox = (savebox[0] + savebox[2] + 10, 10, screen.get_width() - savebox[2] - uy - 20, 40)
    text = ""

    paltickbox = (uy, 60, 30, 30)
    palbox = ((paltickbox[0] + paltickbox[2]) + 10, paltickbox[1], len(pal) * 30, 30)
    fg, bg = 1, 0

    in_box = lambda x, y, box: (box[0] <= x < box[0] + box[2]) and (box[1] <= y < box[1] + box[3])
    can_type = False

    select = (0, 0)

    preview = None
    upd_preview = lambda: make_preview(img, select, (uy - 20, uy - 20), pal[fg], pal[bg])
    preview = upd_preview()

    while True:
        for e in pg.event.get():
            if e.type == pg.QUIT:
                pg.quit()
                exit(0)
            elif e.type == pg.MOUSEBUTTONDOWN:
                if e.button == 1 or e.button == 3:
                    can_type = in_box(*e.pos, textbox)

                    if can_type:
                        pg.key.start_text_input()
                    else:
                        pg.key.stop_text_input()

                    if in_box(*e.pos, (ux, uy, *img.get_size())):
                        select = (int((e.pos[0] - ux) / (TSIZE[0] * SCALE)), int((e.pos[1] - uy) / (TSIZE[1] * SCALE)))
                        preview = upd_preview()
                    elif in_box(*e.pos, paltickbox):
                        toggle_palenable()
                        preview = upd_preview()
                    elif PALENABLE and in_box(*e.pos, palbox):
                        v = int((e.pos[0] - palbox[0]) / 30)
                        if e.button == 1:
                            fg = v
                        else: # rclick
                            bg = v
                        preview = upd_preview()
                    elif in_box(*e.pos, savebox):
                        savehl = True
                        if len(text) > 0:
                            STUFF.insert(0, (text, {
                                "preview" : make_preview(img, select, (TSIZE[0] * SCALE, TSIZE[1] * SCALE), pal[fg], pal[bg]),
                                "loc" : select,
                                "fg" : fg,
                                "bg" : bg
                            }))
                            text = ""
            elif e.type == pg.MOUSEBUTTONUP and savehl:
                savehl = False
            elif e.type == pg.KEYDOWN:
                if e.key == pg.K_ESCAPE or e.key == pg.K_RETURN:
                    can_type = False
                    pg.key.stop_text_input()
                elif can_type:
                    if e.key == pg.K_DELETE:
                        text = ""
                    elif e.key == pg.K_BACKSPACE:
                        text = text[:-1]
            elif e.type == pg.TEXTINPUT:
                if e.text.isalnum() or e.text == '_':
                    text += e.text

        timer.tick(60)
        t = (t + timer.get_time()) % 1000

        screen.fill((0, 0, 0))

        # === upd bar ===
        bar.fill((50, 50, 50))

        # preview
        bar.blit(preview, (10, 10))

        # save btn
        pg.draw.rect(bar, [75*(not savehl)]*3, savebox)
        bar.blit(savetxt, (savebox[0] + 10, savebox[1] + 8))

        # name
        pg.draw.rect(bar, [75*can_type]*3, textbox)

        if len(text) != 0:
            bar.blit(font.render(text, 1, (255, 255, 255)), (textbox[0] + 8, textbox[1] + 8))
        else:
            bar.blit(font.render("~tile name~", 1, (127, 127, 127)), (textbox[0] + 8, textbox[1] + 8))

        # palette chooser
        pg.draw.rect(bar, (255, 255, 255), paltickbox)

        if PALENABLE:
            pg.draw.rect(bar, (75, 75, 75),
                (paltickbox[0] + 10, paltickbox[1] + 10, paltickbox[2] - 20, paltickbox[2] - 20))

            for i in range(len(pal)):
                pg.draw.rect(bar, pal[i], (palbox[0] + i * 30, palbox[1], 30, palbox[3]))

            pg.draw.polygon(bar, (255, 255, 255), [(palbox[0] + fg * 30 + x, palbox[1] + y) for x, y in ((10, -5), (20, -5), (15, 5))])
            pg.draw.polygon(bar, (255, 255, 255), [(palbox[0] + bg * 30 + x, palbox[1] + y) for x, y in ((10, 35), (20, 35), (15, 25))])

        # === upd panel ===
        panel.fill((25, 25, 25))
        pw, ph = (TSIZE[0] * SCALE, TSIZE[1] * SCALE)

        for i in range(len(STUFF)):
            name, info = STUFF[i]
            panel.blit(info["preview"], (0, i * ph))
            panel.blit(smallfont.render(name, 1, (255, 255, 255)), (pw + 10, i * ph + int((ph - 16) / 2)))

        # === upd image ===
        screen.blit(pg.transform.scale(img, (img.get_width() * 3, img.get_height() * 3)), (ux, uy))

        # this draws the squiggly select circle :)
        center = [(ux,uy)[i] + (select[i] + .5) * (TSIZE[i] * SCALE) for i in range(2)]
        pg.draw.polygon(screen, (200, 150, 25),
            [(center[0] + math.cos((i/50) * math.pi) * (TSIZE[0] * .8 * SCALE) * (1 + math.sin((t/500 + i/5) * math.pi) * .05),
              center[1] + math.sin((i/50) * math.pi) * (TSIZE[1] * .8 * SCALE) * (1 + math.sin((t/500 + i/5) * math.pi) * .05)) for i in range(100)], 5)

        pg.display.flip()

if __name__ == '__main__':
    main()
