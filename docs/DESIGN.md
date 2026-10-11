# Design — Sprout character and v2 visuals

Source of truth for the app's look. Approved concept: "Concept v2 — Sprout character"
on the Claude Design canvas. When this document and the code disagree, this document wins.

---

## 1. Principles

- **The plant is the character.** The Sprout's head, leaves, and eyes carry the emotion;
  the pot is a plain pot with no face.
- **The world reacts to real data.** The scene, the character's pose, and the effects all
  come from the current `PlantMood` and readings, never from decoration alone.
- **Calm and warm.** Sage greens, a terracotta pot, soft sky colors. No gradients, no emoji.
- **Character first, numbers second.** The character owns the screen; sensor values are
  small chips.

---

## 2. Palette

### Day (default)

| Token | Hex | Use |
|---|---|---|
| `background` | `#EEF4E6` | Screen background |
| `scene` | `#DCEBD3` | Scene card behind the plant |
| `sky` | `#CFE6F5` | Window glass |
| `windowFrame` | `#FFFFFF` | Window frame and panes |
| `sun` | `#FFD66B` | Sun in the window |
| `sill` | `#D8B892` | Windowsill the pot stands on |
| `floor` | `#CFE2C4` | Area below the sill |
| `card` | `#FFFFFF` | Chips, bubble, secondary buttons |
| `ink` | `#1F2A24` | Primary text, icons |
| `inkSecondary` | `#4D5B53` | Subtitles, chip labels |
| `inkTertiary` | `#56645C` | Inactive tab labels |
| `primary` | `#237A40` | Primary button (white text) |
| `water` | `#236DAD` | Water-related text and buttons (white text when filled) |
| `streak` | `#B4531F` | Streak counter, warm accents |

### Thirsty (overrides)

| Token | Hex |
|---|---|
| `background` | `#F4EEE2` |
| `scene` | `#EADFCB` |
| `sky` | `#DDE9F0` |
| `floor` | `#E2D4BC` |
| `warningFill` | `#FFF1DE` (chip background) |
| `warningBorder` | `#E9A55A` (2 pt inner border) |
| `warningText` | `#9A3F12` (value), `#7A4A2A` (label) |

### Night (overrides)

| Token | Hex |
|---|---|
| `background` | `#17202B` |
| `scene` | `#223042` |
| `sky` | `#2E4260` |
| `windowFrame` | `#3A4A60` |
| `moon` / stars | `#F3E7B3` |
| `sill` | `#4A4236` |
| `floor` | `#1C2836` |
| `card` | `#263241` |
| `ink` | `#EEF2F6` |
| `inkSecondary` | `#A9B6C6` |
| `primary` | `#7BD39A` with text `#0F2418` |
| `water` | `#8EC3F0` |
| `streak` | `#F2B07A` |

**Scene selection:** night when light is below 10 lx or the mood is offline; thirsty when
the mood is thirsty or very thirsty; day otherwise.

---

## 3. Typography

SF Pro Rounded (`.rounded` design) everywhere.

| Style | Size | Weight |
|---|---|---|
| Screen title (plant name) | 30 | heavy |
| Subtitle | 15 | bold |
| Speech bubble | 15 | bold, line height ~1.35 |
| Chip value | 17 | heavy |
| Chip label | 12 | bold |
| Primary button | 18 | heavy |
| Secondary button | 16 | heavy |
| Tab label | 12 | bold (active: heavy) |

---

## 4. Home screen layout (iPhone, 390 pt wide reference)

From top to bottom:

1. **Header** (below the safe area, 20 pt side padding): plant name as title, subtitle
   `"<room> · <mood label>"`. On the right: a streak pill (36 pt high, card background,
   flame icon + text in `streak`) and a 44 pt round settings button.
2. **Scene card**: 16 pt side margins, 440 pt high, corner radius 32, `scene` background.
   - **Window**: 170 × 180 pt, 26 pt radius, 10 pt `windowFrame` border, `sky` fill, a
     cross of 8 pt panes, positioned top-right (x 150, y 24 inside the scene). Day: a
     44 pt `sun` circle in the top-right of the glass. Night: a crescent moon (40 pt
     circle with a 36 pt `sky` circle offset over it) and 4 small stars.
   - **Sill**: full width, 26 pt high, bottom edge 76 pt above the scene bottom.
     Below it, `floor` color.
   - **Sprout**: 270 × 315 pt, horizontally centered, bottom edge 84 pt above the scene
     bottom, so the pot stands on the sill.
   - **Speech bubble**: top-left (14, 18), 168 pt wide, `card` background, radius
     20 / 20 / 20 / 6 (small corner bottom-left), 12 × 14 pt padding.
   - **Chips**: 3 equal columns, 8 pt gap, 12 pt from the scene edges and bottom,
     radius 16, `card` background. Each: icon + value on one row, label under it.
     Moisture icon in `water`, light and temperature icons in `streak`.
3. **Actions** (20 pt side padding, 10 pt gap):
   - Primary pill button, 56 pt high: "Talk to <name>" with a mic icon (`primary`).
     In the thirsty scene the primary button becomes the water action (`water`) and
     Talk becomes secondary.
   - Two secondary pill buttons, 48 pt high, 2 pt border: water action and History.

Icons are SF Symbols equivalents of: drop, sun, thermometer, mic, chart, flame, sliders.

---

## 5. The Sprout character

All coordinates are in a **240 × 280 viewBox**; scale uniformly to the target size
(the home screen uses 270 × 315). Draw in this order, back to front.

### 5.1 Shapes

| # | Element | Geometry | Fill / stroke |
|---|---|---|---|
| 1 | Puddle (overwatered only) | ellipse c(120, 275) r(84, 8) | `#9FD0EE`, opacity = `drops` |
| 2 | Shadow | ellipse c(120, 274) r(52, 5) | `#1F2A24` at 10% |
| 3 | Stem | line (120, 206) → (120, 176) | stroke `stem`, 10 pt, round caps |
| 4 | Left arm leaf | leaf shape, `translate(120,192) rotate(armL) scale(0.42 or 0.40)` | `leaf` |
| 5 | Right arm leaf | same with `armR` | `leaf` |
| 6 | **Head group**, rotated by `tilt` around (120, 206), contains 7–17: | | |
| 7 | Top-left leaf | leaf shape + vein, `translate(120,78) rotate(topL) scale(topScale)` | `leaf`, vein `vein` 3 pt |
| 8 | Top-right leaf | same with `topR` | |
| 9 | Head | circle c(120, 128) r 56 | `head` |
| 10 | Head highlight | ellipse c(100, 102) r(18, 9) | white at 28% |
| 11 | Open eyes | ellipses c(103, 124) and c(137, 124), r(7, `eyeRy`) | `#2B2320` |
| 12 | Eye highlights | circles c(105.5, 120) and c(139.5, 120), r 2.5 | white |
| 13 | Thirsty lids | rects (93,112)–(113,123) and (127,112)–(147,123) in `head` color, plus lid lines y 123 from x 94→112 and 128→146 | lines `#2B2320` 3 pt |
| 14 | Closed eyes | arcs `M95 126 Q103 132 111 126` and `M129 126 Q137 132 145 126` | stroke `#2B2320` 3.5 pt |
| 15 | Squint eyes | arcs `M96 127 Q103 118 110 127` and `M130 127 Q137 118 144 127` | stroke `#2B2320` 3.5 pt |
| 16 | Brows | path `brows` | stroke `#2B2320` 3.5 pt, round caps |
| 17 | Blush + mouth | ellipses c(92, 140) and c(148, 140) r(8, 5) in `#F08A7E` at `blush`; mouth path `mouth` | mouth stroke `#2B2320` 3.5 pt, fill `mouthFill` |
| 18 | Pot body | `M78 220 H162 L154 262 Q152 270 144 270 H96 Q88 270 86 262 Z` | `#CD6E48` |
| 19 | Pot rim | rounded rect (68, 202) 104 × 22, radius 11 | `#DE8A62` |
| 20 | Soil | ellipse c(120, 206) r(44, 5) | `soil` |
| 21 | Effects | see 5.3 | |

**Leaf shape** (points up from its origin): `M0 0 C -24 -26 -22 -70 0 -96 C 22 -70 24 -26 0 0 Z`.
**Vein:** `M0 -8 V -80`.

### 5.2 Moods

`t(r, s)` = rotation in degrees and scale for a leaf. Arms always use scale 0.42
(0.40 when thirsty or cold).

| Visual state | head | leaf | vein | stem | tilt | top leaves (L / R, scale) | arms (L / R) | eyes | brows | mouth | extras |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **happy** | `#62BE70` | `#3FA35B` | `#2C7A43` | `#3A9452` | 0 | −32 / 32, 0.55 | −62 / 62 | open, ry 9 | `M95 108 Q103 104 111 107 M129 107 Q137 104 145 108` | `M108 142 Q120 152 132 142` | blush 0.85, sparkles |
| **thirsty** | `#B9C46E` | `#A3B65C` | `#7D8C3F` | `#8FA04E` | 16 | −104 / 96, 0.50 | −128 / 124 | open + lids | `M95 106 Q103 109 111 104 M129 104 Q137 109 145 106` | `M110 148 Q120 141 130 148` | soil `#A7856A`, pot cracks |
| **hot** | `#5BB86A` | `#4E9E57` | `#367842` | `#3A9452` | 0 | −42 / 42, 0.55 | −30 / 62 | squint | `M95 108 Q103 105 111 108 M129 108 Q137 105 145 108` | `M106 146 Q111 140 116 146 Q121 152 126 146 Q131 140 134 144` | blush 1, sweat |
| **cold** | `#7DC2B0` | `#5BA697` | `#3E8074` | `#4A9585` | 0 | −18 / 18, 0.50 | −96 / 96 | squint | same as thirsty | `M106 145 L111 149 L116 143 L121 149 L126 143 L132 147` | shiver lines |
| **asleep** | `#56AE66` | `#3B8F55` | `#2A6B3E` | `#33874A` | −4 | −48 / 44, 0.52 | −80 / 78 | closed | `M96 110 Q103 108 110 110 M130 110 Q137 108 144 110` | `M115 145 Q120 148 125 145` | blush 0.5, Zzz |
| **overwatered** | `#4FA06A` | `#4FA06A` | `#357A4C` | `#3A8F55` | 0 | −70 / 70, 0.52 | −100 / 100 | open, ry 11 | `M94 104 Q103 98 111 102 M129 102 Q137 98 146 104` | `M111 146 Q120 157 129 146 Q120 137 111 146 Z`, filled `#2B2320` | soil `#4A3427`, drops + puddle |

Default soil: `#6B4A35`. Top leaves for thirsty sit at `translate(120, 80)` instead of 78.

**`PlantMood` → visual state:** happy → happy; thirsty, veryThirsty, dryAir → thirsty
(veryThirsty may add 6° of extra tilt); tooHot → hot; tooCold → cold; tooDark, offline →
asleep; drowning → overwatered. The mood label under the character still shows the exact
`PlantMood` text.

### 5.3 Effects

| Effect | Geometry | Color |
|---|---|---|
| Sparkles (happy) | 4-point stars at (46, 74) size 9 and (198, 56) size 7: `M0 -9 L2.5 -2.5 L9 0 L2.5 2.5 L0 9 L-2.5 2.5 L-9 0 L-2.5 -2.5 Z` | `#F2B93B` |
| Pot cracks (thirsty) | `M90 234 L96 242 L93 252 M150 230 L145 240 L149 248` | `#A3502F` 2.5 pt |
| Sweat (hot) | drops near (170, 96) and (70, 108) | `#6CB8E6` |
| Shiver (cold) | three short lines on each side of the head, x 44–62 and 178–196, y 108–148 | `#7FAEE0` 3 pt |
| Zzz (asleep) | "Z" at (168, 72) size 22, "z" at (188, 50) size 16, "z" at (204, 34) size 11 | `#7E8CB8`, heavy |
| Drops (overwatered) | water drops at (58, 46), (184, 40), (150, 16) | `#5AAAE0` |

### 5.4 Motion

- **Mood changes morph**, never jump: animate leaf rotations, tilt, and colors over
  ~0.6 s with a spring; cross-fade eyes, mouth, and effects.
- **Idle:** a blink every 3–6 s (random), a slow breathing scale of the head group
  (1.0 → 1.02, ~3 s), and a gentle sway of the top leaves (±3°).
- **Reduce Motion:** no idle animation, mood changes cross-fade only.
- The final character will be a **Rive** file with a state machine whose input is the
  visual state above; the SwiftUI drawing is the placeholder until then and must keep
  the same states.
