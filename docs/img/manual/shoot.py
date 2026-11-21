"""Take the user-manual screenshots from the running local demo.

Usage (WSL):  MDMS_PASSWORD=<demo password> python3 shoot.py [base_url]
Needs: pip install playwright; python3 -m playwright install chromium
Output: <role>-<page>.png in this folder (1280 px wide, top 900 px of each page).
Reports PHP errors / warnings found on any page at the end.
"""
import os, re, sys, glob
from playwright.sync_api import sync_playwright

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8342").rstrip("/")
PWD = os.environ["MDMS_PASSWORD"]
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.abspath(os.path.join(HERE, "..", "..", "..", "sources"))
ROLES = {"consumer": "consumer1", "operator": "operator", "technician": "tech1", "dso": "dso1",
         "tso": "tso1", "supplier": "supplier1", "aggregator": "aggregator1", "admin": "admin"}
ERR = re.compile(r"(Fatal error|Warning:|Notice:|Parse error|Uncaught|Stack trace)")
problems = []

def shot(page, name, full=False):
    page.screenshot(path=os.path.join(HERE, name + ".png"), full_page=full,
                    clip=None)
    html = page.content()
    m = ERR.search(html)
    if m:
        problems.append((name, page.url, m.group(0)))

def login(browser, user):
    ctx = browser.new_context(viewport={"width": 1280, "height": 900})
    page = ctx.new_page()
    page.goto(BASE + "/index.php")
    page.fill("input[name=username]", user)
    page.fill("input[name=password]", PWD)
    page.click("button[type=submit]")
    page.wait_for_load_state()
    return ctx, page

with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(viewport={"width": 1280, "height": 900}); pg = ctx.new_page()
    pg.goto(BASE + "/index.php"); shot(pg, "public-login", False)
    pg.goto(BASE + "/register_consumer.php"); shot(pg, "public-register-consumer", False)
    pg.goto(BASE + "/register_technician.php"); shot(pg, "public-register-technician", False)
    ctx.close()
    for role, user in ROLES.items():
        ctx, page = login(b, user)
        shot(page, f"{role}-home", False)
        for f in sorted(glob.glob(os.path.join(SRC, role, "*.php"))):
            base = os.path.basename(f)
            if base.startswith("_"):
                continue
            page.goto(f"{BASE}/{role}/{base}")
            page.wait_for_load_state()
            shot(page, f"{role}-{os.path.splitext(base)[0]}")
        if role == "tso":
            page.goto(f"{BASE}/tso/20_state.php")
            page.click("text=Ανανέωση τρέχουσας κατάστασης"); page.wait_for_load_state()
            shot(page, "tso-20_state-refreshed")
        if role == "consumer":
            page.goto(BASE + "/profile.php"); shot(page, "consumer-profile", False)
        ctx.close()
    b.close()
for pr in problems:
    print("PROBLEM", pr)
print("done")
