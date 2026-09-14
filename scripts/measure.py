import re, pathlib, sys
for f in sys.argv[1:]:
    p = pathlib.Path("scripts/stories")/f
    body = p.read_text(encoding="utf-8").split('---',2)[2]
    chs = re.split(r'^## ', body, flags=re.M)[1:]
    tot = 0
    print(f"{f}")
    for c in chs:
        t, x = c.split('\n',1)
        w = len(x.split()); tot += w
        flag = "  <- curto" if w < 500 else ""
        print(f"   {t.strip()[:38]:40} {w:>4}{flag}")
    print(f"   {'TOTAL':40} {tot:>4}  ~{tot/150:.0f} min\n")
