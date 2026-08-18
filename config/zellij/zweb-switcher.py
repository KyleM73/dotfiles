#!/usr/bin/env python3
# zweb-switcher.py — mobile companion page for zellij's web client: a session
# switcher plus an on-screen key row (Esc/Tab/Ctrl/Alt/arrows/^C) that mobile
# browser keyboards lack. Started/stopped by `zweb up` / `zweb down` (aliases),
# which also mounts it on the tailnet at https://HOST/s via `tailscale serve`
# — same origin as the terminal, so the zellij login cookie is shared.
#
# Binds 127.0.0.1:8083 ONLY (reachable remotely just through the tailnet TLS
# proxy, like zellij itself). The session list requires zellij's login cookie
# (checked by proxying an authenticated page), so tailnet peers without a
# token see nothing — session names are directory names, worth guarding.
#
# Routes (an optional leading /s from the serve mount is stripped):
#   /              switcher: tap a session to open it with the key row
#   /t/NAME        wrapper: iframe of the terminal + the key row
#   /z/NAME        the zellij page proxied minus its X-Frame-Options: DENY —
#                  zellij forbids framing wholesale, but framing our OWN page
#                  on our OWN origin is exactly what the wrapper needs. Only
#                  the HTML shell flows through here: its <base href="/"> and
#                  absolute /ws/ paths send assets, auth, and websockets
#                  straight to the / mount. (Renaming a session from inside
#                  the iframe navigates it to the unproxied page, which
#                  refuses to render framed — reopen from the switcher.)
import html
import http.server
import re
import subprocess
import urllib.request

PORT = 8083
ZELLIJ = "http://127.0.0.1:8082"
NAME_RE = re.compile(r"^[A-Za-z0-9_-]+$")

STYLE = """
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <style>
    * { margin: 0; box-sizing: border-box; }
    body { background: #121212; color: #ddd; font: 16px -apple-system, system-ui, sans-serif; }
  </style>
"""

def sessions():
    out = subprocess.run(["zellij", "list-sessions", "-n"],
                         capture_output=True, text=True, timeout=10).stdout
    rows = []
    for line in out.splitlines():
        # zellij's timestamps end in "ago" already; capture without it. Names
        # outside NAME_RE can't be linked (or safely rendered) — skip them.
        m = re.match(r"(\S+) \[Created ([^\]]*?)(?: ago)?\](.*)", line)
        if m and NAME_RE.match(m.group(1)):
            rows.append({"name": m.group(1), "created": m.group(2),
                         "exited": "EXITED" in m.group(3)})
    return rows

def index_html():
    # Names are NAME_RE-vetted, but escape anyway — session names reach this
    # HTML from anything that can create a session.
    items = "".join(
        f'<a href="/s/t/{s["name"]}"><b>{html.escape(s["name"])}</b>'
        f'<small>{"exited — tap to resurrect" if s["exited"] else "created " + html.escape(s["created"]) + " ago"}</small></a>'
        for s in sessions()) or "<p>no sessions — start one on this machine</p>"
    return f"""<!doctype html><html><head><title>zellij sessions</title>{STYLE}
  <style>
    h1 {{ font-size: 18px; padding: 16px; color: #7fdbca; }}
    a {{ display: block; padding: 14px 16px; border-top: 1px solid #2a2a2a;
        color: #ddd; text-decoration: none; }}
    a small {{ display: block; color: #888; margin-top: 2px; }}
    p {{ padding: 16px; color: #888; }}
  </style></head>
  <body><h1>zellij sessions</h1>{items}
  <script>/* re-list when the tab comes back to the foreground */
    addEventListener("focus", () => location.reload());
  </script></body></html>"""

def wrapper_html(name):
    # The key row dispatches synthetic keydown events onto xterm.js's hidden
    # textarea inside the (same-origin) iframe. Ctrl/Alt are sticky: they tag
    # the next key — from the row or from the mobile keyboard (a capture
    # listener re-dispatches the typed key with the modifier applied).
    return f"""<!doctype html><html><head><title>{name}</title>{STYLE}
  <style>
    html, body {{ height: 100%; overflow: hidden; }}
    body {{ display: flex; flex-direction: column; }}
    iframe {{ flex: 1; border: 0; width: 100%; }}
    /* Grouped: nav | actions | sticky modifiers | arrows — the wider gaps
       between groups keep "shift" from reading as a fifth arrow. */
    #keys {{ display: flex; gap: 14px; padding: 6px; background: #1c1c1c; }}
    /* group flex ~ button count so every key ends up the same width */
    #keys .grp {{ display: flex; gap: 5px; }}
    #keys .g6 {{ flex: 6; }}
    #keys .g4 {{ flex: 4; }}
    #keys button {{ flex: 1; padding: 10px 0; font: 15px ui-monospace, monospace;
        background: #2e2e2e; color: #ddd; border: 0; border-radius: 6px; }}
    #keys button.on {{ background: #7fdbca; color: #000; }}
    #back {{ flex: 0 0 66px; }}
  </style></head><body>
  <iframe id="term" src="/s/z/{name}"></iframe>
  <div id="keys">
    <button id="back" title="sessions">&#9776;</button>
    <span class="grp g6">
      <button data-k="Escape:27">esc</button><button data-k="Tab:9">tab</button>
      <button data-k="c:67" data-ctrl="1">^C</button>
      <button data-m="ctrl">ctrl</button><button data-m="alt">alt</button>
      <button data-m="shift">shift</button>
    </span>
    <span class="grp g4">
      <button data-k="ArrowLeft:37">&larr;</button><button data-k="ArrowUp:38">&uarr;</button>
      <button data-k="ArrowDown:40">&darr;</button><button data-k="ArrowRight:39">&rarr;</button>
    </span>
  </div>
  <script>
    const frame = document.getElementById("term");
    const mods = {{ ctrl: false, alt: false, shift: false }};
    const target = () => {{
      const d = frame.contentDocument;
      return d && (d.querySelector(".xterm-helper-textarea") || d.body);
    }};
    function send(key, keyCode, forceCtrl) {{
      const t = target(); if (!t) return;
      // A key tap should not change whether the on-screen keyboard is up:
      // remember the focus state and put it back after dispatching.
      const hadFocus = frame.contentDocument.activeElement === t;
      const o = {{ key, code: key, keyCode, which: keyCode, bubbles: true,
                  cancelable: true, ctrlKey: forceCtrl || mods.ctrl, altKey: mods.alt,
                  shiftKey: mods.shift }};
      t.dispatchEvent(new KeyboardEvent("keydown", o));
      t.dispatchEvent(new KeyboardEvent("keyup", o));
      if (t.blur && frame.contentDocument.activeElement === t && !hadFocus) t.blur();
      clearMods();
    }}
    function clearMods() {{
      mods.ctrl = mods.alt = mods.shift = false;
      document.querySelectorAll("#keys [data-m]").forEach(b => b.classList.remove("on"));
    }}
    function activate(b) {{
      if (b.id === "back") {{ location.href = "/s/"; return; }}
      if (b.dataset.m) {{ mods[b.dataset.m] = !mods[b.dataset.m]; b.classList.toggle("on"); return; }}
      const [key, kc] = b.dataset.k.split(":");
      send(key, +kc, !!b.dataset.ctrl);
    }}
    document.querySelectorAll("#keys button").forEach(b => {{
      // pointerdown preventDefault keeps a tap from moving focus (which
      // would summon/dismiss the mobile keyboard); the action fires on
      // pointerup. click is only a fallback for non-pointer-event browsers
      // (both would double-fire otherwise).
      b.addEventListener("pointerdown", e => e.preventDefault());
      b.addEventListener("pointerup", e => {{ e.preventDefault(); activate(b); }});
      b.addEventListener("click", e => {{ e.preventDefault(); if (!window.PointerEvent) activate(b); }});
    }});
    // Mobile keyboards overlay the layout viewport without resizing it, which
    // would bury the key row. Track the visual viewport instead: size the
    // page to it, so the terminal shrinks and the key row sits right above
    // the keyboard.
    const vv = window.visualViewport;
    if (vv) {{
      const fit = () => {{ document.body.style.height = vv.height + "px"; scrollTo(0, 0); }};
      vv.addEventListener("resize", fit);
      vv.addEventListener("scroll", fit);
      fit();
    }}
    // Sticky ctrl/alt for keys typed on the mobile keyboard: swallow the bare
    // key and re-dispatch it with the modifier set.
    frame.addEventListener("load", () => {{
      frame.contentDocument.addEventListener("keydown", e => {{
        // !isTrusted skips our own synthetic re-dispatch — without it a
        // sticky modifier recurses through this listener until overflow.
        if (!e.isTrusted || !(mods.ctrl || mods.alt || mods.shift) || e.ctrlKey || e.altKey || e.isComposing) return;
        if (e.key.length !== 1) return;
        e.preventDefault(); e.stopImmediatePropagation();
        send(e.key, e.keyCode);
      }}, true);
    }});
  </script></body></html>"""

LOGIN_HTML = f"""<!doctype html><html><head><title>zellij sessions</title>{STYLE}
  <style> p {{ padding: 16px; line-height: 1.5; }} a {{ color: #7fdbca; }} </style></head>
  <body><p>Not logged in. Open one of your session bookmarks
  (<code>https://HOST/&lt;session&gt;</code>), authenticate with your token,
  then come back here.</p></body></html>"""

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/s" or path.startswith("/s/"):
            path = path[2:] or "/"
        if path == "/":
            if not self.authed():
                return self.html(LOGIN_HTML, status=401)
            return self.html(index_html())
        kind, _, name = path.lstrip("/").partition("/")
        if kind in ("t", "z") and NAME_RE.match(name or ""):
            return self.html(wrapper_html(name)) if kind == "t" else self.proxy(name)
        self.send_error(404)

    def authed(self):
        # Session names are project-dir names — don't list them for tailnet
        # peers who never logged in. Zellij stamps data-authenticated on its
        # page per request cookie, so borrow that as the auth check.
        req = urllib.request.Request(f"{ZELLIJ}/",
                                     headers={"Cookie": self.headers.get("Cookie", "")})
        try:
            with urllib.request.urlopen(req, timeout=5) as r:
                return b'data-authenticated="true"' in r.read()
        except OSError:
            return False

    def proxy(self, name):
        # Forward the browser's cookie so zellij renders the page already
        # authenticated; return its HTML without the X-Frame-Options: DENY —
        # but pin framing to this origin so no other site can embed it.
        req = urllib.request.Request(f"{ZELLIJ}/{name}",
                                     headers={"Cookie": self.headers.get("Cookie", "")})
        try:
            with urllib.request.urlopen(req, timeout=10) as r:
                self.reply(r.status, "text/html; charset=utf-8", r.read(),
                           {"Content-Security-Policy": "frame-ancestors 'self'"})
        except OSError:
            self.send_error(502, "zellij web server not reachable on 127.0.0.1:8082")

    def html(self, page, status=200):
        self.reply(status, "text/html; charset=utf-8", page.encode())

    def reply(self, status, ctype, body, extra=None):
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass

if __name__ == "__main__":
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
