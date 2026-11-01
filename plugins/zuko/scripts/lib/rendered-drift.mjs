// The rendered drift gate. Run by check-rendered-drift.sh, which has already
// checked Node and put the design system's token files in ZUKO_TOKEN_FILES.
//
// Each page is opened in headless Chrome twice: light, then dark (the media
// query, class="dark" and data-theme="dark"). A judge runs inside the page and
// compares each element's computed colours, font size, font family and corner
// radii with the token values that the same page resolves.
//
// Exit 0: every value is a token. Exit 1: drift, or nothing to compare
// against. Exit 2: could not render. A run that rendered nothing is never 0.
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { basename, extname, join, relative, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { Browser, findChrome } from './cdp.mjs';

const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1']);
const SKIP_DIRS = new Set(['node_modules', '.git', 'dist', 'build', '.next']);
const MAX_LINES = 20;
const err = [];
const say = (line) => err.push(line);

// Write everything, then exit once both streams have flushed: Node stays alive
// for many seconds on open CDP timers, and a bare exit can cut a piped write.
function finish(code, stdout = '') {
  const text = err.length ? err.join('\n') + '\n' : '';
  process.stderr.write(text, () => process.stdout.write(stdout, () => process.exit(code)));
}

const shown = (p) => relative(process.cwd(), p).split('\\').join('/') || '.';

// --- Targets: files, folders of .html files, and localhost URLs only. -------
function sortTargets(args) {
  const pages = [], missing = [];
  for (const a of args) {
    if (/^[a-z][a-z0-9+.-]*:/i.test(a) && !/^[a-z]:[\\/]/i.test(a)) {
      let u = null;
      try { u = new URL(a); } catch {}
      if (!u || !['http:', 'https:'].includes(u.protocol) || !LOCAL_HOSTS.has(u.hostname)) {
        say(`Rendered drift check refused ${a}: only localhost and 127.0.0.1 may be opened.`);
        return null;
      }
      pages.push({ label: a, url: u.href });
    } else if (!existsSync(a)) {
      missing.push(a);
    } else if (statSync(a).isDirectory()) {
      const walk = (dir) => {
        for (const name of readdirSync(dir).sort()) {
          const p = join(dir, name);
          if (statSync(p).isDirectory()) { if (!SKIP_DIRS.has(name)) walk(p); }
          else if (/\.html?$/i.test(name)) pages.push({ label: shown(p), url: pathToFileURL(resolve(p)).href });
        }
      };
      walk(a);
    } else if (/\.html?$/i.test(extname(a))) {
      pages.push({ label: shown(a), url: pathToFileURL(resolve(a)).href });
    }
  }
  if (!pages.length) {
    say(args.length
      ? `Rendered drift check rendered NOTHING: no .html file or localhost URL in ${args.join(' ')}.`
      : 'Rendered drift check rendered NOTHING: no target given. Pass the preview file or its localhost URL.');
    return null;
  }
  if (missing.length) say(`Rendered drift check skipped these paths, which do not exist: ${missing.join(' ')}`);
  return pages;
}

// --- Tokens: the custom properties that the CSS token files declare. --------
function readTokens() {
  const files = (process.env.ZUKO_TOKEN_FILES || '').split('\n').map((f) => f.trim()).filter(Boolean);
  const names = new Set(), from = new Set();
  for (const f of files.filter((f) => /\.css$/i.test(f))) {
    let text = '';
    try { text = readFileSync(f, 'utf8').replace(/\/\*[\s\S]*?\*\//g, ''); } catch { continue; }
    for (const m of text.matchAll(/(--[A-Za-z0-9_-]+)\s*:/g)) { names.add(m[1]); from.add(shown(f)); }
  }
  if (names.size) return { names: [...names], from: [...from] };
  const tw = files.find((f) => /^tailwind\.config\./.test(basename(f)));
  if (tw) {
    say(`Rendered drift check could not run: the tokens live in ${basename(tw)}, not in CSS variables.`);
    return { code: 2 };
  }
  say('Rendered drift check has nothing to compare against: no design system token file found.');
  return { code: 1 };
}

// --- The judge. Runs inside the page; it must not use anything from here. ---
async function judge({ names, dark }) {
  const root = document.documentElement;
  if (dark) { root.classList.add('dark'); root.setAttribute('data-theme', 'dark'); }
  await Promise.race([document.fonts.ready, new Promise((r) => setTimeout(r, 1000))]);
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));

  // Chrome keeps oklch() and lab() values as written, so every colour is
  // painted on a canvas and read back as 8-bit sRGB before it is compared.
  const ctx = Object.assign(document.createElement('canvas'), { width: 1, height: 1 }).getContext('2d', { willReadFrequently: true });
  const cache = new Map();
  const rgba = (v) => {
    if (!cache.has(v)) {
      ctx.clearRect(0, 0, 1, 1); ctx.fillStyle = 'rgba(0, 0, 0, 0)'; ctx.fillStyle = v; ctx.fillRect(0, 0, 1, 1);
      cache.set(v, [...ctx.getImageData(0, 0, 1, 1).data]);
    }
    return cache.get(v);
  };
  const firstFamily = (v) => v.split(',')[0].trim().replace(/^["']|["']$/g, '').toLowerCase();

  const colours = [], sizes = [], radii = [], families = [];
  const probe = document.createElement('div');
  probe.style.cssText = 'position:absolute;visibility:hidden';
  document.body.appendChild(probe);
  const rootStyle = getComputedStyle(root);
  let loaded = 0;
  for (const name of names) {
    const raw = rootStyle.getPropertyValue(name).trim();
    if (!raw) continue;
    loaded++;
    if (CSS.supports('color', raw)) { colours.push({ name, raw, px: rgba(raw) }); continue; }
    const isRadius = /radius|rounded/i.test(name);
    if (/%$/.test(raw) && isRadius) { radii.push({ name, raw, pct: raw }); continue; }
    if (CSS.supports('width', raw) && !/%/.test(raw)) {
      probe.style.width = raw;
      const px = parseFloat(getComputedStyle(probe).width);
      if (!Number.isNaN(px)) (isRadius ? radii : sizes).push({ name, raw, px });
      continue;
    }
    if (/font|family/i.test(name) || /[,"']/.test(raw)) families.push({ name, raw, first: firstFamily(raw) });
  }
  probe.remove();

  const found = [];
  const nearestBy = (list, dist) => list.reduce((best, t) => (best && dist(best) <= dist(t) ? best : t), null);
  const label = (t) => (t ? `${t.name} ${t.raw}` : '');
  const checkColour = (sel, prop, v) => {
    const px = rgba(v);
    if (px[3] === 0) return;
    if (colours.some((t) => t.px.every((c, i) => Math.abs(c - px[i]) <= 1))) return;
    const near = nearestBy(colours, (t) => Math.hypot(t.px[0] - px[0], t.px[1] - px[1], t.px[2] - px[2]));
    found.push({ sel, prop, value: v, nearest: label(near) });
  };
  const checkLength = (list, sel, prop, v) => {
    if (v.includes('%')) { if (!list.some((t) => t.pct === v.trim())) found.push({ sel, prop, value: v, nearest: '' }); return; }
    const px = parseFloat(v);
    if (list.some((t) => t.px !== undefined && Math.abs(t.px - px) <= 0.5)) return;
    found.push({ sel, prop, value: v, nearest: label(nearestBy(list.filter((t) => t.px !== undefined), (t) => Math.abs(t.px - px))) });
  };
  const checkFamily = (sel, v) => {
    const first = firstFamily(v);
    if (families.some((t) => t.first === first)) return;
    found.push({ sel, prop: 'font-family', value: v, nearest: label(families[0]) });
  };

  const NO_BOX = new Set(['SCRIPT', 'STYLE', 'TEMPLATE', 'NOSCRIPT', 'BR']);
  const MEDIA = 'img, svg, video, canvas, iframe, picture, object, embed';
  let judged = 0;
  for (const el of [document.body, ...document.body.querySelectorAll('*')]) {
    if (NO_BOX.has(el.tagName) || el.closest(MEDIA) || !el.getClientRects().length) continue;
    judged++;
    const s = getComputedStyle(el);
    const tag = el.tagName.toLowerCase();
    const sel = tag + (el.id ? '#' + el.id : el.classList.length ? '.' + el.classList[0] : '');
    const ownText = [...el.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim());
    if (ownText) {
      checkColour(sel, 'color', s.color);
      checkLength(sizes, sel, 'font-size', s.fontSize);
      checkFamily(sel, s.fontFamily);
    }
    checkColour(sel, 'background-color', s.backgroundColor);
    for (const side of ['top', 'right', 'bottom', 'left']) {
      if (parseFloat(s.getPropertyValue(`border-${side}-width`)) > 0 && s.getPropertyValue(`border-${side}-style`) !== 'none') {
        checkColour(sel, `border-${side}-color`, s.getPropertyValue(`border-${side}-color`));
      }
    }
    if (s.outlineStyle !== 'none' && parseFloat(s.outlineWidth) > 0) checkColour(sel, 'outline-color', s.outlineColor);
    for (const corner of ['top-left', 'top-right', 'bottom-right', 'bottom-left']) {
      const v = s.getPropertyValue(`border-${corner}-radius`);
      if (parseFloat(v) > 0) checkLength(radii, sel, `border-${corner}-radius`, v.split(' ')[0]);
    }
  }
  return { judged, loaded, found };
}

// --- The report. -------------------------------------------------------------
const cell = (s, n) => (s.length >= n ? s + ' ' : s.padEnd(n));

function merge(light, dark) {
  const rows = new Map();
  for (const [mode, r] of [['light', light], ['dark', dark]]) {
    const counts = new Map();
    for (const f of r.found) {
      const key = `${f.sel}\u0000${f.prop}\u0000${f.value}`;
      counts.set(key, (counts.get(key) || 0) + 1);
      if (!rows.has(key)) rows.set(key, { ...f, modes: new Set(), count: 0 });
      rows.get(key).modes.add(mode);
    }
    for (const [key, n] of counts) rows.get(key).count = Math.max(rows.get(key).count, n);
  }
  return [...rows.values()].map((r) => ({ ...r, mode: r.modes.size === 2 ? 'both' : [...r.modes][0] }));
}

function lineOf(r) {
  const count = r.count > 1 ? 'x' + r.count : '';
  const near = r.nearest ? 'nearest ' + r.nearest : 'no token of this kind';
  return '  ' + cell(r.mode, 6) + cell(r.sel, 21) + cell(r.prop, 17) + cell(r.value, 17) + cell(count, 3) + near;
}

// --- Main. -------------------------------------------------------------------
async function main() {
  const pages = sortTargets(process.argv.slice(2));
  if (!pages) return finish(2);
  const tokens = readTokens();
  if (tokens.code) return finish(tokens.code);

  const exe = findChrome();
  if (!exe) {
    say(process.env.CHROME_PATH
      ? `Rendered drift check could not run: CHROME_PATH is ${process.env.CHROME_PATH}, and no browser is there.`
      : 'Rendered drift check could not run: no Chrome, Edge or Chromium found. Install one, or set CHROME_PATH.');
    return finish(2);
  }

  let browser;
  try { browser = await Browser.launch(exe); } catch (e) {
    say(`Rendered drift check could not load ${pages[0].label}: ${e.message}.`);
    return finish(2);
  }
  const page = await browser.newPage();
  const blocked = new Map();
  page.on('Fetch.requestPaused', (p) => {
    let ok = false, host = '';
    try {
      const u = new URL(p.request.url);
      host = u.hostname;
      ok = ['file:', 'data:', 'blob:'].includes(u.protocol) || (['http:', 'https:'].includes(u.protocol) && LOCAL_HOSTS.has(u.hostname));
    } catch {}
    if (ok) return page.send('Fetch.continueRequest', { requestId: p.requestId }).catch(() => {});
    blocked.set(p.request.url, host);
    return page.send('Fetch.failRequest', { requestId: p.requestId, errorReason: 'BlockedByClient' }).catch(() => {});
  });
  await page.send('Fetch.enable', { patterns: [{ urlPattern: '*' }] });

  let code = 0, judged = 0, loaded = 0;
  const report = [];
  let total = 0;
  for (const target of pages) {
    const result = {};
    try {
      for (const mode of ['light', 'dark']) {
        await page.send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-color-scheme', value: mode }] });
        await page.goto(target.url);
        result[mode] = await page.eval(judge, { names: tokens.names, dark: mode === 'dark' });
      }
    } catch (e) {
      say(`Rendered drift check could not load ${target.label}: ${e.message.replace(/^net::/, '')}.`);
      code = 2;
      continue;
    }
    if (!result.light.loaded && !result.dark.loaded) {
      say(`Rendered drift check has nothing to compare against: ${target.label} loads none of the ${tokens.names.length} tokens in ${tokens.from.join(', ')}.`);
      if (code === 0) code = 1;
      continue;
    }
    judged += result.light.judged;
    loaded = Math.max(loaded, result.light.loaded, result.dark.loaded);
    const rows = merge(result.light, result.dark);
    if (!rows.length) continue;
    if (code === 0) code = 1;
    total += rows.length;
    report.push('', target.label, ...rows.slice(0, MAX_LINES).map(lineOf));
    if (rows.length > MAX_LINES) report.push(`  ... and ${rows.length - MAX_LINES} more`);
  }
  await browser.close();

  if (blocked.size) {
    const hosts = [...new Set(blocked.values())].join(', ');
    say(`Rendered drift check blocked ${blocked.size} request${blocked.size === 1 ? '' : 's'} to other hosts: ${hosts}.`);
  }
  const n = pages.length, pl = n === 1 ? '' : 's';
  if (total) {
    const head = `Rendered drift check FAILED: ${total} value${total === 1 ? '' : 's'} over ${n} page${pl} ${total === 1 ? 'is' : 'are'} not design system tokens.`;
    const tail = ['', 'Fix these with tokens and re-render before showing the user. A value the system lacks is a proposal to the system, not a one-off.'];
    return finish(code, [head, ...report, ...tail].join('\n') + '\n');
  }
  if (code !== 0) return finish(code);
  return finish(0, `Rendered drift check passed: ${judged} elements over ${n} page${pl}, light and dark, against ${loaded} token values.\n`);
}

main().catch((e) => { say(`Rendered drift check could not run: ${e.message}.`); finish(2); });
