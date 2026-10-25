/* minotaur can think 레벨 디자인 시트 — data.js(window.LEVEL_DATA)를 읽어 모든 맵의 타일·오브젝트 배치를 한 페이지에 그린다.
   플레이/재생 기능은 없다. 맵을 누르면 큰 지도와 설명을 나란히 보여 준다. */
(() => {
  "use strict";
  const D = window.LEVEL_DATA;
  const app = document.getElementById("app");
  if (!D) { app.textContent = "data.js 를 불러오지 못했다."; return; }

  const RES = "viewer/res/";
  const T = 256;                         // 원본 타일 픽셀
  const PAD = 0.1;                       // 맵 둘레 여백 (타일 단위)
  const SIZES = [["작게", 18], ["보통", 30], ["크게", 46]];
  const RANK = { trap: 0, chili: 0, plate: 0, wall: 1, obstacle: 1, cookie: 2, cocoon: 3, worldPortal: 10, clear: 11, stone: 20, goblin: 50, player: 90 };
  const GOB_TINT = Object.assign({ patrol: "#c0e080", chase: "#e08080" }, D.draw.goblinTint || {});   // Goblin._apply_kind_look
  const EMO = ["평온", "화남", "격노"];
  const emoOf = (hp) => (hp >= 4 ? 0 : hp >= 2 ? 1 : 2);
  const ARROW = { U: "↑", D: "↓", L: "←", R: "→" };

  let cell = window.innerWidth < 600 ? 22 : 30;   // 시트의 한 칸 크기(px) — 모든 맵 동일 축척
  let showGrid = false;
  let compact = false;      // 배치만: 카드의 글을 숨기고 지도만

  // ── DOM 도우미
  function h(tag, attrs, ...kids) {
    const el = document.createElement(tag);
    if (attrs) for (const [k, v] of Object.entries(attrs)) {
      if (v == null || v === false) continue;
      if (k === "class") el.className = v;
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
  const first = (list) => (list && list.length ? list[0] : null);

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

  // 고블린 표시 — 게임 화면에는 없는 뷰어 전용 표식. 순찰 = 바라보는 방향 화살표, 추적 = 과녁
  // 발판 — 전용 그림이 없어 게임의 임시 그림(Plate._draw)과 같은 사각형을 그린다
  function plateMark(ctx, X, Y) {
    const s = T * 150 / 256, r = T * 18 / 256;
    ctx.save();
    ctx.lineWidth = T * 6 / 256; ctx.strokeStyle = "#1a1a1a"; ctx.fillStyle = "#dbd6c7";
    ctx.beginPath(); ctx.roundRect(X + (T - s) / 2, Y + (T - s) / 2, s, s, r); ctx.fill(); ctx.stroke();
    ctx.restore();
  }

  function goblinMark(ctx, e, X, Y) {
    const chase = e.move === "chase";
    const [dx, dy] = chase ? [0, 0] : ({ U: [0, -1], D: [0, 1], L: [-1, 0], R: [1, 0] }[e.dir || "R"] || [1, 0]);
    const cx = X + T / 2 + dx * T * 0.34, cy = Y + T / 2 + dy * T * 0.34 + (chase ? T * 0.3 : 0);
    ctx.save();
    ctx.fillStyle = "rgba(40,40,40,.85)";
    ctx.beginPath(); ctx.arc(cx, cy, 40, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = ctx.fillStyle = "#fff"; ctx.lineWidth = 10; ctx.lineCap = "round"; ctx.lineJoin = "round";
    if (chase) {
      ctx.beginPath(); ctx.arc(cx, cy, 22, 0, Math.PI * 2); ctx.stroke();
      ctx.beginPath(); ctx.arc(cx, cy, 7, 0, Math.PI * 2); ctx.fill();
    } else {
      ctx.translate(cx, cy); ctx.rotate(Math.atan2(dy, dx));
      ctx.beginPath(); ctx.moveTo(-20, 0); ctx.lineTo(20, 0); ctx.moveTo(4, -16); ctx.lineTo(20, 0); ctx.lineTo(4, 16); ctx.stroke();
    }
    ctx.restore();
  }

  // ─────────────────────────────────────── 맵 그리기 (JSON 배치 그대로)
  function drawMap(canvas, lv, cellPx, grid) {
    const cols = lv.w + PAD * 2, rows = lv.h + PAD * 2;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const W = Math.round(cols * cellPx * dpr), H = Math.round(rows * cellPx * dpr);
    canvas.width = W; canvas.height = H;
    canvas.style.width = Math.round(cols * cellPx) + "px";
    const ctx = canvas.getContext("2d");
    const s = W / (cols * T);
    ctx.setTransform(s, 0, 0, s, PAD * T * s, PAD * T * s);
    ctx.imageSmoothingQuality = "high";
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
      for (const [list, px, py] of [[Q.ul[ul], X, Y], [Q.ur[ur], X + hT, Y], [Q.dl[dl], X, Y + hT], [Q.dr[dr], X + hT, Y + hT]]) {
        const p = first(list); if (p) ctx.drawImage(IMG[p], px, py, hT, hT);
      }
      const hs = hash(x, y, strHash(lv.key));
      if (hs % 100 < 50) ctx.drawImage(IMG[D.draw.dust[(hs >>> 8) % D.draw.dust.length]], X + T / 4, Y + T / 4, hT, hT);
    }

    // 개체 — y 다음 스폰 순서(EntitySpawner.RANK). 같은 칸에 여럿이면 순서대로 겹친다.
    const gated = lv.ents.some((e) => e.t === "cocoon" || e.t === "plate");
    const items = [...lv.ents].sort((p, q) => p.y - q.y || (RANK[p.t] ?? 99) - (RANK[q.t] ?? 99) || p.id - q.id);
    for (const e of items) {
      const X = e.x * T, Y = e.y * T;
      let img = null;
      ctx.save();
      switch (e.t) {
        case "trap": img = first(D.draw.trap[Math.min(Math.max((e.atk || 1) - 1, 0), 2)]); break;
        case "chili": img = first(D.draw.chili); break;
        case "wall": img = first(D.draw.wall[hash(e.x, e.y, strHash(lv.key)) % D.draw.wall.length]); break;
        case "obstacle": img = first(D.draw.obstacle[Math.min(Math.max((e.ma || 1) - 1, 0), 1)]); break;
        case "cookie": img = first(D.draw.cookie); break;
        case "plate": plateMark(ctx, X, Y); break;
        case "cocoon": img = first(D.draw.cocoon); break;
        case "stone": img = first(D.draw.stone); break;
        case "goblin": {
          const g = first(D.draw.goblin);
          if (g) ctx.drawImage(tinted(g, GOB_TINT[e.move === "chase" ? "chase" : "patrol"]), X, Y, T, T);
          goblinMark(ctx, e, X, Y);
          break;
        }
        case "clear": img = first(D.draw.clear); if (gated) ctx.globalAlpha = 0.5; break;
        case "worldPortal": {
          const bg = first(D.draw.worldPortal);
          if (bg) ctx.drawImage(tinted(bg, "#8dc977"), X, Y, T, T);
          const num = first(D.draw.numbers[e.num ?? e.to_s ?? 0]);
          if (num) ctx.drawImage(IMG[num], X, Y, T, T);
          break;
        }
        case "player": img = first(D.draw.player[emoOf(lv.startHp ?? e.ch ?? 6)]); break;
      }
      if (img) ctx.drawImage(IMG[img], X, Y, T, T);
      ctx.restore();
    }

    if (grid) {
      ctx.save();
      ctx.lineWidth = 4; ctx.strokeStyle = "rgba(0,0,0,.2)";
      for (let x = 0; x <= lv.w; x++) { ctx.beginPath(); ctx.moveTo(x * T, 0); ctx.lineTo(x * T, lv.h * T); ctx.stroke(); }
      for (let y = 0; y <= lv.h; y++) { ctx.beginPath(); ctx.moveTo(0, y * T); ctx.lineTo(lv.w * T, y * T); ctx.stroke(); }
      // 구멍 위에 떠 있는 개체
      ctx.setLineDash([20, 16]); ctx.lineWidth = 10; ctx.strokeStyle = "rgba(190,40,40,.8)";
      for (const e of lv.ents) if (!tile(e.x, e.y)) ctx.strokeRect(e.x * T + 16, e.y * T + 16, T - 32, T - 32);
      ctx.setLineDash([]);
      // 한 칸에 겹친 개체 수
      const count = {};
      for (const e of lv.ents) { const k = e.x + "," + e.y; count[k] = (count[k] || 0) + 1; }
      ctx.font = "bold 60px system-ui, sans-serif";
      for (const [k, n] of Object.entries(count)) if (n > 1) {
        const [x, y] = k.split(",").map(Number);
        ctx.fillStyle = "rgba(190,40,40,.9)"; ctx.beginPath(); ctx.arc(x * T + T - 40, y * T + 40, 34, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = "#fff"; ctx.textAlign = "center"; ctx.textBaseline = "middle"; ctx.fillText("×" + n, x * T + T - 40, y * T + 42);
      }
      ctx.textAlign = "left"; ctx.textBaseline = "alphabetic";
      ctx.font = "bold 46px system-ui, sans-serif"; ctx.fillStyle = "rgba(0,0,0,.55)";
      for (let y = 0; y < lv.h; y++) for (let x = 0; x < lv.w; x++) ctx.fillText(`${x},${y}`, x * T + 12, y * T + 52);
      ctx.restore();
    }
  }

  // ─────────────────────────────────────── 시트 (모든 맵)
  const allLevels = D.worlds.flatMap((w) => w.levels);
  const sheets = [];   // [{lv, canvas}]

  function summary(lv) {
    if (lv.hub) {
      const n = lv.ents.filter((e) => e.t === "worldPortal").length;
      return `허브 · 포탈 ${n}개` + (lv.missing && lv.missing.length ? " · ⚠ 연결 파일 없음" : "");
    }
    const m = lv.metrics;
    const pct = m.alive ? Math.round((100 * m.locks) / m.alive) : 0;
    return `최단 ${m.shortest}수 · 소프트락 ${pct}% · ${m.required.filter((t) => t !== "평온").join("·") || "평온"}`;
  }

  function mapCard(lv) {
    const canvas = h("canvas", { "aria-hidden": "true" });
    const d = lv.desc || {};
    const sub = d.title ? d.title.replace(/^[^—]*—\s*/, "") : "";
    const card = h("button", {
      type: "button", class: "map-card" + (lv.legacy ? " legacy" : ""), id: "lv-" + lv.key,
      "aria-label": `${lv.key} ${lv.name} ${sub} — 자세히 보기`, onclick: () => openDetail(lv.key),
    },
      h("span", { class: "mc-head" }, h("span", { class: "mc-key" }, lv.key.replace(/^v(\d)_/, "v$1·")), h("span", { class: "mc-name" }, lv.name)),
      h("span", { class: "mc-map" }, canvas),
      sub ? h("span", { class: "mc-sub" }, sub) : null,
      h("span", { class: "mc-stat" }, summary(lv)));
    sheets.push({ lv, canvas, card });
    return card;
  }

  function redrawSheets() {
    for (const { lv, canvas, card } of sheets) {
      drawMap(canvas, lv, cell, showGrid);
      card.style.width = Math.max(compact ? 0 : 150, Math.round((lv.w + PAD * 2) * cell) + 22) + "px";   // 카드 폭 = 지도 폭 (+여백)
    }
  }

  // ─────────────────────────────────────── 상세 창
  const dlg = document.getElementById("detail");
  const dlgBody = h("div", { class: "dlg-body" });
  let curKey = null;
  function stat(k, v, title) { return h("div", { class: "stat", title: title || null }, h("div", { class: "k" }, k), h("div", { class: "v" }, v)); }

  function openDetail(key) {
    const i = allLevels.findIndex((l) => l.key === key);
    if (i < 0) return;
    const lv = allLevels[i];
    curKey = key;
    const d = lv.desc || {};
    const badges = [h("span", { class: "badge" }, `${lv.w}×${lv.h}`)];
    badges.push(h("span", { class: "badge" }, `시작 체력 ${lv.startHp} · ${EMO[emoOf(lv.startHp)]}`));
    if (lv.hub) badges.push(h("span", { class: "badge accent" }, "허브"));
    if (lv.legacy) badges.push(h("span", { class: "badge warn" }, "레거시 — 게임에서 로드 안 됨"));

    const big = h("canvas", { role: "img", "aria-label": `${lv.key} ${lv.name} 배치도` });
    const mapBox = h("div", { class: "dlg-map" }, big);
    const info = h("div", { class: "dlg-info" });
    if (d.tags && d.tags.length && !lv.hub) info.append(h("div", { class: "tags" }, d.tags.map((t) => h("span", { class: "tag" }, t))));
    if (!lv.hub) {
      const m = lv.metrics;
      const pct = m.alive ? Math.round((100 * m.locks) / m.alive) : 0;
      info.append(h("div", { class: "stats" },
        stat("최단 수", m.shortest + "수"),
        stat("탐색 상태", m.states + "개", "도달 가능한 모든 상태 수"),
        stat("소프트락", `${pct}% (${m.locks}/${m.alive})`, "살아 있지만 이미 클리어가 불가능한 상태 비율"),
        stat("사망 · 낙하", `${m.dead} · ${m.fallen}`),
        stat("필수 감정", m.required.join(" · ") || "없음", "이 감정을 금지하면 클리어 불가"),
        m.goblins ? stat("고치 · 돌 · 고블린", `${m.cocoons} · ${m.boxes} · ${m.goblins}`)
                  : stat("고치 · 돌", `${m.cocoons} · ${m.boxes}`)));
    }
    const rows = [];
    const add = (cls, k, v) => { if (v) rows.push(h("dt", { class: cls }, k), h("dd", null, v)); };
    add("", "가르치는 것", d.teach);
    add("belief", "플레이어가 처음 믿는 것", d.belief);
    add("insight", "깨닫는 것", d.insight);
    add("", "해답 흐름", d.flow);
    add("", "함정", d.traps);
    add("", "메모", d.notes);
    if (lv.solution) add("", `최단 해답 (${lv.solution.length}수)`, [...lv.solution].map((k) => ARROW[k]).join(" "));
    if (rows.length) info.append(h("dl", { class: "desc" }, rows));
    if (!lv.hub && lv.metrics.cocoonKillers.length)
      info.append(h("p", { class: "note" }, "누에고치를 깰 수 있는 수단 — ", lv.metrics.cocoonKillers.map((c) => `(${c.x},${c.y}) ${c.by}`).join(" · ")));
    if (lv.hub) {
      if (lv.missing && lv.missing.length) info.append(h("div", { class: "warnbox" },
        "연결된 맵 파일이 없는 포탈: ", lv.missing.map((m) => `(${m.x},${m.y}) → ${m.file}`).join(", "), " — 밟으면 맵 로드에 실패한다."));
      info.append(h("pre", { class: "hub" }, lv.hubText));
    }
    info.append(h("p", { class: "note" }, "맵 파일 ", h("code", null, lv.file), d.source ? ` · 근거: ${d.source}` : ""));

    const prev = allLevels[i - 1], next = allLevels[i + 1];
    dlgBody.replaceChildren(
      h("div", { class: "dlg-head" },
        h("div", null,
          h("div", { class: "mc-key" }, lv.key.replace(/^v(\d)_/, "v$1 · ") + " · " + lv.name),
          h("h2", { id: "dlg-title" }, d.title || lv.name),
          h("div", { class: "badges" }, badges)),
        h("div", { class: "dlg-nav" },
          h("button", { type: "button", "aria-label": "이전 맵", title: "이전 맵 (←)", disabled: !prev, onclick: () => prev && openDetail(prev.key) }, "‹"),
          h("button", { type: "button", "aria-label": "다음 맵", title: "다음 맵 (→)", disabled: !next, onclick: () => next && openDetail(next.key) }, "›"),
          h("button", { type: "button", "aria-label": "닫기", title: "닫기 (Esc)", onclick: () => dlg.close() }, "✕"))),
      h("div", { class: "dlg-grid" }, mapBox, info));
    if (!dlg.open) dlg.showModal();
    // 큰 지도: 돌 너비에 맞춰 축척 (한 칸 최대 96px)
    const avail = mapBox.clientWidth || 320;
    const c = Math.max(24, Math.min(96, avail / (lv.w + PAD * 2), (window.innerHeight * 0.62) / (lv.h + PAD * 2)));
    drawMap(big, lv, c, showGrid);
    history.replaceState(null, "", "#lv-" + key);
    dlgBody.scrollTop = 0;
  }
  dlg.append(dlgBody);
  dlg.addEventListener("close", () => {
    history.replaceState(null, "", location.pathname + location.search);
    const card = curKey && document.getElementById("lv-" + curKey);
    if (card) card.focus({ preventScroll: false });
    curKey = null;
  });
  dlg.addEventListener("click", (e) => { if (e.target === dlg) dlg.close(); });   // 바깥 누르면 닫기
  dlg.addEventListener("keydown", (e) => {
    const i = allLevels.findIndex((l) => l.key === curKey);
    if (e.key === "ArrowRight" && allLevels[i + 1]) { openDetail(allLevels[i + 1].key); e.preventDefault(); }
    if (e.key === "ArrowLeft" && allLevels[i - 1]) { openDetail(allLevels[i - 1].key); e.preventDefault(); }
  });

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
        const f = v.pngs[0];
        card.append(h("div", { class: "variant" },
          h("div", { class: "thumb" }, f ? h("img", { src: url(f), alt: v.label, loading: "lazy" }) : null),
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
      h("p", { class: "note" }, D.commonSfx),
      h("details", { class: "more" }, h("summary", null, `프로젝트 어디에서도 경로로 참조하지 않는 그림 ${D.unreferenced.length}장`),
        h("ul", { class: "unref" }, D.unreferenced.map((p) => h("li", null, p)))));
    return sec;
  }

  // ─────────────────────────────────────── 범례
  function legend() {
    const it = (img, label) => h("span", { class: "lg" }, img ? h("img", { src: url(img), alt: "" }) : h("i", { class: "hole" }), label);
    const pic = (paint, label) => {   // 틴트가 필요한 그림은 시트와 같은 방식으로 작은 캔버스에
      const c = h("canvas", { width: T, height: T, "aria-hidden": "true" });
      paint(c.getContext("2d"));
      return h("span", { class: "lg" }, c, label);
    };
    const gob = (e, label) => pic((x) => {
      const g = first(D.draw.goblin);
      if (g) x.drawImage(tinted(g, GOB_TINT[e.move]), 0, 0, T, T);
      goblinMark(x, e, 0, 0);
    }, label);
    const portal = (label) => pic((x) => {
      const bg = first(D.draw.worldPortal), num = first(D.draw.numbers[1]);
      if (bg) x.drawImage(tinted(bg, "#8dc977"), 0, 0, T, T);
      if (num) x.drawImage(IMG[num], 0, 0, T, T);
    }, label);
    return h("div", { class: "legend", "aria-label": "범례" },
      it(first(D.draw.player[0]), "플레이어 (감정별 그림)"),
      it(first(D.draw.clear), "실타래 = 목표 (반투명 = 고치가 남았거나 발판이 안 눌려 꺼짐)"),
      it(first(D.draw.cocoon), "누에고치"),
      it(first(D.draw.stone), "돌"),
      D.draw.goblin ? gob({ move: "patrol", dir: "R" }, "고블린 순찰 (화살표 = 바라보는 방향)") : null,
      D.draw.goblin ? gob({ move: "chase" }, "고블린 추적 (과녁)") : null,
      it(first(D.draw.trap[2]), "가시 1·2·3 (상시)"),
      it(first(D.draw.chili), "칠리 (일회성, 항상 -1)"),
      it(first(D.draw.cookie), "쿠키 = 회복"),
      it(first(D.draw.wall[0]), "바위 = 벽 (파괴 불가)"),
      it(first(D.draw.obstacle[0]), "장애물: 항아리 (공격 1로 파괴)"),
      it(first(D.draw.obstacle[1]), "장애물: 기둥 (공격 2로 파괴)"),
      pic((x) => plateMark(x, 0, 0), "발판 (전부 눌려야 목표가 켜짐)"),
      portal("월드 포탈 (허브, 숫자 = 스테이지)"),
      it(null, "회색 = 구멍"));
  }

  // ─────────────────────────────────────── 조립
  function build() {
    document.getElementById("loading").remove();
    document.getElementById("meta").textContent =
      `생성 ${D.generated}${D.commit ? " · 커밋 " + D.commit : ""} · 맵 ${allLevels.length}개 · 그림 ${Object.keys(D.sizes).length}장`;

    // 도구 막대: 타일 크기 / 좌표·격자
    const sizeBtns = SIZES.map(([label, px]) => h("button", {
      type: "button", "aria-pressed": px === cell ? "true" : "false",
      onclick: (e) => { cell = px; sizeBtns.forEach((b) => b.setAttribute("aria-pressed", b === e.currentTarget ? "true" : "false")); redrawSheets(); },
    }, label));
    if (!SIZES.some(([, px]) => px === cell)) sizeBtns[0].setAttribute("aria-pressed", "true");
    const gridBox = h("input", { type: "checkbox", onchange: (e) => { showGrid = e.target.checked; redrawSheets(); } });
    document.getElementById("tools").append(
      h("span", { class: "seg", role: "group", "aria-label": "타일 크기" }, h("span", { class: "seg-l" }, "타일"), sizeBtns),
      h("label", { class: "chk", title: "칸 좌표, 격자, 겹친 개체 수(×n), 구멍 위에 떠 있는 개체(빨간 점선)" }, gridBox, "좌표·격자"),
      h("label", { class: "chk", title: "카드의 설명 글을 숨기고 배치만 보여 준다" },
        h("input", { type: "checkbox", onchange: (e) => { compact = e.target.checked; document.body.classList.toggle("compact", compact); redrawSheets(); } }), "배치만"));

    app.append(legend());
    const nav = document.getElementById("nav");
    const links = [];
    for (const w of D.worlds) {
      const sec = h("section", { class: "world", id: w.id },
        h("h2", null, w.title, w.legacy ? h("span", { class: "badge warn" }, "레거시") : null),
        h("p", { class: "sub" }, w.subtitle),
        h("div", { class: "sheet" }, w.levels.map(mapCard)));
      app.append(sec);
      links.push(h("a", { href: "#" + w.id }, w.nav || w.title));
    }
    app.append(objectsSection());
    links.push(h("a", { href: "#objects" }, "리소스"));
    nav.append(...links.map((a) => h("li", null, a)));

    const io = new IntersectionObserver((ents) => {
      for (const e of ents) if (e.isIntersecting)
        links.forEach((a) => a.setAttribute("aria-current", a.getAttribute("href") === "#" + e.target.id ? "true" : "false"));
    }, { rootMargin: "-35% 0px -60% 0px" });
    document.querySelectorAll("section.world").forEach((s) => io.observe(s));

    redrawSheets();
    const m = location.hash.match(/^#lv-(.+)$/);
    if (m) openDetail(decodeURIComponent(m[1]));
    else if (location.hash) { const t = document.getElementById(location.hash.slice(1)); if (t) t.scrollIntoView(); }
  }

  loadImages().then(build);
})();
