import json
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "icons")

S = 240          # final canvas size (matches avatars)
K = 4            # supersample factor for anti-aliasing
W = 18           # stroke width in 240-space
COL = (23, 23, 23, 255)


def rot(x, y, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return x * c - y * s, x * s + y * c


class Icon:
    def __init__(self):
        self.im = Image.new("RGBA", (S * K, S * K), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    # ---- primitives (coords in 240-space) ----
    def _k(self, pts):
        return [(x * K, y * K) for x, y in pts]

    def cap(self, x, y, r=None):
        r = (r or W / 2) * K
        self.d.ellipse((x * K - r, y * K - r, x * K + r, y * K + r), fill=COL)

    def line(self, x1, y1, x2, y2, w=None):
        w = w or W
        self.d.line((x1 * K, y1 * K, x2 * K, y2 * K), fill=COL, width=w * K)
        self.cap(x1, y1, w / 2)
        self.cap(x2, y2, w / 2)

    def poly(self, pts, closed=False, w=None):
        pts = list(pts)
        if closed:
            pts = pts + [pts[0]]
        self.d.line(self._k(pts), fill=COL, width=(w or W) * K, joint="curve")
        self.cap(*pts[0], (w or W) / 2)
        self.cap(*pts[-1], (w or W) / 2)

    def circle(self, cx, cy, r, w=None):
        w = w or W
        self.d.ellipse(((cx - r) * K, (cy - r) * K, (cx + r) * K, (cy + r) * K),
                       outline=COL, width=w * K)

    def dot(self, cx, cy, r):
        self.d.ellipse(((cx - r) * K, (cy - r) * K, (cx + r) * K, (cy + r) * K), fill=COL)

    def arc(self, cx, cy, r, a1, a2, caps=True, w=None):
        """Angles in degrees, screen coords (y down): 0=right, 90=bottom, 270=top."""
        if a2 < a1:
            a2 += 360
        self.d.arc(((cx - r) * K, (cy - r) * K, (cx + r) * K, (cy + r) * K),
                   a1, a2, fill=COL, width=(w or W) * K)
        if caps:
            for a in (a1, a2):
                ar = math.radians(a)
                self.cap(cx + r * math.cos(ar), cy + r * math.sin(ar), (w or W) / 2)

    def rrect(self, x1, y1, x2, y2, rad, w=None):
        self.d.rounded_rectangle((x1 * K, y1 * K, x2 * K, y2 * K), radius=rad * K,
                                 outline=COL, width=(w or W) * K)

    def polyfill(self, pts):
        self.d.polygon(self._k(pts), fill=COL)

    def rectfill(self, x1, y1, x2, y2, rad=0):
        if rad:
            self.d.rounded_rectangle((x1 * K, y1 * K, x2 * K, y2 * K), radius=rad * K, fill=COL)
        else:
            self.d.rectangle((x1 * K, y1 * K, x2 * K, y2 * K), fill=COL)

    def bezier(self, p0, c, p1, n=48):
        pts = []
        for i in range(n + 1):
            t = i / n
            u = 1 - t
            pts.append((u * u * p0[0] + 2 * u * t * c[0] + t * t * p1[0],
                        u * u * p0[1] + 2 * u * t * c[1] + t * t * p1[1]))
        return pts

    def save(self, path):
        im = self.im.resize((S, S), Image.LANCZOS)
        im.save(path)


def ray_line(ic, cx, cy, ang_deg, r1, r2, w=None):
    a = math.radians(ang_deg)
    ic.line(cx + r1 * math.cos(a), cy + r1 * math.sin(a),
            cx + r2 * math.cos(a), cy + r2 * math.sin(a), w)


# ---------------------------------------------------------------- ui
def i_home(ic):
    ic.poly([(48, 126), (128, 54), (208, 126)])
    ic.line(64, 118, 64, 200); ic.line(192, 118, 192, 200); ic.line(64, 200, 192, 200)
    ic.poly([(110, 200), (110, 158), (146, 158), (146, 200)])


def i_search(ic):
    ic.circle(112, 112, 56)
    ic.line(156, 156, 202, 202)


def i_settings(ic):
    for k in range(8):
        ray_line(ic, 128, 128, k * 45, 54, 84, w=24)
    ic.circle(128, 128, 58)
    ic.circle(128, 128, 22)


def i_user(ic):
    ic.circle(128, 92, 38)
    ic.arc(128, 214, 68, 180, 360)


def i_users(ic):
    ic.circle(174, 102, 27)
    ic.arc(174, 186, 38, 180, 360)
    ic.circle(94, 106, 36)
    ic.arc(94, 210, 52, 180, 360)


def i_heart(ic):
    s, cy = 5.0, 133
    pts = []
    for i in range(120):
        t = 2 * math.pi * i / 119
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((128 + x * s, cy + y * s))
    ic.poly(pts, closed=True)


def i_star(ic):
    pts = []
    for i in range(10):
        r = 88 if i % 2 == 0 else 37
        a = math.radians(-90 + i * 36)
        pts.append((128 + r * math.cos(a), 140 + r * math.sin(a)))
    ic.poly(pts, closed=True)


def i_bookmark(ic):
    ic.poly([(80, 48), (176, 48), (176, 208), (128, 164), (80, 208)], closed=True)


def i_bell(ic):
    ic.arc(128, 130, 50, 180, 360)
    ic.line(78, 130, 64, 172); ic.line(178, 130, 192, 172)
    ic.line(64, 172, 192, 172)
    ic.dot(128, 204, 11)


def i_lock(ic):
    ic.arc(128, 96, 36, 180, 360)
    ic.line(92, 96, 92, 116); ic.line(164, 96, 164, 116)
    ic.rrect(76, 116, 180, 208, 16)
    ic.dot(128, 152, 12)
    ic.line(128, 152, 128, 178)


def i_unlock(ic):
    ic.line(92, 96, 92, 116)
    ic.arc(128, 96, 36, 180, 300, caps=False)
    ic.line(146, 65, 170, 65)
    ic.rrect(76, 116, 180, 208, 16)
    ic.dot(128, 152, 12)
    ic.line(128, 152, 128, 178)


def i_eye(ic):
    top = ic.bezier((44, 128), (128, 36), (212, 128))
    bot = ic.bezier((212, 128), (128, 220), (44, 128))
    ic.poly(top + bot, closed=True)
    ic.circle(128, 128, 30)


def i_calendar(ic):
    ic.rrect(56, 72, 200, 208, 14)
    ic.line(56, 116, 200, 116)
    ic.line(92, 52, 92, 84); ic.line(164, 52, 164, 84)


def i_clock(ic):
    ic.circle(128, 128, 84)
    ic.line(128, 128, 128, 78)
    ic.line(128, 128, 166, 150)


def i_trash(ic):
    ic.line(60, 82, 196, 82)
    ic.poly([(104, 82), (104, 56), (152, 56), (152, 82)])
    ic.line(82, 82, 90, 206); ic.line(174, 82, 166, 206)
    ic.line(90, 206, 166, 206)
    ic.line(114, 132, 117, 186); ic.line(142, 132, 139, 186)


def i_edit(ic):
    tip = (64, 192)
    c1, c2 = (161.9, 65.9), (190.1, 94.1)
    ic.poly([tip, c1, c2], closed=True)
    ic.line(71.1, 156.7, 99.3, 184.9)
    ic.line(140.4, 87.4, 168.6, 115.6)


def i_plus(ic):
    ic.line(128, 64, 128, 192); ic.line(64, 128, 192, 128)


def i_minus(ic):
    ic.line(64, 128, 192, 128)


def i_check(ic):
    ic.poly([(64, 132), (112, 180), (196, 84)])


def i_close(ic):
    ic.line(72, 72, 184, 184); ic.line(184, 72, 72, 184)


def i_menu(ic):
    for y in (86, 126, 166):
        ic.line(64, y, 192, y)


def i_more_horizontal(ic):
    for x in (76, 128, 180):
        ic.dot(x, 128, 13)


def i_more_vertical(ic):
    for y in (76, 128, 180):
        ic.dot(128, y, 13)


def i_filter(ic):
    ic.poly([(56, 72), (200, 72), (146, 138), (146, 196), (110, 172), (110, 138)], closed=True)


def i_grid(ic):
    for x1 in (56, 136):
        for y1 in (56, 136):
            ic.rrect(x1, y1, x1 + 64, y1 + 64, 12)


def i_list(ic):
    for y in (86, 126, 166):
        ic.dot(72, y, 9)
        ic.line(104, y, 196, y)


def i_info(ic):
    ic.circle(128, 128, 84)
    ic.dot(128, 86, 10)
    ic.line(128, 118, 128, 174)


def i_help(ic):
    ic.circle(128, 128, 84)
    ic.arc(128, 114, 28, 180, 360, caps=False)
    ic.line(156, 114, 128, 150)
    ic.dot(128, 180, 9)


def i_warning(ic):
    ic.poly([(128, 58), (214, 198), (42, 198)], closed=True)
    ic.line(128, 110, 128, 152)
    ic.dot(128, 176, 9)


def i_shield(ic):
    ic.poly([(128, 54), (194, 80), (194, 142), (128, 206), (62, 142), (62, 80)], closed=True)


def i_key(ic):
    ic.circle(88, 128, 34)
    ic.line(122, 128, 202, 128)
    ic.line(170, 128, 170, 158); ic.line(198, 128, 198, 158)


# ---------------------------------------------------------------- arrows
def _arrow(ic, deg):
    a = math.radians(deg)
    dx, dy = math.cos(a), math.sin(a)
    px, py = -dy, dx
    tip = (128 + 78 * dx, 128 + 78 * dy)
    w1 = (128 + 24 * dx + 50 * px, 128 + 24 * dy + 50 * py)
    w2 = (128 + 24 * dx - 50 * px, 128 + 24 * dy - 50 * py)
    tail = (128 - 78 * dx, 128 - 78 * dy)
    knee = (128 + 26 * dx, 128 + 26 * dy)
    ic.line(tail[0], tail[1], knee[0], knee[1])
    ic.poly([w1, tip, w2])


def i_arrow_up(ic): _arrow(ic, -90)
def i_arrow_down(ic): _arrow(ic, 90)
def i_arrow_left(ic): _arrow(ic, 180)
def i_arrow_right(ic): _arrow(ic, 0)


def _chevron(ic, deg):
    a = math.radians(deg)
    dx, dy = math.cos(a), math.sin(a)
    px, py = -dy, dx
    tip = (128 + 52 * dx, 128 + 52 * dy)
    b1 = (128 - 8 * dx + 56 * px, 128 - 8 * dy + 56 * py)
    b2 = (128 - 8 * dx - 56 * px, 128 - 8 * dy - 56 * py)
    ic.poly([b1, tip, b2])


def i_chevron_up(ic): _chevron(ic, -90)
def i_chevron_down(ic): _chevron(ic, 90)
def i_chevron_left(ic): _chevron(ic, 180)
def i_chevron_right(ic): _chevron(ic, 0)


def i_refresh(ic):
    ic.arc(128, 128, 74, 300, 615, caps=False)
    ic.line(165, 64, 165, 102)
    ic.line(165, 64, 129, 64)


def i_external_link(ic):
    ic.poly([(176, 140), (176, 202), (62, 202), (62, 88), (118, 88)])
    ic.line(140, 116, 198, 58)
    ic.poly([(162, 58), (198, 58), (198, 94)])


def i_link(ic):
    ic.poly([(120, 88), (88, 88)])
    ic.arc(88, 128, 40, 90, 270, caps=False)
    ic.poly([(88, 168), (120, 168)])
    ic.poly([(136, 88), (168, 88)])
    ic.arc(168, 128, 40, 270, 450, caps=False)
    ic.poly([(168, 168), (136, 168)])


# ---------------------------------------------------------------- media
def i_play(ic):
    ic.polyfill([(88, 70), (188, 128), (88, 186)])


def i_pause(ic):
    ic.rectfill(78, 70, 110, 182, rad=8)
    ic.rectfill(146, 70, 178, 182, rad=8)


def i_stop(ic):
    ic.rectfill(78, 78, 178, 178, rad=14)


def i_skip_forward(ic):
    ic.polyfill([(76, 74), (154, 128), (76, 182)])
    ic.line(170, 74, 170, 182)


def i_skip_back(ic):
    ic.polyfill([(164, 74), (86, 128), (164, 182)])
    ic.line(70, 74, 70, 182)


def i_volume(ic):
    ic.polyfill([(52, 102), (86, 102), (124, 68), (124, 188), (86, 154), (52, 154)])
    ic.arc(126, 128, 34, 305, 415)
    ic.arc(126, 128, 60, 305, 415)


def i_mute(ic):
    ic.polyfill([(48, 102), (82, 102), (120, 68), (120, 188), (82, 154), (48, 154)])
    ic.line(150, 108, 196, 152)
    ic.line(196, 108, 150, 152)


def i_mic(ic):
    ic.rrect(104, 52, 152, 152, 24)
    ic.arc(128, 140, 52, 0, 180)
    ic.line(128, 192, 128, 212)
    ic.line(100, 212, 156, 212)


def i_camera(ic):
    ic.poly([(96, 96), (108, 76), (148, 76), (160, 96)])
    ic.rrect(48, 96, 208, 196, 16)
    ic.circle(128, 144, 30)
    ic.dot(178, 120, 7)


def i_video(ic):
    ic.rrect(44, 84, 168, 184, 14)
    ic.polyfill([(176, 110), (212, 90), (212, 178), (176, 158)])


def i_image(ic):
    ic.rrect(52, 60, 204, 196, 14)
    ic.circle(98, 104, 15)
    ic.poly([(60, 182), (112, 126), (140, 152), (168, 122), (196, 150)])


def i_music(ic):
    ic.dot(92, 178, 17); ic.dot(170, 162, 17)
    ic.line(107, 178, 107, 90); ic.line(185, 162, 185, 74)
    ic.line(107, 90, 185, 74)


# ---------------------------------------------------------------- files
def i_file(ic):
    ic.poly([(72, 48), (152, 48), (184, 80), (184, 208), (72, 208)], closed=True)
    ic.poly([(152, 48), (152, 80), (184, 80)])


def i_folder(ic):
    ic.poly([(52, 76), (104, 76), (122, 96), (196, 96), (196, 188), (52, 188)], closed=True)


def i_copy(ic):
    ic.rrect(92, 56, 196, 160, 12)
    ic.rrect(60, 96, 164, 200, 12)


def i_clipboard(ic):
    ic.rrect(64, 76, 192, 208, 14)
    ic.rrect(96, 42, 160, 76, 10)


def i_paperclip(ic):
    ic.arc(128, 90, 33, 180, 360)
    ic.line(95, 90, 95, 196)
    ic.line(161, 90, 161, 174)
    ic.arc(139, 174, 22, 0, 180)
    ic.line(117, 174, 117, 112)
    ic.arc(128, 112, 11, 180, 360, caps=False)
    ic.line(139, 112, 139, 150)


def i_download(ic):
    ic.poly([(56, 164), (56, 204), (200, 204), (200, 164)])
    ic.line(128, 48, 128, 148)
    ic.poly([(84, 104), (128, 148), (172, 104)])


def i_upload(ic):
    ic.poly([(56, 164), (56, 204), (200, 204), (200, 164)])
    ic.line(128, 156, 128, 56)
    ic.poly([(84, 100), (128, 56), (172, 100)])


def i_save(ic):
    ic.rrect(56, 56, 200, 200, 12)
    ic.poly([(106, 98), (106, 58), (150, 58), (150, 98)])
    ic.rrect(94, 138, 162, 190, 4)


# ---------------------------------------------------------------- comms
def i_mail(ic):
    ic.rrect(48, 72, 208, 184, 12)
    ic.poly([(52, 78), (128, 138), (204, 78)])


def i_phone(ic):
    ic.arc(128, 150, 64, 180, 360)
    ic.dot(64, 150, 18)
    ic.dot(192, 150, 18)


def i_chat(ic):
    ic.rrect(52, 64, 204, 172, 20)
    ic.polyfill([(88, 168), (78, 204), (126, 168)])


def i_send(ic):
    ic.poly([(208, 56), (48, 104), (116, 136), (208, 56)], closed=True)
    ic.poly([(116, 136), (160, 200), (208, 56)], closed=True)


def i_share(ic):
    nodes = [(176, 72), (64, 128), (176, 184)]
    for c in nodes:
        ic.circle(c[0], c[1], 22)
    for a, b in ((nodes[0], nodes[1]), (nodes[1], nodes[2])):
        dx, dy = b[0] - a[0], b[1] - a[1]
        d = math.hypot(dx, dy)
        ux, uy = dx / d, dy / d
        ic.line(a[0] + ux * 30, a[1] + uy * 30, b[0] - ux * 30, b[1] - uy * 30)


# ---------------------------------------------------------------- weather
def i_sun(ic):
    ic.circle(128, 128, 52)
    for k in range(8):
        ray_line(ic, 128, 128, k * 45, 70, 94)


def i_moon(ic):
    big = Image.new("L", (S * K, S * K), 0)
    d = ImageDraw.Draw(big)
    r = 76 * K
    d.ellipse((128 * K - r, 128 * K - r, 128 * K + r, 128 * K + r), fill=255)
    r2 = 64 * K
    d.ellipse((160 * K - r2, 108 * K - r2, 160 * K + r2, 108 * K + r2), fill=0)
    layer = Image.new("RGBA", (S * K, S * K), COL)
    out = Image.composite(layer, Image.new("RGBA", layer.size, (0, 0, 0, 0)), big)
    ic.im.alpha_composite(out)


_CLOUD_A = (96, 146, 28)
_CLOUD_B = (132, 120, 36)
_CLOUD_C = (164, 146, 26)


def _cloud(ic, scale=1.0, ox=0, oy=0):
    ax, ay, ar = _CLOUD_A
    bx, by, br = _CLOUD_B
    cx, cy_, cr = _CLOUD_C

    def tr(p):
        return (ox + p[0] * scale, oy + p[1] * scale)

    base_l = tr((ax - math.sqrt(ar ** 2 - (170 - ay) ** 2), 170))
    base_r = tr((cx + math.sqrt(cr ** 2 - (170 - cy_) ** 2), 170))
    ab_ang_a, ab_ang_b = 270.0, 183.2
    bc_ang_b, bc_ang_c = 0.6, 278.9
    c_ang_end = 67.4
    a_ang_start = 121.0

    def arc(c, r, a1, a2):
        cc = tr((c[0], c[1]))
        ic.arc(cc[0], cc[1], r * scale, a1, a2)

    arc(_CLOUD_A, ar, a_ang_start, ab_ang_a)
    arc(_CLOUD_B, br, ab_ang_b, bc_ang_b + 360 if bc_ang_b < ab_ang_b else bc_ang_b)
    arc(_CLOUD_C, cr, bc_ang_c, c_ang_end + 360 if c_ang_end < bc_ang_c else c_ang_end)
    p1, p2 = base_l, base_r
    ic.line(p1[0], p1[1], p2[0], p2[1])


def i_cloud(ic):
    _cloud(ic)


def i_rain(ic):
    _cloud(ic, scale=0.82, ox=128 - 130 * 0.82, oy=128 - 158 * 0.82)
    for x in (92, 128, 164):
        ic.line(x, 186, x - 12, 208)


def i_lightning(ic):
    ic.polyfill([(144, 48), (88, 140), (124, 140), (104, 208), (172, 112), (134, 112)])


def i_snowflake(ic):
    for k in range(3):
        a = k * 60
        ray_line(ic, 128, 128, a, -76, 76)
    for k in range(6):
        a = k * 60
        ar = math.radians(a)
        bx, by = 128 + 46 * math.cos(ar), 128 + 46 * math.sin(ar)
        for da in (-25, 25):
            br = math.radians(a + da)
            ex, ey = 128 + 68 * math.cos(br), 128 + 68 * math.sin(br)
            ic.line(bx, by, ex, ey)


# ---------------------------------------------------------------- commerce
def i_cart(ic):
    ic.line(48, 64, 80, 64)
    ic.line(80, 64, 100, 150)
    ic.line(92, 84, 204, 84)
    ic.line(204, 84, 184, 150)
    ic.line(100, 150, 184, 150)
    ic.circle(112, 190, 15)
    ic.circle(172, 190, 15)


def i_tag(ic):
    ic.poly([(56, 68), (140, 68), (200, 128), (140, 188), (56, 188)], closed=True)
    ic.circle(96, 128, 13)


def i_gift(ic):
    ic.rrect(64, 120, 192, 200, 6)
    ic.rrect(52, 88, 204, 120, 6)
    ic.circle(104, 70, 16)
    ic.circle(152, 70, 16)
    ic.line(128, 88, 128, 200)


def i_credit_card(ic):
    ic.rrect(48, 72, 208, 184, 14)
    ic.line(48, 112, 208, 112)
    ic.line(80, 152, 120, 152)


def i_wallet(ic):
    ic.rrect(48, 72, 208, 192, 16)
    ic.poly([(208, 104), (150, 104), (150, 160), (208, 160)])
    ic.dot(170, 132, 7)


# ---------------------------------------------------------------- devices
def i_monitor(ic):
    ic.rrect(44, 60, 212, 172, 12)
    ic.line(128, 172, 128, 198)
    ic.line(90, 202, 166, 202)


def i_smartphone(ic):
    ic.rrect(80, 44, 176, 212, 18)
    ic.line(112, 66, 144, 66)
    ic.dot(128, 190, 8)


def i_printer(ic):
    ic.rrect(84, 44, 172, 88, 6)
    ic.rrect(52, 88, 204, 164, 12)
    ic.rrect(84, 164, 172, 204, 6)
    ic.dot(172, 122, 7)


def i_battery(ic):
    ic.rrect(44, 88, 200, 168, 12)
    ic.rectfill(204, 112, 218, 144, rad=5)
    ic.rectfill(62, 104, 92, 152, rad=5)
    ic.rectfill(104, 104, 134, 152, rad=5)


def i_wifi(ic):
    ic.dot(128, 178, 11)
    for r, delta in ((46, 43.7), (78, 29.4), (110, 21.8)):
        ic.arc(128, 178, r, 270 - delta, 270 + delta)


def i_bluetooth(ic):
    ic.poly([(96, 84), (160, 144), (128, 168), (128, 88), (160, 112), (96, 172)])


def i_power(ic):
    ic.arc(128, 140, 66, 280, 620)
    ic.line(128, 52, 128, 124)


# ---------------------------------------------------------------- registry
LIBRARY = {
    "ui": {
        "home": i_home, "search": i_search, "settings": i_settings,
        "user": i_user, "users": i_users, "heart": i_heart, "star": i_star,
        "bookmark": i_bookmark, "bell": i_bell, "lock": i_lock, "unlock": i_unlock,
        "eye": i_eye, "calendar": i_calendar, "clock": i_clock, "trash": i_trash,
        "edit": i_edit, "plus": i_plus, "minus": i_minus, "check": i_check,
        "close": i_close, "menu": i_menu, "more-horizontal": i_more_horizontal,
        "more-vertical": i_more_vertical, "filter": i_filter, "grid": i_grid,
        "list": i_list, "info": i_info, "help": i_help, "warning": i_warning,
        "shield": i_shield, "key": i_key,
    },
    "arrows": {
        "arrow-up": i_arrow_up, "arrow-down": i_arrow_down,
        "arrow-left": i_arrow_left, "arrow-right": i_arrow_right,
        "chevron-up": i_chevron_up, "chevron-down": i_chevron_down,
        "chevron-left": i_chevron_left, "chevron-right": i_chevron_right,
        "refresh": i_refresh, "external-link": i_external_link, "link": i_link,
    },
    "media": {
        "play": i_play, "pause": i_pause, "stop": i_stop,
        "skip-forward": i_skip_forward, "skip-back": i_skip_back,
        "volume": i_volume, "mute": i_mute, "mic": i_mic, "camera": i_camera,
        "video": i_video, "image": i_image, "music": i_music,
    },
    "files": {
        "file": i_file, "folder": i_folder, "copy": i_copy, "clipboard": i_clipboard,
        "paperclip": i_paperclip, "download": i_download, "upload": i_upload,
        "save": i_save,
    },
    "comms": {
        "mail": i_mail, "phone": i_phone, "chat": i_chat, "send": i_send, "share": i_share,
    },
    "weather": {
        "sun": i_sun, "moon": i_moon, "cloud": i_cloud, "rain": i_rain,
        "lightning": i_lightning, "snowflake": i_snowflake,
    },
    "commerce": {
        "cart": i_cart, "tag": i_tag, "gift": i_gift,
        "credit-card": i_credit_card, "wallet": i_wallet,
    },
    "devices": {
        "monitor": i_monitor, "smartphone": i_smartphone, "printer": i_printer,
        "battery": i_battery, "wifi": i_wifi, "bluetooth": i_bluetooth, "power": i_power,
    },
}


def display_name(icon_id):
    special = {"ui": "UI", "wifi": "Wi-Fi", "mail": "Mail"}
    words = []
    for w in icon_id.split("-"):
        words.append(special.get(w, w.capitalize()))
    return " ".join(words)


def main():
    meta = {}
    total = 0
    for cat, icons in LIBRARY.items():
        cat_dir = os.path.join(OUT, cat)
        os.makedirs(cat_dir, exist_ok=True)
        entries = []
        for name, fn in icons.items():
            ic = Icon()
            fn(ic)
            rel = f"{cat}/{name}.png"
            ic.save(os.path.join(cat_dir, f"{name}.png"))
            entries.append({"id": name, "displayName": display_name(name), "path": rel})
            total += 1
        meta[cat] = entries
        print(f"{cat}: {len(entries)}")
    with open(os.path.join(OUT, "icons.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
    print(f"TOTAL: {total}")

    # contact sheet for visual review
    from PIL import ImageFont
    cols = 10
    cell = 150
    try:
        font = ImageFont.truetype("arial.ttf", 13)
    except Exception:
        font = ImageFont.load_default()
    rows = math.ceil(total / cols)
    sheet = Image.new("RGB", (cols * cell, rows * cell), (245, 246, 248))
    sd = ImageDraw.Draw(sheet)
    idx = 0
    for cat, entries in meta.items():
        for e in entries:
            x = (idx % cols) * cell
            y = (idx // cols) * cell
            img = Image.open(os.path.join(OUT, e["path"])).convert("RGBA").resize((100, 100))
            sheet.paste(img, (x + 25, y + 8), img)
            label = e["id"]
            tw = sd.textlength(label, font=font)
            sd.text((x + (cell - tw) / 2, y + 116), label, fill=(40, 40, 40), font=font)
            idx += 1
    sheet.save(os.path.join(os.path.dirname(__file__), "contact_sheet.png"))


if __name__ == "__main__":
    main()
