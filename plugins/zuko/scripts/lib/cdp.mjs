// A zero-dependency Chrome DevTools Protocol client, for check-rendered-drift.sh.
// Drives an installed Chrome, Edge or Chromium in headless mode over Node's
// built-in WebSocket. Needs Node 22 or newer. No npm install.
//
// Ported from design-taste-frontend v2.1.5, scripts/lib/cdp.mjs
// (https://github.com/Leonxlnx/taste-skill). Changes from upstream: a set
// CHROME_PATH is used alone, with no fall back to the search; taskkill starts
// from System32, never from the current folder (D133); a candidate path that
// is not absolute is skipped (D135); the profile sweep, screenshots and wheel
// input are not ported.
//
// MIT License
//
// Copyright (c) 2026 Leonxlnx
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
import { spawn, spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { isAbsolute, join, win32 } from 'node:path';

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Windows' own taskkill, by its full path: libuv looks in the current folder
// first for a bare name (D133).
export const taskkillPath = () => win32.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'taskkill.exe');

// The browser to drive, or null. A set CHROME_PATH is the only candidate, so a
// wrong path is an error, not a different browser. An unset variable makes a
// candidate relative, and a relative path reads from the project folder (D135).
export function findChrome() {
  if (process.env.CHROME_PATH) return existsSync(process.env.CHROME_PATH) ? process.env.CHROME_PATH : null;
  const home = process.env.HOME || process.env.USERPROFILE || '';
  const local = process.env.LOCALAPPDATA || '';
  const pf = process.env.PROGRAMFILES || 'C:\\Program Files';
  const pf86 = process.env['PROGRAMFILES(X86)'] || 'C:\\Program Files (x86)';
  const candidates = [
    // Windows
    join(pf, 'Google/Chrome/Application/chrome.exe'),
    join(pf86, 'Google/Chrome/Application/chrome.exe'),
    join(local, 'Google/Chrome/Application/chrome.exe'),
    join(pf86, 'Microsoft/Edge/Application/msedge.exe'),
    join(pf, 'Microsoft/Edge/Application/msedge.exe'),
    join(pf, 'BraveSoftware/Brave-Browser/Application/brave.exe'),
    // macOS
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
    '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser',
    join(home, 'Applications/Google Chrome.app/Contents/MacOS/Google Chrome'),
    // Linux
    '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable', '/usr/bin/chromium',
    '/usr/bin/chromium-browser', '/snap/bin/chromium', '/usr/bin/microsoft-edge',
  ];
  for (const c of candidates) if (isAbsolute(c) && existsSync(c)) return c;
  return null;
}

export class Browser {
  // Starts the browser at `exe` with a throwaway profile, removed on exit.
  static async launch(exe, { width = 1440, height = 900 } = {}) {
    if (typeof WebSocket === 'undefined') {
      throw new Error('Node 22+ is required (built-in WebSocket missing). Current: ' + process.version);
    }
    const dir = mkdtempSync(join(tmpdir(), 'zuko-chrome-'));
    // On exit Chrome still holds the profile's files: stop it first, then remove the folder.
    let pid = 0;
    const drop = () => {
      try { if (pid) { if (process.platform === 'win32') spawnSync(taskkillPath(), ['/pid', String(pid), '/T', '/F'], { stdio: 'ignore' }); else process.kill(pid, 'SIGKILL'); } } catch {}
      try { rmSync(dir, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 }); } catch {}
    };
    process.once('exit', drop);
    for (const sig of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.once(sig, () => { drop(); process.exit(130); });
    const args = [
      '--headless=new', '--remote-debugging-port=0', `--user-data-dir=${dir}`,
      '--no-first-run', '--no-default-browser-check', '--mute-audio', '--hide-scrollbars',
      '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
      '--disable-backgrounding-occluded-windows', '--disable-features=Translate,MediaRouter',
      '--force-color-profile=srgb', `--window-size=${width},${height}`,
      // The Fetch domain never pauses a WebSocket handshake, so each connection
      // also goes to a proxy on a dead port. Only localhost and 127.0.0.1 bypass
      // it; `<-loopback>` drops Chrome's own bypass for the rest of 127.0.0.0/8.
      '--proxy-server=127.0.0.1:9', '--proxy-bypass-list=<-loopback>;localhost;127.0.0.1',
      'about:blank',
    ];
    const proc = spawn(exe, args, { stdio: ['ignore', 'ignore', 'pipe'] });
    pid = proc.pid;
    const wsUrl = await new Promise((resolve, reject) => {
      let buf = '';
      const t = setTimeout(() => reject(new Error('the browser did not start within 20s')), 20000);
      proc.stderr.on('data', (d) => {
        buf += d.toString();
        const m = buf.match(/DevTools listening on (ws:\/\/[^\s]+)/);
        if (m) { clearTimeout(t); resolve(m[1]); }
      });
      proc.on('error', (e) => { clearTimeout(t); reject(new Error('the browser did not start: ' + e.message)); });
      proc.on('exit', (code) => { clearTimeout(t); reject(new Error('the browser exited early, code ' + code)); });
    });
    const b = new Browser();
    b.proc = proc; b.dir = dir; b.nextId = 1; b.pending = new Map(); b.listeners = new Map();
    b.ws = new WebSocket(wsUrl);
    await new Promise((res, rej) => { b.ws.onopen = res; b.ws.onerror = () => rej(new Error('the CDP socket failed')); });
    b.ws.onmessage = (ev) => {
      const msg = JSON.parse(typeof ev.data === 'string' ? ev.data : Buffer.from(ev.data).toString());
      if (msg.id && b.pending.has(msg.id)) {
        const { resolve, reject, timer } = b.pending.get(msg.id);
        clearTimeout(timer); b.pending.delete(msg.id);
        if (msg.error) reject(new Error(msg.error.message)); else resolve(msg.result);
      } else if (msg.method) {
        const fns = b.listeners.get((msg.sessionId || '') + '|' + msg.method);
        if (fns) for (const fn of [...fns]) fn(msg.params);
      }
    };
    return b;
  }

  send(method, params = {}, sessionId, timeoutMs = 30000) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => { this.pending.delete(id); reject(new Error('CDP timeout: ' + method)); }, timeoutMs);
      this.pending.set(id, { resolve, reject, timer });
      this.ws.send(JSON.stringify(sessionId ? { id, method, params, sessionId } : { id, method, params }));
    });
  }

  on(sessionId, method, fn) {
    const k = (sessionId || '') + '|' + method;
    if (!this.listeners.has(k)) this.listeners.set(k, new Set());
    this.listeners.get(k).add(fn);
    return () => this.listeners.get(k)?.delete(fn);
  }

  async newPage({ width = 1440, height = 900 } = {}) {
    const { targetId } = await this.send('Target.createTarget', { url: 'about:blank', newWindow: true });
    const { sessionId } = await this.send('Target.attachToTarget', { targetId, flatten: true });
    const p = new Page(this, targetId, sessionId);
    await p.send('Page.enable');
    await p.send('Runtime.enable');
    await p.send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: false });
    return p;
  }

  async close() {
    try { await this.send('Browser.close', {}, undefined, 3000); } catch {}
    try { this.ws.close(); } catch {}
    try { this.proc.kill(); } catch {}
    await sleep(300);
    try { rmSync(this.dir, { recursive: true, force: true, maxRetries: 3 }); } catch {}
  }
}

export class Page {
  constructor(browser, targetId, sessionId) {
    this.browser = browser; this.targetId = targetId; this.sessionId = sessionId;
    // Never let a JS dialog block the page.
    browser.on(sessionId, 'Page.javascriptDialogOpening', () => {
      this.send('Page.handleJavaScriptDialog', { accept: false }).catch(() => {});
    });
  }

  send(method, params = {}, timeoutMs = 30000) {
    return this.browser.send(method, params, this.sessionId, timeoutMs);
  }

  on(method, fn) { return this.browser.on(this.sessionId, method, fn); }

  // Navigates and resolves after the load event (or the timeout). Throws when
  // the navigation itself fails, with the browser's error text.
  async goto(url, { timeoutMs = 25000 } = {}) {
    let off;
    const loaded = new Promise((resolve) => { off = this.on('Page.loadEventFired', () => resolve('load')); });
    const nav = await this.send('Page.navigate', { url }, timeoutMs).catch((e) => ({ errorText: e.message }));
    if (nav.errorText && !/ERR_ABORTED/.test(nav.errorText)) { off(); throw new Error(nav.errorText); }
    const how = await Promise.race([loaded, sleep(timeoutMs).then(() => 'timeout')]);
    off();
    return how;
  }

  // Evaluates a function (serialised) in the page and returns its JSON value.
  async eval(fn, arg) {
    const expression = `(${fn.toString()})(${arg === undefined ? '' : JSON.stringify(arg)})`;
    const r = await this.send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true }, 30000);
    if (r.exceptionDetails) {
      throw new Error('page eval: ' + (r.exceptionDetails.exception?.description || r.exceptionDetails.text));
    }
    return r.result?.value;
  }
}
