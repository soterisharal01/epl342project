#!/usr/bin/env python3
"""smoke_site.py (REL-1): smoke test of a deployed MDMS-Cy site. Read-only: it only logs in and opens pages.

    set MDMS_DEMO_PASSWORD=<the demo password>        (PowerShell: $env:MDMS_DEMO_PASSWORD = '...')
    python sql/tools/smoke_site.py https://students.cs.ucy.ac.cy/~sharal01/mdms/
    python sql/tools/smoke_site.py http://localhost:8342 --insecure     (skip TLS check, like curl -k)
    python sql/tools/smoke_site.py <url> --roles consumer1,dso1         (only some users)

For each demo user it logs in, reads the menu links from home.php (so new pages are found automatically),
opens each page and profile.php, and fails a page when: HTTP status is not 200, the text contains a PHP
warning/notice/fatal/parse/stack trace or a raw SQL Server error, or the page is empty.
The password is read only from the environment and never printed. Exit code 1 if anything fails.
"""
import html
import http.cookiejar
import os
import re
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request

USERS = ['consumer1', 'operator', 'tech1', 'dso1', 'tso1', 'supplier1', 'aggregator1', 'admin']
BAD = re.compile(r'(<b>)?(Warning|Notice|Fatal error|Parse error|Deprecated)(</b>)?:\s|Stack trace:|Uncaught |'
                 r'\[Microsoft\]\[ODBC|SQLSTATE\[|sqlsrv_|Call to undefined|on line <b>\d+', re.I)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None


def make_opener(insecure):
    jar = http.cookiejar.CookieJar()
    handlers = [urllib.request.HTTPCookieProcessor(jar)]
    if insecure:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        handlers.append(urllib.request.HTTPSHandler(context=ctx))
    return urllib.request.build_opener(*handlers)


def fetch(op, url, data=None):
    """Returns (status, final_url, text). Follows redirects. HTTP errors return their status."""
    req = urllib.request.Request(url, data=urllib.parse.urlencode(data).encode() if data else None,
                                 headers={'User-Agent': 'mdms-smoke/1.0'})
    try:
        with op.open(req, timeout=30) as r:
            return r.status, r.geturl(), r.read().decode('utf-8', 'replace')
    except urllib.error.HTTPError as e:
        return e.code, url, e.read().decode('utf-8', 'replace')
    except Exception as e:  # network, TLS, timeout
        return 0, url, f'{type(e).__name__}: {e}'


def problems(status, text):
    out = []
    if status != 200:
        out.append(f'HTTP {status}')
    if status == 200 and len(text.strip()) < 50:
        out.append('empty page')
    m = BAD.search(text)
    if m:
        s = max(0, m.start() - 20)
        out.append('error text: ' + re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', '', text[s:m.end() + 80]))[:100])
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    insecure = '--insecure' in sys.argv
    users = USERS
    for i, a in enumerate(sys.argv):
        if a == '--roles' and i + 1 < len(sys.argv):
            users = sys.argv[i + 1].split(',')
            args = [x for x in args if x != sys.argv[i + 1]]
    if len(args) != 1:
        sys.exit(__doc__)
    base = args[0].rstrip('/') + '/'
    pw = os.environ.get('MDMS_DEMO_PASSWORD')
    if not pw:
        sys.exit('Set the environment variable MDMS_DEMO_PASSWORD first (never type the password in a file).')

    fails = 0
    total = 0
    for user in users:
        op = make_opener(insecure)
        st, _, text = fetch(op, base + 'index.php')
        m = re.search(r'name="csrf" value="([0-9a-f]+)"', text)
        if st != 200 or not m:
            print(f'FAIL {user:12} login form: HTTP {st}, csrf token {"found" if m else "missing"}')
            fails += 1
            continue
        st, final, text = fetch(op, base + 'login.php', {'csrf': m.group(1), 'username': user, 'password': pw})
        if st != 200 or 'home.php' not in final:
            flash = re.search(r'class="[^"]*(?:flash|error)[^"]*"[^>]*>(.*?)<', text, re.S)
            print(f'FAIL {user:12} login: HTTP {st}, ended at {final.replace(base, "")}'
                  + (f', message: {html.unescape(flash.group(1).strip())[:80]}' if flash else ''))
            fails += 1
            continue
        pages = ['home.php']
        for href in re.findall(r'<li><a href="([^"]+)"', text):
            href = html.unescape(href)
            rel = urllib.parse.urljoin(final, href).replace(base, '')
            if rel not in pages and not rel.startswith(('http', 'logout')):
                pages.append(rel)
        if 'profile.php' not in pages:
            pages.append('profile.php')
        for page in pages:
            total += 1
            st, _, body = fetch(op, base + page)
            bad = problems(st, body)
            if bad:
                fails += 1
                print(f'FAIL {user:12} {page}: ' + '; '.join(bad))
            else:
                print(f'OK   {user:12} {page}')
        fetch(op, base + 'logout.php')
    print(f'{total} pages opened, {fails} problem(s)')
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
