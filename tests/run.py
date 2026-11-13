import sys, os, locale
from lupa.lua51 import LuaRuntime

# like WoW: C locale, otherwise string.lower() mangles UTF-8 bytes on Windows
locale.setlocale(locale.LC_ALL, "C")

ADDON_DIR = sys.argv[1]
SCENARIO = sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))

lua = LuaRuntime(unpack_returned_tuples=True)
LOCALE = os.environ.get("LOCALE", "deDE")
lua.execute(open(os.path.join(HERE, "mock.lua"), encoding="utf-8").read())
# Layout-Rechner (Anker, Größen, Textbreiten) – damit läuft ns.LayoutCheck auch in den Tests
lua.execute(open(os.path.join(HERE, "layoutsim.lua"), encoding="utf-8").read())
if os.environ.get("FACTION") == "Alliance":
    lua.execute('UnitFactionGroup = function() return "Alliance", "Alliance" end')
lua.execute('GetLocale = function() return "%s" end' % LOCALE)
lua.execute("""
UNKNOWN = {}
setmetatable(_G, { __index = function(t, k) UNKNOWN[k] = true; return nil end })
""")
# addon name comes from the .toc, so the checkout folder may have any name
NAME = next(f[:-4] for f in os.listdir(ADDON_DIR) if f.endswith(".toc"))
toc = open(os.path.join(ADDON_DIR, NAME + ".toc"), encoding="utf-8").read()
files = [l.strip() for l in toc.splitlines() if l.strip() and not l.startswith("#")]
lua.execute("KW = {}")
loader = lua.eval("function(src, name) local fn, err = loadstring(src, name); if not fn then error(err) end; return fn end")
for f in files:
    path = os.path.join(ADDON_DIR, *f.split("\\"))
    fn = loader(open(path, encoding="utf-8").read(), "@" + f)
    fn(NAME, lua.globals().KW)

lua.execute(open(SCENARIO, encoding="utf-8").read())
unknown = sorted(k for k in lua.globals().UNKNOWN.keys())
print("Unbekannte Globals:", unknown)
