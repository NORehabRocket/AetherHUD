"""Renders AetherHUD's real layout (anchors, sizes, colours, text from the addon code
running in the mock client) to a standalone HTML page, as a stand-in for an in-game
screenshot. Icons from the game's data are drawn as placeholders; fonts are approximated.

    python render_preview.py <AzerothSurvivors.exe> <out.html> [demo|run]
"""
import base64
import html
import os
import re
import struct
import sys
import zlib

import test_harness as th

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(HERE, "..", "AetherHUD", "media")
W, H = 1365, 768


def tga_to_png_b64(path):
    data = open(path, "rb").read()
    w, h = struct.unpack("<HH", data[12:16])
    desc = data[17]
    px = data[18:]
    rows = []
    for y in range(h):
        sy = y if desc & 0x20 else h - 1 - y
        row = bytearray([0])
        for x in range(w):
            i = (sy * w + x) * 4
            b, g, r, a = px[i:i + 4]
            row += bytes((r, g, b, a))
        rows.append(bytes(row))

    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")
    return base64.b64encode(png).decode()


def rgba(c, alpha=1.0):
    if not c:
        return "rgba(255,255,255,%.3f)" % alpha
    r, g, b = c[1], c[2], c[3]
    a = (c[4] if len(c) >= 4 and c[4] is not None else 1) * alpha
    return "rgba(%d,%d,%d,%.3f)" % (r * 255, g * 255, b * 255, a)


def lua_list(t, n):
    return [t[i] for i in range(1, n + 1)] if t else None


ICON_COLORS = ["#3b6ea5", "#8a4fbf", "#b0553a", "#3f8f5a", "#a8892f", "#4a8fa8", "#9c3f5e"]


def text_spans(s, base):
    out, color = [], base
    pos = 0
    for m in re.finditer(r"\|c([0-9a-fA-F]{8})|\|r", s):
        if m.start() > pos:
            out.append((s[pos:m.start()], color))
        if m.group(0) == "|r":
            color = base
        else:
            hexc = m.group(1)[2:]
            color = "#" + hexc
        pos = m.end()
    if pos < len(s):
        out.append((s[pos:], color))
    return out


# A fight around the hero for the preview: enemies with client nameplates, a few hit.
WORLD = r'''
MOCK.Addon("AZSUNITS", "boss,101,Mother Fang,40000,64000,0;guardian,90,Kobold Geomancer,5400,9000,1;elite,95,Defias Pillager,300,400,0")
MOCK.Addon("AZSTGT", "kind=boss;id=101;name=Mother Fang;hp=40000;hpm=64000;state=0;elite=1")
MOCK.target = { name = "Mother Fang", hp = 62, hpm = 100, level = -1 }
local function mob(name, v, max, x, y, look)
	local p = MOCK.SpawnPlate(name, v, max, x, y)
	p.__mob = look
	return p
end
mob("Mother Fang", 40000, 64000, 860, 470, "boss")
mob("Kobold Geomancer", 5400, 9000, 470, 300, "guardian")
mob("Defias Pillager", 300, 400, 900, 300, "elite")
mob("Defias Thug", 55, 100, 560, 455)
mob("Defias Thug", 30, 100, 600, 520)
mob("Defias Thug", 100, 100, 780, 360)
mob("Murloc Raider", 80, 100, 520, 380)
mob("Murloc Raider", 100, 100, 640, 270)
mob("Murloc Raider", 100, 100, 760, 250)
mob("Defias Thug", 100, 100, 820, 560)
mob("Murloc Raider", 45, 100, 700, 560)
MOCK.Run(0.3)
'''


# Things the full-UI previews add: a party, a pet, gear, bags, stats, a loot line, a notice.
FULL = r'''
MOCK.party = { { name = "Friendo", hp = 72, hpm = 100, token = "PRIEST" }, { name = "Brakka", hp = 0, hpm = 100, token = "WARRIOR", dead = true, map = { 0.44, 0.62 }, dist = 20 } }
MOCK.pet = { name = "Water Elemental", hp = 80, hpm = 100 }
MOCK.equip[1] = { tex = "Interface\Icons\INV_Helmet_01", link = "|cffa335ee|Hitem:10:0:0:0|h[Helm]|h|r" }
MOCK.equip[5] = { tex = "Interface\Icons\INV_Chest_Cloth_01", link = "|cff0070dd|Hitem:11:0:0:0|h[Robe]|h|r" }
MOCK.equip[16] = { tex = "Interface\Icons\INV_Staff_01", link = "|cffff8000|Hitem:12:0:0:0|h[Staff]|h|r" }
MOCK.equip[11] = { tex = "Interface\Icons\INV_Jewelry_Ring_01", link = "|cff1eff00|Hitem:13:0:0:0|h[Ring]|h|r" }
for i = 1, 9 do
	local q = { 1, 2, 3, 4, 1, 2, 1, 3, 2 }
	local colors = { "ffffff", "1eff00", "0070dd", "a335ee", "ffffff", "1eff00", "ffffff", "0070dd", "1eff00" }
	MOCK.bags[0][i] = { tex = "Interface\Icons\Item" .. i, count = (i == 1 or i == 5) and 12 or 1, quality = q[i],
		link = "|cff" .. colors[i] .. "|Hitem:" .. (100 + i) .. ":0:0:0|h[Item]|h|r" }
end
MOCK.Addon("AZS", "hp=2400;dmg=1.35;cd=0.85;crit=0.12;cm=1.5;arm=0.2;reg=3.5;area=1.2;cnt=1;echo=0.05;spd=1.1;pick=6;xp=1;luck=0.1;gold=1;heal=4;lch=0.02;thn=0.05;liv=2;bp=0;dots=2;doth=0.1;big=0.15;exe=0;cc=0;dotd=0;shd=0;auto=0;pet=0;gdmg=0.08;ghp=120;gcrit=0.02")
MOCK.Run(0.3)
UIErrorsFrame:AddMessage("Not enough gold to open this cache.", 1, 0.25, 0.2)
MOCK.Fire("CHAT_MSG_LOOT", "You receive loot: |cffa335ee|Hitem:2000:0:0:0|h[Hogger's Spiked Collar]|h|r New in your collection!")
MOCK.Fire("CHAT_MSG_LOOT", "You receive loot: |cff0070dd|Hitem:2001:0:0:0|h[Defias Mask]|h|r already collected (2)")
'''

CHAT_LINES = [
    ("#ffff00", "Utther the Human Mage enters Elwynn Forest. Move to begin."),
    ("#ff7fff", "[Friendo] whispers: ready when you are"),
    ("#a9d271", "You receive loot: [Defias Mask] already collected (2)"),
    ("#ffffff", "[Brakka]: got the left side"),
    ("#ffff00", "Level 17 reached."),
]


def render(items, out_path, title, mobs=(), chat=()):
    media = {}
    for name in os.listdir(MEDIA):
        if name.endswith(".tga"):
            media[name[:-4]] = tga_to_png_b64(os.path.join(MEDIA, name))
    roboto = base64.b64encode(open(os.path.join(MEDIA, "Roboto.ttf"), "rb").read()).decode()

    defs, body = [], []
    for name, b64 in media.items():
        defs.append('<image id="img_%s" href="data:image/png;base64,%s" preserveAspectRatio="none"/>' % (name, b64))

    gid = 0
    for it in items:
        x, y = it["l"], H - it["t"]
        w, h = max(0.0, it["r"] - it["l"]), max(0.0, it["t"] - it["b"])
        alpha = it["alpha"]
        blend = ' style="mix-blend-mode:screen"' if it.get("blend") == "ADD" else ""
        if it["kind"] == "MinimapFace":
            body.append('<circle cx="%.2f" cy="%.2f" r="%.2f" fill="url(#terrain)"/>' % (x + w / 2, y + h / 2, w / 2))
            body.append('<path d="M %.1f %.1f l 5 12 l -5 -3 l -5 3 z" fill="#ffe680" stroke="black" stroke-width=".8"/>' % (x + w / 2, y + h / 2 - 7))
            continue
        if it["kind"] == "Texture":
            if w < 0.3 or h < 0.3 or not it.get("tex"):
                continue  # a cleared texture draws nothing
            tex = it.get("tex") or ""
            color = it.get("color")
            grad = it.get("grad")
            if grad:
                gid += 1
                horiz = grad[1] == "HORIZONTAL"
                c1 = "rgba(%d,%d,%d,%.3f)" % (grad[2] * 255, grad[3] * 255, grad[4] * 255, grad[5])
                c2 = "rgba(%d,%d,%d,%.3f)" % (grad[6] * 255, grad[7] * 255, grad[8] * 255, grad[9])
                if horiz:
                    defs.append('<linearGradient id="g%d" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>' % (gid, c1, c2))
                else:  # WoW: min colour at the bottom
                    defs.append('<linearGradient id="g%d" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>' % (gid, c1, c2))
                fill = "url(#g%d)" % gid
            else:
                fill = rgba([None] + list(color[1:5]) if color else None)
            key = None
            m = re.search(r"AetherHUD\\media\\(\w+)$", tex)
            if m and m.group(1) in media:
                key = m.group(1)
            if key:
                gid += 1
                flip = it.get("coord") and it["coord"][1] > it["coord"][2]
                transform = ' transform="translate(%.2f,0) scale(-1,1)"' % (2 * x + w) if flip else ""
                defs.append('<mask id="m%d" maskUnits="userSpaceOnUse" x="%.2f" y="%.2f" width="%.2f" height="%.2f"><use href="#img_%s" x="%.2f" y="%.2f" width="%.2f" height="%.2f"%s/></mask>'
                            % (gid, x - 1, y - 1, w + 2, h + 2, key, x, y, w, h, transform))
                # <use> on <image> ignores width/height in some engines: draw the image directly
                defs[-1] = ('<mask id="m%d" maskUnits="userSpaceOnUse" x="%.2f" y="%.2f" width="%.2f" height="%.2f"><image href="data:image/png;base64,%s" x="%.2f" y="%.2f" width="%.2f" height="%.2f" preserveAspectRatio="none"%s/></mask>'
                            % (gid, x - 1, y - 1, w + 2, h + 2, media[key], x, y, w, h, transform))
                body.append('<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s" mask="url(#m%d)" opacity="%.3f"%s/>' % (x, y, w, h, fill, gid, alpha, blend))
            elif "Icons" in tex or "TargetingFrame" in tex:
                name = tex.split("\\")[-1]
                col = ICON_COLORS[sum(map(ord, name)) % len(ICON_COLORS)]
                body.append('<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s" opacity="%.3f"/>' % (x, y, w, h, col, alpha))
                body.append('<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="url(#iconShade)" opacity="%.3f"/>' % (x, y, w, h, alpha))
            elif tex == "Portrait":
                body.append('<circle cx="%.2f" cy="%.2f" r="%.2f" fill="url(#portrait)" opacity="%.3f"/>' % (x + w / 2, y + h / 2, w * 0.47, alpha))
            elif "Spark" in tex:
                body.append('<ellipse cx="%.2f" cy="%.2f" rx="%.2f" ry="%.2f" fill="white" opacity="%.3f" style="mix-blend-mode:screen"/>' % (x + w / 2, y + h / 2, w / 4, h / 2.6, 0.5 * alpha))
            else:
                body.append('<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s" opacity="%.3f"%s/>' % (x, y, w, h, fill, alpha, blend))
        else:
            txt = it.get("text") or ""
            size = it["size"] * it["scale"]
            tc = it.get("tcolor")
            base = "#%02x%02x%02x" % (int(tc[1] * 255), int(tc[2] * 255), int(tc[3] * 255)) if tc else "#ffffff"
            point = it.get("point") or "CENTER"
            if "LEFT" in point:
                anchor, tx = "start", x
            elif "RIGHT" in point:
                anchor, tx = "end", x + w
            else:
                anchor, tx = "middle", x + w / 2
            ty = y + h / 2
            fam = "Roboto, Arial, sans-serif" if "Roboto" in it["font"] else "'Friz Quadrata TT', Georgia, serif"
            outline = "OUTLINE" in (it.get("flags") or "")
            spans = "".join('<tspan fill="%s">%s</tspan>' % (c, html.escape(t)) for t, c in text_spans(txt, base))
            stroke = ' stroke="black" stroke-width="%.1f" paint-order="stroke" stroke-linejoin="round"' % max(1.6, size / 7) if outline else ""
            weight = "600" if "Friz" in fam or "Georgia" in fam else "500"
            body.append('<text x="%.2f" y="%.2f" font-family="%s" font-weight="%s" font-size="%.2f" text-anchor="%s" dominant-baseline="central" opacity="%.3f"%s style="white-space:pre">%s</text>'
                        % (tx, ty, fam, weight, size, anchor, alpha, stroke, spans))

    page = """<!doctype html><html><head><meta charset="utf-8"><title>%s</title>
<style>
@font-face { font-family: Roboto; src: url(data:font/ttf;base64,%s); }
html, body { margin: 0; background: #0b0f14; color: #cfe; font: 13px Roboto, Arial, sans-serif; }
.wrap { width: %dpx; margin: 0 auto; padding: 16px 0; }
.note { opacity: .7; margin: 8px 0 12px; }
svg { display: block; border: 1px solid #234; }
</style></head><body><div class="wrap">
<div class="note">%s - layout rendered from the addon's own code in a mock 1.12 client (icons are placeholders; the game draws its world and native overlays behind this).</div>
<svg width="%d" height="%d" viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg">
<defs>
<radialGradient id="world" cx="50%%" cy="55%%" r="75%%"><stop offset="0" stop-color="#4b5a33"/><stop offset=".55" stop-color="#2c3a24"/><stop offset="1" stop-color="#121a12"/></radialGradient>
<radialGradient id="terrain" cx="40%%" cy="40%%" r="70%%"><stop offset="0" stop-color="#6f8a4a"/><stop offset=".5" stop-color="#4d6b35"/><stop offset=".8" stop-color="#3b5a2e"/><stop offset="1" stop-color="#2c4422"/></radialGradient>
<radialGradient id="portrait" cx="50%%" cy="38%%" r="65%%"><stop offset="0" stop-color="#e8c39e"/><stop offset=".45" stop-color="#9c6b4c"/><stop offset=".75" stop-color="#3a2a22"/><stop offset="1" stop-color="#1b1512"/></radialGradient>
<linearGradient id="iconShade" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="rgba(255,255,255,.35)"/><stop offset=".5" stop-color="rgba(255,255,255,0)"/><stop offset="1" stop-color="rgba(0,0,0,.45)"/></linearGradient>
%s
</defs>
<rect width="%d" height="%d" fill="url(#world)"/>
<circle cx="682" cy="430" r="14" fill="#c9b27a" opacity=".8"/><ellipse cx="682" cy="452" rx="16" ry="5" fill="black" opacity=".35"/>
%s
%s
%s
</svg></div>
<script>
// #x,y,w,h zooms into a region (for close inspection)
var m = location.hash.match(/^#(\\d+),(\\d+),(\\d+),(\\d+)$/);
if (m) { var s = document.querySelector("svg"); s.setAttribute("viewBox", m[1] + " " + m[2] + " " + m[3] + " " + m[4]);
  s.setAttribute("height", Math.round(%d * m[4] / m[3])); document.querySelector(".note").style.display = "none"; }
</script></body></html>""" % (title, roboto, W, title, W, H, W, H, "\n".join(defs), W, H, mob_svg(mobs), "\n".join(body), chat_svg(chat), W)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(page)


MOB_LOOK = {"normal": ("#6b5b4a", 11), "elite": ("#8a6a2a", 14), "guardian": ("#5e3f8c", 15), "boss": ("#7a2a22", 20)}


def mob_svg(mobs):
    out = []
    for x, y, look in mobs:
        col, r = MOB_LOOK.get(look, MOB_LOOK["normal"])
        cy = H - y + 30 + r
        out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="black" opacity=".35"/>' % (x, cy + r * 0.9, r * 1.2, r * 0.35))
        out.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="#1a120c" stroke-width="1.5"/>' % (x, cy, r, col))
    return "\n".join(out)


def chat_svg(lines):
    # sample chat lines in ChatFrame1's area (BOTTOMLEFT 32, 95; 430 x 120)
    out = []
    for i, (col, text) in enumerate(lines):
        y = H - 95 - 120 + 16 + i * 20
        out.append('<text x="36" y="%d" font-family="Roboto, Arial" font-size="13" fill="%s" style="paint-order:stroke" stroke="black" stroke-width="2">%s</text>' % (y, col, html.escape(text)))
    return "\n".join(out)


def to_py(items):
    out = []
    for i in range(1, len(items) + 1):
        it = items[i]
        d = {}
        for k in ("kind", "l", "r", "t", "b", "alpha", "tex", "blend", "text", "size", "font", "flags", "point", "scale",
                  "strata", "level", "layer", "seq"):
            d[k] = it[k]
        d["color"] = [None] + lua_list(it.color, 4) if it.color else None
        d["grad"] = [None] + lua_list(it.grad, 9) if it.grad else None
        d["coord"] = [None] + lua_list(it.coord, 4) if it.coord else None
        d["tcolor"] = [None] + lua_list(it.tcolor, 4) if it.tcolor else None
        out.append(d)
    return out


INSPECT = r"""
MOCK.party = { { name = "Jaina", hp = 1320, hpm = 1500, level = 24, class = "Mage", token = "MAGE", race = "Human", player = true, friend = true } }
MOCK.guilds = { Jaina = "Kirin Tor" }
local q = { epic = "a335ee", rare = "0070dd", good = "1eff00", common = "ffffff" }
local function it(id, icon, name, quality)
	return { tex = "Interface\\Icons\\" .. icon, link = "|cff" .. q[quality] .. "|Hitem:" .. id .. ":0:0:0|h[" .. name .. "]|h|r" }
end
MOCK.inspected = { Jaina = {
	[1] = it(1, "INV_Helmet_29", "Admiral's Hat", "epic"), [2] = it(2, "INV_Jewelry_Necklace_07", "Amulet of the Kirin Tor", "rare"),
	[3] = it(3, "INV_Shoulder_02", "Frostweave Mantle", "rare"), [15] = it(4, "INV_Misc_Cape_05", "Onyxia Scale Cloak", "epic"),
	[5] = it(5, "INV_Chest_Cloth_08", "Robe of the Archmage", "epic"), [9] = it(6, "INV_Bracer_07", "Frostweave Bracers", "good"),
	[10] = it(7, "INV_Gauntlets_14", "Gloves of the Tide", "rare"), [6] = it(8, "INV_Belt_08", "Sash of Mercy", "good"),
	[7] = it(9, "INV_Pants_08", "Leggings of Arcana", "epic"), [8] = it(10, "INV_Boots_05", "Sandals of the Insurgent", "rare"),
	[11] = it(11, "INV_Jewelry_Ring_15", "Band of Frost", "rare"), [13] = it(12, "INV_Trinket_Naxxramas06", "Eye of Moam", "epic"),
	[16] = it(13, "INV_Staff_13", "Staff of Jordan", "rare"), [18] = it(14, "INV_Wand_07", "Glacial Spike", "good"),
} }
MOCK.Run(0.3)
MOCK.Addon("AZSPARTY", "Jaina,mage,184200,412,0.58,Frostbolt,230;Utther,shaman,131800,298,0.42,Chain Lightning,180")
InspectUnit("party1")
MOCK.Run(0.6)
"""


def main():
    exe, out = sys.argv[1], sys.argv[2]
    mode = sys.argv[3] if len(sys.argv) > 3 else "demo"
    lua = th.new_runtime()
    lua.execute(open(os.path.join(HERE, "layout.lua"), encoding="utf-8").read())
    lua.execute(th.extract_api(exe))
    th.load_addon(lua, th.toc_files())
    lua.execute('MOCK.Fire("VARIABLES_LOADED") MOCK.Fire("PLAYER_ENTERING_WORLD") MOCK.Run(0.6)')
    if mode in ("demo", "windows", "inspect", "records"):
        lua.execute(WORLD)
        lua.execute(FULL)
        lua.execute('MOCK.Slash("/aether", "demo") MOCK.Run(0.2) AetherHUD.TestBanners() MOCK.Run(1.0)')
    if mode == "windows":
        lua.execute('ToggleBackpack() ToggleCharacter() MOCK.Run(0.4)')
    elif mode == "inspect":
        lua.execute(INSPECT)
    elif mode == "records":
        lua.execute('AetherHUD.ToggleRecords() MOCK.Run(0.3)')
    elif mode == "unlock":
        lua.execute('MOCK.Slash("/aether", "unlock") MOCK.Run(1.0)')
    elif mode == "options":
        lua.execute('MOCK.Slash("/aether", "demo") MOCK.Run(0.5) MOCK.Slash("/aether", "") MOCK.Run(0.2)')
    mobs = []
    if mode == "demo":
        kids = lua.eval("WorldFrame.__children")
        for i in range(1, len(kids) + 1):
            k = kids[i]
            if k.__px:
                mobs.append((k.__px, k.__py, k.__mob or "normal"))
    py = to_py(lua.eval("MOCK.Layout(WorldFrame)"))
    py += to_py(lua.eval("MOCK.Layout(AetherHUDRoot)"))
    # the map stays in the game's cluster (2.1), which follows our ring
    py += to_py(lua.eval("MOCK.Layout({ __children = { MinimapCluster } })"))
    py += to_py(lua.eval("MOCK.Layout({ __children = { ChatFrame1, ChatFrame1Tab, ChatFrame2Tab, ChatFrameEditBox } })"))
    if lua.eval("AetherHUDNumbers ~= nil"):
        py += to_py(lua.eval("MOCK.Layout({ __children = { AetherHUDNumbers } })"))
    if mode == "options":
        py += to_py(lua.eval("MOCK.Layout({ __children = { AetherHUDOptions } })"))
    errs = lua.eval("MOCK.errors")
    for i in range(1, len(errs) + 1):
        print("lua error:", errs[i])
    # one draw order across every root, as the client draws them: strata, level, layer
    py.sort(key=lambda d: (d["strata"], d["level"], d["layer"], d["seq"]))
    chat = []
    if mode in ("demo", "windows", "inspect", "records"):
        chat = CHAT_LINES
    render(py, out, "AetherHUD preview (%s)" % mode, mobs, chat)
    print("wrote", out, len(py), "items")


if __name__ == "__main__":
    main()
