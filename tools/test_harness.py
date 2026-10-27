"""Loads AetherHUD in a mock WoW 1.12 client (Lua 5.1 via lupa, trimmed to 5.0's library)
and runs scenario.lua against it. The game's own AZS parser is read out of
AzerothSurvivors.exe so the tables are filled exactly as in game.

    python test_harness.py <path to AzerothSurvivors.exe>

Also lints the addon for Lua 5.1+ syntax the 1.12 client (Lua 5.0) would reject.
"""
import os
import re
import sys

import lupa.lua51 as lua51

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.join(HERE, "..", "AetherHUD")

HUD_CVARS = ('clock = "hudClock", bosses = "hudBosses", tally = "hudTally", build = "hudBuild", '
             'banners = "hudBanners", loot = "hudLoot", meter = "hudMeter", levels = "hudLevels", '
             'flag = "hudFlag", revive = "hudRevive"')


def extract_api(exe):
    data = open(exe, "rb").read()
    start = data.find(b"AZS_ZONE = {};")
    end_marker = b'AZSApiFrame:SetScript("OnEvent", AZS_ApiOnEvent);'
    end = data.find(end_marker, start)
    if start < 0 or end < 0:
        raise SystemExit("AZS API source not found in " + exe)
    src = data[start:end + len(end_marker)].decode("latin-1")
    return src.replace("HUD_CVARS_LUA", HUD_CVARS)


def toc_files():
    files = []
    for line in open(os.path.join(ADDON, "AetherHUD.toc"), encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#"):
            files.append(line)
    return files


# ------------------------------------------------------------------ lint

def strip_code(src):
    """Blank out comments and string literals so the lint only sees code."""
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("--[[", i):
            j = src.find("]]", i)
            j = n if j < 0 else j + 2
            out.append("\n" * src.count("\n", i, j))
            i = j
        elif src.startswith("--", i):
            j = src.find("\n", i)
            j = n if j < 0 else j
            i = j
        elif c in "\"'":
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == "\\" else 1
            out.append('""')
            i = j + 1
        elif src.startswith("[[", i):
            j = src.find("]]", i)
            j = n if j < 0 else j + 2
            out.append('""' + "\n" * src.count("\n", i, j))
            i = j
        else:
            out.append(c)
            i += 1
    return "".join(out)


LINT = [
    (r"#", "length operator # (5.1+): use table.getn / string.len"),
    (r"[\w\)\]]\s*%\s*[\w\(]", "modulo operator % (5.1+): use math.mod"),
    (r"\.\.\.", "vararg ... (5.0 uses arg)"),
    (r"\bstring\.(match|gmatch)\b", "string.match/gmatch don't exist in 5.0"),
    (r"\bselect\s*\(", "select() doesn't exist in 5.0"),
    (r"\bmath\.(huge|fmod)\b", "math.huge / math.fmod don't exist in 5.0"),
    (r"\bgoto\b", "goto (5.2+)"),
    (r"//", "integer division (5.3+)"),
    (r"\btable\.(unpack|pack)\b", "table.unpack/pack (5.2+)"),
    (r'(""|\))\s*:\s*(upper|lower|sub|len|find|format|gsub|rep|byte)\s*\(', "string method call (no string metatable in 5.0)"),
]


def lint(files):
    problems = []
    for name in files:
        src = open(os.path.join(ADDON, name), encoding="utf-8").read()
        code = strip_code(src)
        for lineno, line in enumerate(code.split("\n"), 1):
            for pat, why in LINT:
                if re.search(pat, line):
                    problems.append("%s:%d: %s   | %s" % (name, lineno, why, line.strip()))
    return problems


# ------------------------------------------------------------------ run

def new_runtime():
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(open(os.path.join(HERE, "wowmock.lua"), encoding="utf-8").read())
    lua.execute(open(os.path.join(HERE, "wowmock_ui.lua"), encoding="utf-8").read())
    return lua


def load_addon(lua, files):
    for name in files:
        src = open(os.path.join(ADDON, name), encoding="utf-8").read()
        fn = lua.eval("function(src, name) local f, err = loadstring(src, '@' .. name) if not f then error(err) end return f end")
        chunk = fn(src, name)
        chunk()


def main():
    exe = sys.argv[1]
    files = toc_files()

    problems = lint(files)
    print("== lint (Lua 5.0)")
    for p in problems:
        print("  " + p)
    print("  %d problem(s)" % len(problems))

    print("== scenario")
    lua = new_runtime()
    lua.execute(extract_api(exe))
    load_addon(lua, files)
    lua.execute(open(os.path.join(HERE, "scenario.lua"), encoding="utf-8").read())
    g = lua.globals()
    passed = failed = 0
    for i in range(1, len(g.RESULTS) + 1):
        r = g.RESULTS[i]
        if r.ok:
            passed += 1
            print("  ok    " + r.name)
        else:
            failed += 1
            print("  FAIL  " + r.name + ("   [" + r.detail + "]" if r.detail else ""))
    errs = g.MOCK.errors
    for i in range(1, len(errs) + 1):
        print("  lua error: " + errs[i])
    perf = g.PERF
    if perf:
        print("  steady state per second: SetText %.0f, SetWidth %.0f, SetTexture %.0f"
              % (perf.SetText, perf.SetWidth, perf.SetTexture))

    print("== without the AZS API")
    lua2 = new_runtime()
    load_addon(lua2, files)
    lua2.execute('MOCK.Fire("VARIABLES_LOADED") MOCK.Fire("PLAYER_ENTERING_WORLD") MOCK.Run(1)')
    g2 = lua2.globals()
    chat = [g2.MOCK.chat[i] for i in range(1, len(g2.MOCK.chat) + 1)]
    errs2 = [g2.MOCK.errors[i] for i in range(1, len(g2.MOCK.errors) + 1)]
    ok = any("API is missing" in m for m in chat) and not errs2
    print("  %s  explains itself and stays quiet %s" % ("ok  " if ok else "FAIL", errs2[:1]))
    if not ok:
        failed += 1
    else:
        passed += 1

    print("== %d passed, %d failed, %d lint" % (passed, failed, len(problems)))
    sys.exit(1 if failed or problems else 0)


if __name__ == "__main__":
    main()
