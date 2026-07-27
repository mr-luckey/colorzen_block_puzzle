# ColorZen — Google Play ASO Listing Pack
**Publisher:** AppWareTech  
**Package (keep as-is):** `com.appwaretech.colorzen.puzzle`  
**Research date:** 25 Jul 2026  
**Primary locale:** `en-US` (localize next: en-IN, pt-BR, id-ID, es-419, tr-TR, ar)

> **Honesty first:** Google Play does **not** publish official search-volume numbers. Volumes / KD below come from third-party ASO tools (ASOTools, Applyra-style audits) + competitor listing reverse-engineering. Treat them as **relative priority**, not exact monthly searches. After launch, trust **Play Console → Growth → Acquisition → Search** as ground truth.

---

## 1) Reality check (goals vs market)

| Goal | Verdict |
|------|---------|
| **10M downloads in 3 months, organic only** | **Not realistic** for a new indie against [Block Blast!](https://play.google.com/store/apps/details?id=com.block.juggle) (1B+ installs, #4 top free Puzzle, heavy live-ops + UA). That scale needs paid UA + creative testing + multi-country soft launches. |
| **1M downloads without paid UA ads** | **Stretch / rare.** Possible only if you win many mid/long-tail keywords, ship ad-light retention, localize hard, and get strong conversion (icon/screenshots/rating ≥4.5). Plan for **paid keyword / UAC later** to hit 1M+ faster. |
| **What ASO alone can do** | Rank for long-tail → mid keywords, lift organic CTR, feed the algorithm with retention. This is the foundation — not a 10M shortcut. |

**Your unfair advantage (from competitor reviews):** Block Blast, Woodoku, Blockudoku players repeatedly complain about **excessive ads**. Position ColorZen as **calm / zen / interruption-light** (and keep interstitial frequency low). That converts searchers who bounce from ad-heavy clones.

---

## 2) Competitor analysis (researched listings)

### A. Biggest competitor — Block Blast!
| Field | Data |
|-------|------|
| Play URL | https://play.google.com/store/apps/details?id=com.block.juggle |
| Package | `com.block.juggle` |
| Downloads | **1B+** |
| Rating | **4.9** (~5.09M reviews) |
| Chart | **#4 top free Puzzle** (as of research) |
| Title | `Block Blast!` (brand-only — they already own brand queries) |
| Short description (reported) | `Relax with offline games and puzzle games anytime, no WiFi needed!` |
| Long-description SEO pattern | Extreme repetition of: **offline games**, **no wifi games**, **no internet games**, **puzzle games**, **relaxing** |
| Monetization pain | Ads after levels / continue-with-ad loops (top 1-star themes) |

**Takeaway:** Do **not** try to outrank them on brand “block blast”. Steal their **offline / no wifi / puzzle** cluster in *your* metadata, but win on **zen + ad-light + USP modes**.

### B. Direct genre peers

| App | Package | Downloads | Rating | Title pattern | SEO angle |
|-----|---------|-----------|--------|---------------|-----------|
| **Woodoku** | `com.tripledot.woodoku` | 100M+ | ~4.2 | `Woodoku - Wood Block Puzzle` | wood + sudoku + offline |
| **Blockudoku** | `com.easybrain.block.puzzle.games` | 100M+ | ~4.6 | `Blockudoku®: Block Puzzle Game` | sudoku + block + daily + zen phrasing |
| **Block Puzzle (Big Cake)** | `com.bigcake.android.bpdaily` | 10M+ | ~4.8 | `Block Puzzle` | classic + offline + daily + calm |
| **Woody / wood clones** | various | 10M–100M | mixed | `Wood Block Puzzle…` | “wood block puzzle” head term |

### C. Keyword density tricks used by winners
1. **Title** = Brand + 1–2 head keywords (≤30 chars).  
2. **Short description** = highest-intent phrase (offline / no WiFi / block puzzle) — fully indexed on Play.  
3. **First ~250–300 characters** of long description = densest keyword block (Play weights early text).  
4. Repeat **offline / no wifi / block puzzle / relaxing** naturally 6–12× — Block Blast does this aggressively.  
5. Avoid trademarked **Tetris** in metadata.

---

## 3) Keyword strategy (traffic vs competition)

### Tier A — Attack first (better chance to rank as a new app)
Use these in title / short / early long description. Sources: ASOTools-style SV/KD + competitor gaps.

| Keyword | Approx SV* | Approx KD* | Why |
|---------|------------|------------|-----|
| block puzzle | 41 | ~11–65† | Core intent — must include, expect slow climb |
| puzzle block | 26 | 15 | Same intent, slightly less contested phrasing |
| block puzzles | 25 | 13 | Plural variant |
| wooden block puzzle | 25 | 12 | Lower KD wood variant (use lightly — you’re color/zen not wood) |
| block puzzle game | 23 | 18 | Mid intent |
| ofline games / offline games | 35–43 | mid–high | Misspell + correct — Block Blast farms this |
| free ofline games | 16 | 23 | Long-tail offline |
| puzzles without internet | — | ~8 | Proven low KD offline intent |
| puzzle gratis sin internet | — | ~10 | LATAM long-tail (localize later) |
| zen block puzzle / zen puzzle | mid-low | lower | Matches **your USP**; fewer 1B apps own “zen” + block |
| offline block puzzle | mid | mid | Hybrid of two winner clusters |
| relaxing block puzzle | mid | mid | Review-language overlap |
| no wifi puzzle / no wifi games | high intent | high head, mid long-tail | Copy Block Blast cluster carefully |
| daily block puzzle | mid | mid | Matches Daily mode |
| color block puzzle | mid-low | lower | Brand-relevant, less wood-saturated |

\*SV/KD = third-party index (0–100 style), not Google official.  
†Head term shows low KD in some tools but **real** competition is extreme because giants already rank.

### Tier B — Scale after Top-20 on Tier A
`offline games`, `no wifi games`, `no internet games`, `puzzle games`, `brain games`, `relaxing games`, `casual puzzle`

### Tier C — Avoid / low ROI early
| Term | Reason |
|------|--------|
| block blast | Competitor brand — wasted chars |
| tetris / tetjis | Trademark + redirected to giants |
| woodoku / blockudoku | Competitor brands |
| games / puzzle alone | Too broad; dead CTR |

### Priority embedding order (first 90 days)
1. `block puzzle` + `offline` + `no wifi`  
2. `zen` + `relaxing` + `daily`  
3. `free` + `brain` (light)  
4. Expand localized offline phrases (ES/ID/PT/TR/AR)

---

## 4) FINAL APP IDENTITY (decide & ship)

### Recommended store title (≤30)
```
ColorZen: Block Puzzle
```
**22/30 characters** — brand + primary keyword. Best balance of memorability and rank signal.

### Alternatives (if A/B testing title)
| Title | Chars | Use when |
|-------|-------|----------|
| `ColorZen Block Puzzle` | 21 | Prefer no colon |
| `ColorZen: Offline Puzzle` | 24 | If offline CTR wins in experiments |
| `Zen Block Puzzle Offline` | 24 | Max keyword density (weaker brand) |

### Package name
```
com.appwaretech.colorzen.puzzle
```
Already correct — **do not change** after publish.

### Developer display name
```
AppWareTech
```

### Category / tags
- **Category:** Puzzle  
- **Tags (Play Console):** Block, Casual, Offline, Single player, Abstract  

---

## 5) READY-TO-PASTE — Short description (≤80)

**Primary (recommended):**
```
Block puzzle offline & zen mode. No WiFi needed—relax anytime!
```
**62/80** — hits: block puzzle, offline, zen, no WiFi, relax.

**Alt A (more “no wifi games”):**
```
Offline zen block puzzle free. No WiFi needed. Clear lines & relax!
```
**67/80**

**Alt B (classic calm pitch):**
```
Relaxing block puzzle offline—no WiFi games. Place, clear, zen!
```
**63/80**

---

## 6) READY-TO-PASTE — Full description (≤4000)

Copy everything between the fences into Play Console → Store listing → Full description.

```
ColorZen is a free offline block puzzle game for players who love relaxing puzzle games, no wifi games, and calm brain challenges—no internet needed.

Place colorful blocks on the board, clear rows and columns, build combos, and stay in the flow. Whether you want a quick break or a long zen session, this block puzzle offline experience is ready anytime.

Why ColorZen?
• Classic block puzzle — drag, place, clear lines, chase high scores
• Zen mode — no score pressure, no bombs, endless calm play
• Daily challenge — one shared puzzle each day (play offline after download)
• Satisfying combos — clear multiple lines and same-color bonuses
• Beautiful themes — Enchanted Night, Woodland, Ocean, Sunset
• Fully offline puzzle fun — perfect no wifi games for travel, commute, or bedtime

Looking for offline games, no internet games, or a relaxing block puzzle free to play? ColorZen keeps the board open, the mind clear, and the ads from interrupting your flow.

How to play this block puzzle game
1. Drag blocks onto the grid
2. Fill a full row or column to clear space
3. Chain clears for bigger combos and higher scores
4. Plan ahead — keep room for larger pieces
5. In Classic, survive as long as you can; in Zen, never stop

Features players love in great offline puzzle games
• Smooth, easy controls — learn in seconds
• No timer stress — play at your own pace
• Offline block puzzle saves — continue anytime from Home
• Daily block puzzle habit loop to train your brain
• Colorful, modern visuals instead of plain wood-only boards
• Light, relaxing sound and haptic feedback

Who is ColorZen for?
If you enjoy puzzle games, casual brain games, offline games, and no wifi games that feel fair and calming, ColorZen is built for you. It is a free block puzzle with zen energy—simple to start, strategic to master, and satisfying every clear.

Download ColorZen: Block Puzzle today
Play free offline. No WiFi needed. Place. Clear. Zen.
```

**Character count:** ~1,850 (safe under 4000; room for localized paragraphs later).

### First-250-char keyword block (already front-loaded)
Contains: free, offline, block puzzle, relaxing puzzle games, no wifi games, no internet, colorful blocks, clear rows and columns, combos, block puzzle offline.

---

## 7) What’s New (first release)
```
Welcome to ColorZen!
• Classic, Daily & Zen modes
• Offline block puzzle — play with no WiFi
• Combos, themes & calm vibes
Place. Clear. Zen.
```

---

## 8) Creative / conversion checklist (ASO is not text-only)

Without these, keyword ranking will **not** convert to downloads:

| Asset | Spec | Must show |
|-------|------|-----------|
| **Icon** | 512×512 | Readable “CZ” or colorful blocks + calm glow; test vs Block Blast icon clutter |
| **Feature graphic** | 1024×500 | Title + “Offline · No WiFi · Zen Mode” |
| **Screenshots (phone)** | min 4, ideal 6–8 | 1 Classic board, 2 Zen calm, 3 Daily, 4 Combo clear, 5 Themes, 6 “Offline / No WiFi” caption |
| **Short video** | 15–30s | Silent-first; place → clear → combo in 3s |
| **Rating** | Target ≥4.6 | Soft-prompt after pleasant Zen session (not after ad) |

Caption keywords on screenshots (indexed lightly / conversion heavily):  
`Offline Block Puzzle` · `No WiFi Needed` · `Zen Mode` · `Daily Challenge` · `Clear Rows & Columns`

---

## 9) 90-day organic ranking plan

### Days 0–14 — Soft launch
- Publish in 2–3 countries (e.g. PH, ID, IN) before US/global flood.  
- Freeze metadata; fix crashes; target D1 retention ≥35%, D7 ≥12% (puzzle norms vary).  
- Interstitials: **never mid-placement**; prefer menu / game-over only.

### Days 15–45 — Long-tail attack
- Track ranks for: `zen block puzzle`, `offline block puzzle`, `relaxing block puzzle`, `daily block puzzle`, `color block puzzle`, `no wifi puzzle`.  
- If a term is Top 20, reinforce it in short description A/B.  
- Ship Remove Ads IAP visibly (competitors charge high; price competitively).

### Days 45–90 — Mid keywords + localization
- Localize title/short/long for **en-IN, id-ID, pt-BR, es-419, tr-TR**.  
- Add localized offline phrases (`sin internet`, `tanpa internet`, `sem wifi`).  
- Only then push harder into `offline games` / `no wifi games` (Block Blast territory).  
- Optional: light UAC / ASO install campaigns on winning keywords (this is how most apps cross 1M).

### Metadata change rule
Change **one** of {title, short desc} every 2–3 weeks — never both at once — so you can measure lift.

---

## 10) Copy-paste Play Console field sheet

| Field | Value |
|-------|--------|
| App name | `ColorZen: Block Puzzle` |
| Package | `com.appwaretech.colorzen.puzzle` |
| Short description | `Block puzzle offline & zen mode. No WiFi needed—relax anytime!` |
| Full description | *(Section 6 block)* |
| Application type | Game |
| Category | Puzzle |
| Tags | Block, Casual, Offline, Single player, Abstract |
| Contact email | *(your support@appwaretech…)* |
| Privacy policy URL | *(required before publish)* |

---

## 11) Sources used (no guessing on competitor facts)

- [Block Blast! — Google Play](https://play.google.com/store/apps/details?id=com.block.juggle) — 1B+, 4.9, offline/no-wifi description pattern, #4 Puzzle  
- [Woodoku — Google Play](https://play.google.com/store/apps/details?id=com.tripledot.woodoku) — 100M+, wood/sudoku/offline SEO  
- [Blockudoku — Google Play](https://play.google.com/store/apps/details?id=com.easybrain.block.puzzle.games) — 100M+, block+sudoku+daily  
- [Block Puzzle (Big Cake) — Google Play](https://play.google.com/store/apps/details?id=com.bigcake.android.bpdaily) — 10M+, calm/offline long-form SEO  
- [ASOTools — “block puzzle” keyword case](https://asotools.io/app-store-keywords/block-puzzle) — SV/KD for block/wood variants  
- [ASOTools — offline misspell cluster](https://vip.asotools.io/app-store-keywords/ofline) — ofline games SV ~35  
- [AppTweak — Play keyword research 2026](https://www.apptweak.com/en/aso-blog/play-store-keyword-research) — title/short/long indexing rules  
- [Keywords Everywhere note](https://keywordseverywhere.com/google-play-search-volume.html) — Play has **no official** volume API  
- In-repo product truth: Classic / Daily / Zen, 9×9, offline-first, package `com.appwaretech.colorzen.puzzle`

---

## 12) Bottom line

| Decide | Ship |
|--------|------|
| **Name** | **ColorZen: Block Puzzle** |
| **Package** | `com.appwaretech.colorzen.puzzle` |
| **Short** | `Block puzzle offline & zen mode. No WiFi needed—relax anytime!` |
| **Strategy** | Long-tail zen/offline first → mid keywords → localize → paid UA for 1M–10M scale |
| **Moat** | Zen mode + fairer ads than Block Blast / Woodoku / Blockudoku |

ASO text is ready to paste. Hitting **10M in 3 months without paid ads is not a listing-text problem** — treat Section 9 as the real growth system, and use this metadata as the ranking foundation.
