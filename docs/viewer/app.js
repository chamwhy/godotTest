/* bsk 레벨 뷰어 — data.js(window.LEVEL_DATA)를 읽어 맵을 그리고 해답을 재생한다. */
(() => {
  "use strict";
  const D = window.LEVEL_DATA;
  const app = document.getElementById("app");
  if (!D) { app.textContent = "data.js 를 불러오지 못했다."; return; }

  const RES = "viewer/res/";
  const T = 256;                         // 원본 타일 픽셀
  const PAD = 0.12;                      // 맵 둘레 여백 (타일 단위)
  const MAX_CELL = 104;                  // 화면상 한 칸 최대 크기(px)
  const RANK = { trap: 0, wall: 1, healItem: 2, cocoon: 3, worldPortal: 10, clear: 11, moveBox: 20, player: 90 };
  const EMO = ["평온", "화남", "격노"];
  const emoOf = (hp) => (hp >= 4 ? 0 : hp >= 2 ? 1 : 2);
  const ARROW = { U: "↑", D: "↓", L: "←", R: "→" };
  const KEYNAME = { U: "위", D: "아래", L: "왼쪽", R: "오른쪽" };
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // ── 작은 DOM 도우미
  function h(tag, attrs, ...kids) {
    const el = document.createElement(tag);
    if (attrs) for (const [k, v] of Object.entries(attrs)) {
      if (v == null || v === false) continue;
      if (k === "class") el.className = v;
      else if (k === "html") el.innerHTML = v;
      else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
      else if (k === "style" && typeof v === "object") Object.assign(el.style, v);
      else el.setAttribute(k, v === true ? "" : v);
    }
    for (const c of kids.flat()) if (c != null && c !== false) el.append(c.nodeType ? c : String(c));
    return el;
  }
  const url = (p) => RES + p.replace(/^03_Resources\//, "");
  const hash = (a, b, c = 0) => { let x = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791); x = (x ^ (x >>> 13)) * 1274126177; return (x ^ (x >>> 16)) >>> 0; };
  const strHash = (s) => { let x = 0; for (const ch of s) x = (x * 31 + ch.charCodeAt(0)) >>> 0; return x; };

  // ── 이미지
  const IMG = {};
  function loadImages() {
    return Promise.all(Object.keys(D.sizes).map((p) => new Promise((res) => {
      const im = new Image();
      im.onload = im.onerror = () => res();
      im.src = url(p);
      IMG[p] = im;
    })));
  }
  const TINT = {};
  function tinted(p, color) {
    const key = p + color;
    if (TINT[key]) return TINT[key];
    const im = IMG[p];
    const c = document.createElement("canvas");
    c.width = im.naturalWidth || T; c.height = im.naturalHeight || T;
    const x = c.getContext("2d");
    x.drawImage(im, 0, 0);
    x.globalCompositeOperation = "multiply"; x.fillStyle = color; x.fillRect(0, 0, c.width, c.height);
    x.globalCompositeOperation = "destination-in"; x.drawImage(im, 0, 0);
    return (TINT[key] = c);
  }
  const pick = (list, anim) => (list && list.length ? list[anim % list.length] : null);

  // ── 전역 최댓값 (지표 막대용)
  const allLevels = D.worlds.flatMap((w) => w.levels);
  const playable = allLevels.filter((l) => !l.hub);
  const maxStates = Math.max(...playable.map((l) => l.metrics.states));

  // ─────────────────────────────────────── 맵 뷰
  let anim = 0;
  const views = [];

  class MapView {
    constructor(lv) {
      this.lv = lv;
      this.frames = lv.frames && lv.frames.length ? lv.frames : [this.staticFrame()];
      this.idx = 0;
      this.grid = false;
      this.visible = false;
      this.timer = null;
      this.cols = lv.w + PAD * 2;
      this.rows = lv.h + PAD * 2;
      this.canvas = h("canvas", { role: "img", "aria-label": `${lv.key} ${lv.name} 지도, ${lv.w}×${lv.h}칸` });
      this.state = h("div", { class: "map-state", "aria-live": "polite" });
      this.frame = h("div", {
        class: "map-frame", tabindex: "0", style: { maxWidth: Math.round(this.cols * MAX_CELL) + "px" },
        "aria-label": "지도 — 왼쪽/오른쪽 방향키로 한 수씩 이동",
      }, this.canvas);
      this.frame.addEventListener("keydown", (e) => {
        if (e.key === "ArrowRight") { this.go(this.idx + 1); e.preventDefault(); }
        if (e.key === "ArrowLeft") { this.go(this.idx - 1); e.preventDefault(); }
      });
      this.cocoons = lv.ents.filter((e) => e.t === "cocoon").map((e) => e.id);
      this.onChange = null;
      new ResizeObserver(() => this.draw()).observe(this.frame);
      views.push(this);
    }
    staticFrame() {
      const p = this.lv.ents.find((e) => e.t === "player");
      const bx = {};
      for (const e of this.lv.ents) if (e.t === "moveBox") bx[e.id] = [e.x, e.y];
      return { k: null, p: p ? [p.x, p.y] : [0, 0], hp: p ? (p.ch ?? p.mh ?? 6) : 6, rm: [], bx, d: false, f: false, c: false };
    }
    lookRight() {
      let r = true;
      for (let i = 1; i <= this.idx; i++) { const k = this.frames[i].k; if (k === "L") r = false; else if (k === "R") r = true; }
      return r;
    }
    go(i) {
      i = Math.max(0, Math.min(this.frames.length - 1, i));
      if (i === this.idx) return;
      this.idx = i;
      this.draw();
      if (this.onChange) this.onChange();
    }
    play() {
      if (this.timer) { this.stop(); return; }
      if (this.idx >= this.frames.length - 1) this.idx = 0;
      this.timer = setInterval(() => {
        if (this.idx >= this.frames.length - 1) { this.stop(); return; }
        this.go(this.idx + 1);
      }, 650);
      this.draw(); if (this.onChange) this.onChange();
    }
    stop() { clearInterval(this.timer); this.timer = null; if (this.onChange) this.onChange(); }

    draw() {
      const lv = this.lv;
      const cssW = this.frame.clientWidth;
      if (!cssW) return;
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const W = Math.round(cssW * dpr), H = Math.round(cssW * dpr * this.rows / this.cols);
      if (this.canvas.width !== W || this.canvas.height !== H) { this.canvas.width = W; this.canvas.height = H; }
      const ctx = this.canvas.getContext("2d");
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.clearRect(0, 0, W, H);
      const s = W / (this.cols * T);
      ctx.setTransform(s, 0, 0, s, PAD * T * s, PAD * T * s);
      ctx.imageSmoothingQuality = "high";
      const a = reduceMotion ? 0 : anim;
      const tile = (x, y) => (y >= 0 && y < lv.h && x >= 0 && x < lv.w && lv.tiles[y][x] ? 1 : 0);

      // 바닥 — Tile.update_tile_sprites 와 같은 3비트 규칙
      const Q = D.draw.tile;
      for (let y = 0; y < lv.h; y++) for (let x = 0; x < lv.w; x++) {
        if (!tile(x, y)) continue;
        const S = (r, c) => tile(x + c - 1, y + r - 1);
        const ul = S(0, 1) * 4 + S(0, 0) * 2 + S(1, 0);
        const ur = S(1, 2) * 4 + S(0, 2) * 2 + S(0, 1);
        const dl = S(1, 0) * 4 + S(2, 0) * 2 + S(2, 1);
        const dr = S(2, 1) * 4 + S(2, 2) * 2 + S(1, 2);
        const X = x * T, Y = y * T, hT = T / 2;
        const parts = [[Q.ul[ul], X, Y], [Q.ur[ur], X + hT, Y], [Q.dl[dl], X, Y + hT], [Q.dr[dr], X + hT, Y + hT]];
        for (const [list, px, py] of parts) { const p = pick(list, a); if (p) ctx.drawImage(IMG[p], px, py, hT, hT); }
        const hs = hash(x, y, strHash(lv.key));
        if (hs % 100 < 50) ctx.drawImage(IMG[D.draw.dust[(hs >>> 8) % D.draw.dust.length]], X + T / 4, Y + T / 4, hT, hT);
      }

      // 개체 — y 다음 스폰 순서(EntitySpawner.RANK)
      const fr = this.frames[this.idx];
      const rm = new Set(fr.rm);
      const gated = this.cocoons.some((id) => !rm.has(id));
      const items = [];
      for (const e of lv.ents) {
        if (rm.has(e.id)) continue;
        let x = e.x, y = e.y;
        if (e.t === "moveBox") { const b = fr.bx[e.id]; if (!b) continue; [x, y] = b; }
        if (e.t === "player") [x, y] = fr.p;
        items.push({ e, x, y });
      }
      items.sort((p, q) => p.y - q.y || (RANK[p.e.t] ?? 99) - (RANK[q.e.t] ?? 99) || p.e.id - q.e.id);
      for (const { e, x, y } of items) {
        const X = x * T, Y = y * T;
        ctx.save();
        let img = null;
        switch (e.t) {
          case "trap": img = e.once ? pick(D.draw.trapOnce[0], a) : pick(D.draw.trap[Math.min(Math.max((e.atk || 1) - 1, 0), 2)], a); break;
          case "wall": img = e.ma ? pick(D.draw.wallBreakable[Math.min(e.ma - 1, 1)], a)
                                  : pick(D.draw.wallRandom[hash(e.x, e.y, strHash(lv.key)) % D.draw.wallRandom.length], a); break;
          case "healItem": img = pick(D.draw.healItem, a); break;
          case "cocoon": img = pick(D.draw.cocoon, a); break;
          case "moveBox": img = pick(D.draw.moveBox, a); break;
          case "clear": img = pick(D.draw.clear, a); if (gated) ctx.globalAlpha = 0.5; break;
          case "worldPortal": {
            const bg = pick(D.draw.worldPortal, a);
            if (bg) ctx.drawImage(tinted(bg, "#8dc977"), X, Y, T, T);
            const n = e.num ?? e.to_s ?? 0;
            const num = pick(D.draw.numbers[n], 0);
            if (num) ctx.drawImage(IMG[num], X, Y, T, T);
            break;
          }
          case "player": {
            img = pick(D.draw.player[emoOf(fr.hp)], a);
            if (fr.d) ctx.globalAlpha = 0.45;
            if (fr.f) ctx.globalAlpha = 0.25;
            if (!this.lookRight()) { ctx.translate(X + T, Y); ctx.scale(-1, 1); ctx.drawImage(IMG[img], 0, 0, T, T); img = null; }
            break;
          }
        }
        if (img) ctx.drawImage(IMG[img], X, Y, T, T);
        ctx.restore();
      }

      // 좌표·격자 보기
      if (this.grid) {
        ctx.save();
        ctx.lineWidth = 3; ctx.strokeStyle = "rgba(0,0,0,.18)";
        for (let x = 0; x <= lv.w; x++) { ctx.beginPath(); ctx.moveTo(x * T, 0); ctx.lineTo(x * T, lv.h * T); ctx.stroke(); }
        for (let y = 0; y <= lv.h; y++) { ctx.beginPath(); ctx.moveTo(0, y * T); ctx.lineTo(lv.w * T, y * T); ctx.stroke(); }
        ctx.setLineDash([18, 14]); ctx.lineWidth = 8; ctx.strokeStyle = "rgba(180,40,40,.75)";
        for (const e of lv.ents) if (!tile(e.x, e.y) && !rm.has(e.id) && e.t !== "moveBox" && e.t !== "player") ctx.strokeRect(e.x * T + 14, e.y * T + 14, T - 28, T - 28);
        ctx.setLineDash([]);
        ctx.font = "bold 44px system-ui, sans-serif"; ctx.fillStyle = "rgba(0,0,0,.55)";
        for (let y = 0; y < lv.h; y++) for (let x = 0; x < lv.w; x++) ctx.fillText(`${x},${y}`, x * T + 12, y * T + 50);
        ctx.restore();
      }
      this.renderState(fr, gated);
    }
    renderState(fr, gated) {
      const lv = this.lv;
      const emo = emoOf(fr.hp);
      const pills = [];
      const face = pick(D.draw.player[emo], 0);
      pills.push(h("span", { class: "pill" }, h("img", { src: url(face), alt: "" }),
        h("span", null, "체력 ", h("b", null, fr.hp), " · ", h("span", { class: "e" + emo }, EMO[emo]))));
      if (this.cocoons.length) {
        const left = this.cocoons.filter((id) => !fr.rm.includes(id)).length;
        pills.push(h("span", { class: "pill plain" }, `누에고치 ${left}/${this.cocoons.length}`, left ? "" : " · 실타래 켜짐"));
      }
      if (fr.d) pills.push(h("span", { class: "pill bad" }, "사망"));
      if (fr.f) pills.push(h("span", { class: "pill bad" }, "낙하"));
      if (fr.c) pills.push(h("span", { class: "pill good" }, "클리어"));
      this.state.replaceChildren(...pills);
    }
  }

  // ─────────────────────────────────────── 카드
  function stat(k, v, sub, ratio, title) {
    return h("div", { class: "stat", title: title || null },
      h("div", { class: "k" }, k),
      h("div", { class: "v" }, v, sub ? h("small", null, " ", sub) : null),
      ratio != null ? h("div", { class: "meter", "aria-hidden": "true" }, h("i", { style: { width: Math.max(3, Math.round(ratio * 100)) + "%" } })) : null);
  }

  function levelCard(lv) {
    const d = lv.desc || {};
    const p = lv.ents.find((e) => e.t === "player");
    const startHp = p ? (p.ch ?? p.mh ?? 6) : 6;
    const badges = [h("span", { class: "badge" }, `${lv.w}×${lv.h}`)];
    if (lv.hub) badges.push(h("span", { class: "badge accent" }, "허브"));
    else badges.push(h("span", { class: "badge" }, `시작 체력 ${startHp} · ${EMO[emoOf(startHp)]}`));
    if (lv.legacy) badges.push(h("span", { class: "badge warn" }, "레거시 — 게임에서 로드 안 됨"));
    if (lv.missing && lv.missing.length) badges.push(h("span", { class: "badge warn" }, "연결 파일 없음"));

    const view = new MapView(lv);
    const mapCol = h("div", { class: "map-col" }, view.frame, view.state);

    if (!lv.hub) {
      const btn = (label, aria, fn, cls) => h("button", { type: "button", class: cls || null, "aria-label": aria, title: aria, onclick: fn }, label);
      const bFirst = btn("⏮", "처음으로", () => { view.stop(); view.go(0); });
      const bPrev = btn("◀", "한 수 뒤로", () => { view.stop(); view.go(view.idx - 1); });
      const bPlay = btn("재생", "해답 재생 / 정지", () => view.play(), "primary");
      const bNext = btn("▶", "한 수 앞으로", () => { view.stop(); view.go(view.idx + 1); });
      const bLast = btn("⏭", "끝으로", () => { view.stop(); view.go(view.frames.length - 1); });
      const step = h("span", { class: "step" });
      const moves = h("ol", { class: "moves", "aria-label": "최단 해답 — 누르면 그 수로 이동" });
      const mbtns = [...lv.solution].map((k, i) => {
        const b = h("button", { type: "button", "aria-label": `${i + 1}수: ${KEYNAME[k]}`, title: `${i + 1}수: ${KEYNAME[k]}`, onclick: () => { view.stop(); view.go(i + 1); } }, ARROW[k]);
        moves.append(h("li", null, b));
        return b;
      });
      const sync = () => {
        const n = view.frames.length - 1;
        const k = view.frames[view.idx].k;
        step.textContent = view.idx === 0 ? `시작 · 0/${n}` : `${view.idx}/${n} · ${KEYNAME[k]}`;
        bPlay.textContent = view.timer ? "정지" : "재생";
        bFirst.disabled = bPrev.disabled = view.idx === 0;
        bNext.disabled = bLast.disabled = view.idx === n;
        mbtns.forEach((b, i) => { b.className = i + 1 === view.idx ? "cur" : i + 1 < view.idx ? "done" : ""; });
      };
      view.onChange = sync;
      sync();
      mapCol.append(h("div", { class: "controls" }, bFirst, bPrev, bPlay, bNext, bLast, step), moves);
    }
    const gridToggle = h("input", { type: "checkbox", onchange: (e) => { view.grid = e.target.checked; view.draw(); } });
    mapCol.append(h("div", { class: "toggles" }, h("label", { title: "칸 좌표(x,y)와 격자를 그린다. 빨간 점선 = 아래가 구멍인 칸에 떠 있는 개체" }, gridToggle, "좌표·격자 보기")));

    // 정보 칸
    const info = h("div", { class: "info-col" });
    if (!lv.hub && d.tags && d.tags.length) info.append(h("div", { class: "tags" }, d.tags.map((t) => h("span", { class: "tag" }, t))));
    if (!lv.hub) {
      const m = lv.metrics;
      const pct = m.alive ? Math.round((100 * m.locks) / m.alive) : 0;
      info.append(h("div", { class: "stats" },
        stat("최단 수", m.shortest, "수"),
        stat("탐색 상태", m.states, "개", m.states / maxStates, "도달 가능한 모든 상태 수. 막대는 전체 레벨 최댓값 대비"),
        stat("소프트락", pct + "%", `${m.locks}/${m.alive}`, pct / 100, "살아 있지만 이미 클리어가 불가능한 상태의 비율"),
        stat("사망 · 낙하", `${m.dead} · ${m.fallen}`, "상태", null, "죽음/낙하로 끝나는 상태 수 — 실패가 '정보'가 되는 면적"),
        stat("필수 감정", m.required.length ? m.required.join(" · ") : "없음", null, null, "이 감정을 금지하면 클리어 불가"),
        stat("고치 · 상자", `${m.cocoons} · ${m.boxes}`, null)));
    }
    const rows = [];
    const add = (cls, k, v) => { if (v) rows.push(h("dt", { class: cls }, k), h("dd", null, v)); };
    add("", "가르치는 것", d.teach);
    add("belief", "플레이어가 처음 믿는 것", d.belief);
    add("insight", "깨닫는 것", d.insight);
    add("", "해답 흐름", d.flow);
    add("", "함정", d.traps);
    add("", "메모", d.notes);
    if (rows.length) info.append(h("div", { class: "desc" }, h("dl", null, rows)));
    if (!lv.hub && lv.metrics.cocoonKillers.length) {
      info.append(h("p", { class: "source" }, "누에고치를 깰 수 있는 수단 — ",
        lv.metrics.cocoonKillers.map((c) => `(${c.x},${c.y}) ${c.by}`).join(" · ")));
    }
    if (lv.hub) {
      if (lv.missing && lv.missing.length) info.append(h("div", { class: "warnbox" },
        "연결된 맵 파일이 없는 포탈: ", lv.missing.map((m) => `(${m.x},${m.y}) → ${m.file}`).join(", "),
        " — 밟으면 MapLoader 가 로드에 실패한다."));
      info.append(h("pre", { class: "hub" }, lv.hubText));
    }
    info.append(h("p", { class: "source" }, "맵 파일 ", h("code", null, lv.file), d.source ? ` · 근거: ${d.source}` : ""));

    return h("article", { class: "level", id: "lv-" + lv.key },
      h("div", { class: "level-head" },
        h("div", { class: "key" }, lv.key.replace("v1_", "v1 · ") + " · " + lv.name),
        h("h3", null, d.title || lv.name),
        h("div", { class: "badges" }, badges)),
      h("div", { class: "level-body" }, mapCol, info));
  }

  // ─────────────────────────────────────── 난이도 곡선 (단일 계열 막대)
  function curve(world) {
    const ls = world.levels.filter((l) => !l.hub);
    if (ls.length < 2) return null;
    const max = Math.max(...ls.map((l) => l.metrics.shortest));
    const top = Math.ceil(max / 5) * 5;
    const tip = h("div", { class: "tip", role: "status" });
    const ticks = [0, top / 2, top].map((v) => h("div", { class: "tick", style: { bottom: (v / top) * 100 + "%" } }, h("span", null, v)));
    const cols = ls.map((l) => {
      const m = l.metrics;
      const pct = m.alive ? Math.round((100 * m.locks) / m.alive) : 0;
      const label = `${l.key.replace("v1_", "")} ${l.name} — 최단 ${m.shortest}수 · 상태 ${m.states} · 소프트락 ${pct}%`;
      const b = h("button", {
        type: "button", class: "col", "aria-label": label,
        onclick: () => document.getElementById("lv-" + l.key).scrollIntoView({ behavior: reduceMotion ? "auto" : "smooth" }),
      }, h("span", { class: "bar", style: { height: (m.shortest / top) * 100 + "%" } }));
      const show = () => {
        tip.textContent = label;
        const r = b.getBoundingClientRect(), pr = wrap.getBoundingClientRect();
        const bar = b.firstChild.getBoundingClientRect();
        let x = r.left + r.width / 2 - pr.left;
        tip.style.left = x + "px"; tip.style.top = bar.top - pr.top + "px";
        tip.classList.add("on");
        const tr = tip.getBoundingClientRect();     // 가장자리에서 잘리지 않게
        if (tr.left < pr.left + 4) tip.style.left = x + (pr.left + 4 - tr.left) + "px";
        if (tr.right > pr.right - 4) tip.style.left = x - (tr.right - pr.right + 4) + "px";
      };
      b.addEventListener("pointerenter", show); b.addEventListener("focus", show);
      b.addEventListener("pointerleave", () => tip.classList.remove("on")); b.addEventListener("blur", () => tip.classList.remove("on"));
      return h("div", { class: "colwrap" }, b, h("span", { class: "x" }, String(l.stage ?? "").padStart(2, "0")));
    });
    const table = h("table", null,
      h("thead", null, h("tr", null, h("th", null, "맵"), h("th", null, "이름"), h("th", { class: "num" }, "최단"), h("th", { class: "num" }, "상태"), h("th", { class: "num" }, "소프트락"), h("th", null, "필수 감정"))),
      h("tbody", null, ls.map((l) => {
        const m = l.metrics; const pct = m.alive ? Math.round((100 * m.locks) / m.alive) : 0;
        return h("tr", null, h("td", null, h("a", { href: "#lv-" + l.key }, l.key.replace("v1_", ""))), h("td", null, l.name),
          h("td", { class: "num" }, m.shortest), h("td", { class: "num" }, m.states), h("td", { class: "num" }, pct + "%"), h("td", null, m.required.join(" · ")));
      })));
    const wrap = h("div", { class: "curve" },
      h("h3", null, "최단 수 곡선"),
      h("p", { class: "cap" }, "스테이지별 최단 해답 길이. 막대를 누르면 그 맵으로 이동, 올리면 상태 수·소프트락까지 보인다."),
      h("div", { class: "plot" }, h("div", { class: "ticks", "aria-hidden": "true" }, ticks), h("div", { class: "cols" }, cols)),
      tip,
      h("details", { class: "table" }, h("summary", null, "표로 보기"), h("div", { class: "tbl-scroll" }, table)));
    return wrap;
  }

  // ─────────────────────────────────────── 오브젝트 리소스
  function objectsSection() {
    const sec = h("section", { class: "world", id: "objects" },
      h("h2", null, "오브젝트 리소스"),
      h("p", { class: "sub" }, "엔티티 씬(.tscn) → SpriteFrames(.tres) → 그림(.png)을 코드 그대로 추적한 표. 어떤 조건에서 어떤 그림이 쓰이는지, 어떤 효과음을 내는지."));
    const grid = h("div", { class: "objects" });
    for (const o of D.objects) {
      const card = h("div", { class: "obj", id: "obj-" + o.type },
        h("h3", null, o.name, " ", h("span", { class: "badge" }, o.type)),
        h("p", { class: "art" }, o.art));
      for (const v of o.variants) {
        const first = v.pngs[0];
        card.append(h("div", { class: "variant" },
          h("div", { class: "thumb" }, first ? h("img", { src: url(first), alt: v.label, loading: "lazy" }) : null),
          h("div", null,
            h("div", { class: "lbl" }, v.label),
            h("div", { class: "src" }, v.prop, " · ", String(v.src)),
            v.pngs.length > 1 ? h("div", { class: "strip" }, v.pngs.map((p) => h("img", { src: url(p), alt: "", title: p, loading: "lazy" }))) : null,
            h("div", { class: "src" }, v.pngs.length === 1 ? v.pngs[0] : `그림 ${v.pngs.length}장`))));
      }
      card.append(h("div", { class: "paths" }, "씬 ", o.scene, h("br"), "스크립트 ", o.scripts.join(" ← ")));
      card.append(h("div", { class: "codenote" }, o.code));
      if (o.sfx.length) card.append(h("div", { class: "sfx", "aria-label": "효과음" }, o.sfx.map((s) => h("span", null, "♪ " + s))));
      if (o.warn) card.append(h("div", { class: "warnbox" }, o.warn));
      grid.append(card);
    }
    sec.append(grid,
      h("p", { class: "source" }, D.commonSfx),
      h("details", { class: "table" }, h("summary", null, `프로젝트 어디에서도 경로로 참조하지 않는 그림 ${D.unreferenced.length}장`),
        h("ul", { class: "unref" }, D.unreferenced.map((p) => h("li", null, p)))));
    return sec;
  }

  // ─────────────────────────────────────── 읽는 법
  function guideSection() {
    const items = [
      ["감정", "체력 4~6 평온(이동 1·공격 1) / 2~3 화남(이동 1·공격 2) / 1 격노(이동 2·공격 2). 이동한 칸수만큼 공격력이 깎이고 남은 힘으로 앞을 친다."],
      ["가시 · 고추", "상시 함정은 가시 그림(가시 개수 = 피해 1·2·3, 4 이상도 가시 3개 그림). 일회성 함정은 고추 그림(피해량과 무관한 한 그림). 예전 문서의 '고추 n'(상시)은 가시 n이다."],
      ["최단 수", "tools/level_sim 의 너비 우선 탐색으로 찾은 최단 해답 길이. 재생 버튼이 그 해답을 한 수씩 보여 준다."],
      ["탐색 상태", "시작에서 도달 가능한 모든 (위치·체력·남은 개체·상자 위치) 조합의 수. 넓을수록 헤맬 공간이 크다 — 깊이와 같지는 않다."],
      ["소프트락", "살아 있지만 이미 클리어가 불가능해진 상태의 비율. 화면에 아무 표시가 없는 실패라 되돌리기/리셋 버튼이 중요하다."],
      ["필수 감정", "그 감정 상태를 아예 금지하면 클리어할 수 없는 감정."],
      ["시뮬레이터 기준", "저장소 시뮬레이터는 '유령 상자'·'상자가 가시를 지나면 힘이 바뀌는' 두 코드 버그가 고쳐진 상태로 계산한다(docs/08 8절). 2월드 v2 와 1월드는 버그 유무와 무관하게 결과가 같다."],
      ["좌표·격자 보기", "지도 아래 체크박스. 칸 좌표 (x,y)와 격자를 그리고, 아래가 구멍인 칸에 떠 있는 개체(예: 구멍 위 누에고치)를 빨간 점선으로 표시한다. 깨지면 그 칸은 구멍이 된다."],
      ["그리기", "바닥은 게임과 같은 3비트 오토타일로 조립하고, 개체는 y → 스폰 순서로 겹친다. 먼지 장식과 바위 2종의 무작위 선택은 좌표로 고정했다."],
    ];
    return h("section", { class: "world", id: "guide" },
      h("h2", null, "읽는 법"),
      h("div", { class: "guide" }, h("dl", null, items.flatMap(([k, v]) => [h("dt", null, k), h("dd", null, v)]))));
  }

  // ─────────────────────────────────────── 조립
  function build() {
    document.getElementById("loading").remove();
    document.getElementById("meta").textContent =
      `생성 ${D.generated}${D.commit ? " · 커밋 " + D.commit : ""} · 맵 ${allLevels.length}개 · 그림 ${Object.keys(D.sizes).length}장`;
    const nav = document.getElementById("nav");
    const navItems = [];
    for (const w of D.worlds) {
      const sec = h("section", { class: "world", id: w.id },
        h("h2", null, w.title, w.legacy ? h("span", { class: "badge warn", style: { marginLeft: "8px" } }, "레거시") : null),
        h("p", { class: "sub" }, w.subtitle));
      const c = curve(w);
      if (c) sec.append(c);
      for (const lv of w.levels) sec.append(levelCard(lv));
      app.append(sec);
      navItems.push([w.id, w.nav || w.title]);
    }
    app.append(objectsSection(), guideSection());
    navItems.push(["objects", "리소스"], ["guide", "읽는 법"]);
    const links = navItems.map(([id, t]) => h("a", { href: "#" + id }, t));
    nav.append(...links.map((a) => h("li", null, a)));

    // 현재 섹션 표시
    const io = new IntersectionObserver((ents) => {
      for (const e of ents) if (e.isIntersecting) {
        links.forEach((a) => a.setAttribute("aria-current", a.getAttribute("href") === "#" + e.target.id ? "true" : "false"));
        const cur = links.find((a) => a.getAttribute("href") === "#" + e.target.id);
        if (cur) cur.scrollIntoView({ block: "nearest", inline: "nearest" });
      }
    }, { rootMargin: "-40% 0px -55% 0px" });
    document.querySelectorAll("section.world").forEach((s) => io.observe(s));

    // 보이는 지도만 다시 그린다
    const vio = new IntersectionObserver((ents) => {
      for (const e of ents) { const v = views.find((x) => x.frame === e.target); if (v) { v.visible = e.isIntersecting; if (v.visible) v.draw(); } }
    }, { rootMargin: "200px 0px" });
    views.forEach((v) => { vio.observe(v.frame); v.draw(); });
    if (!reduceMotion) setInterval(() => { anim++; views.forEach((v) => v.visible && v.draw()); }, 200);
    if (location.hash) { const t = document.getElementById(location.hash.slice(1)); if (t) t.scrollIntoView(); }
  }

  loadImages().then(build);
})();
