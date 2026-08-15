# Simon — Steel Tongue Drum Edition: Polish & Production Value Expansion

Design document for a **presentation/UX polish pass** on the existing, fully-implemented Simon game
(see `GAME_OVERVIEW.md` for the frozen core design). This document does not change what the game
*is* — core rules, scoring, the 5 modifiers, 8 scales, and existing 8 flat + 2 animated palettes are
unchanged. It defines new, additive layers: a UI Theme system, richer audio, and UX/onboarding work.

Full interview record: `interview.md`.

## Explicit scope boundary

**In scope:** visual identity/theming, audio architecture, onboarding, mid-game pacing/feedback,
settings navigation, accessibility (shake/flash toggle, mix defaults).

**Out of scope:** new game modes, new scoring mechanics, new modifiers, new scales, new pad
palettes/content counts, any change to the core memory-sequence loop.

---

## 1. Visual track

### 1.1 UI Theme system (new)

A new, **independent** progression axis alongside the existing pad Palette system. A Theme
controls the whole app's mood — background, UI chrome, panel styling, typography treatment,
lighting — separately from pad color (Palette). Any Theme can be paired with any Palette.

| Theme | Status | Unlock | Notes |
|---|---|---|---|
| Premium & Minimal | Default, always unlocked | — | Dark, sleek, high-end audio-app/synth-hardware feel. Muted chrome; pads and their palette colors are the visual focus. This is the baseline aesthetic for all UI (settings panel, buttons, labels, backgrounds) in v1. |
| Cosmic & Atmospheric | Unlockable | Reach Round 20 (same trigger as Galaxy palette) | Background/panels/lighting shift toward a starfield/nebula treatment, reusing/adapting the domain-warped fbm techniques from `shaders/galaxy.gdshader` and `shaders/aurora.gdshader` for backgrounds and UI chrome — not just pads. Unlocking Round 20 now grants **both** the Galaxy pad skin and this theme together as one payoff moment. |

Warm & Tactile and Playful & Colorful are noted as future content, not built in v1.

Settings gets a new **Themes** section (collapsible, see §3.3) mirroring the existing Palette
grid's locked/unlocked-with-requirement visual pattern.

### 1.2 Flat palette shimmer upgrade

All 8 existing flat palettes (Anodized, Pastel Dream, Sunset, Ocean Steel, Monochrome Steel,
Neon, Forest, Royal) get a shared, lightweight shader treatment applied uniformly — not
palette-specific bespoke shaders. This raises their baseline quality without the cost of building
more full animated skins like Galaxy/Aurora, and it's the highest-impact visual change since flat
palettes cover the majority of actual play time.

Behavior: **ambient + state-reactive**.
- **Idle**: a subtle, slow, time-based shimmer/gradient animation — pads feel quietly alive even
  when nothing is happening.
- **Lit** (sequence playback) and **Press** (player hit): the shimmer intensifies/shifts,
  layering on top of — not replacing — the existing glow/flash feedback already implemented in
  `simon_button.gd` (`_set_glow`, `_tween_glow_out`).

Implementation note: this is a new shader (or shared shader + per-palette color uniform) applied
to flat-palette pads, with additional uniforms driven by the same state hooks `simon_button.gd`
already exposes (`_on_button_down`, `flash()`), so it composes with existing feedback rather than
conflicting with it. The two existing animated skins (Galaxy, Aurora) are unchanged.

### 1.3 Transitions

Every current UI-state change in `Main.gd` is a hard `.visible = true/false` snap (settings panel
~line 314/317, modifier panel ~line 511/513, mode-switch button blocks ~line 383-401). These get
**distinct, per-context treatments** rather than one shared tween:

| Transition point | Treatment |
|---|---|
| Modifier picker open | Dramatic reveal (scale + glow-in) — it's a meaningful decision point, deserves weight |
| Settings panel open/close | Quick slide-in from edge |
| Mode switch (Normal/Chaos/Zen) | Full-screen cross-fade |
| Round-start (sequence begins after correct repeat) | A clear beat/animation between "correct" and "sequence grows" — see §2, pacing |

---

## 2. Audio track

Current state: `sound.gd` has exactly two synthesis functions (`play_tone`, `play_fail`), one
`AudioStreamPlayer`, no music, no UI SFX, and no volume controls anywhere. This track adds a full
audio architecture on top of the existing harmonic-synthesis approach (odd-harmonic overtones,
exponential decay — kept as the sonic signature for anything new).

### 2.1 New audio buses

Four independent Godot audio buses, each with a persisted volume:

- **Master**
- **Tones** — existing pad-hit and fail sounds
- **Ambient** — new background layer (below)
- **UI** — new interaction SFX (below)

### 2.2 Ambient background layer (new)

Always-on across Normal, Chaos, Zen, and menus. Two defining properties:
- **Scale-reactive**: harmonic key/mode derives from the currently active scale (e.g. D Minor
  Pentatonic vs. C Major Diatonic), so the ambient bed harmonizes with pad tones rather than
  clashing. Tracks the active *scale*, not per-round pad layout — Chaos Mode's per-round reshuffle
  should not retrigger/retune the ambient layer.
- **Theme-reactive**: texture/timbre shifts with the active UI Theme (e.g. more atmospheric/
  shimmering character under Cosmic & Atmospheric).

Implementation note: needs its own generator/player in `sound.gd` (separate from the existing pad
tone player), regenerating on scale change, with theme-driven parameter shifts (not necessarily a
full retune) rather than a hard restart.

### 2.3 UI SFX (new)

**Present but soft** — most interactions (button clicks, panel slides, panel open/close) get a
gentle synthesized sound, built from the same harmonic-synthesis approach as pad tones (soft,
bell-like, decay envelope) for sonic cohesion, rather than generic beeps. Not silent-by-default,
not reserved only for big moments — routine UI is consistently, gently audible.

Unlock moments (already paired with the existing gold-flash treatment from the "hubert" easter
egg pattern) can still be more elaborate/celebratory than routine UI sounds.

### 2.4 Mix panel

Four sliders in the new Settings → Audio section (see §3.3): Master, Tones, Ambient, UI.
Routed through `AudioServer` bus volumes, persisted in `user://simon_save.json` alongside existing
bests. Default levels should be modest/non-jarring, particularly Ambient, so it doesn't compete
with pad tones (accessibility consideration, §4).

---

## 3. UX/flow track

### 3.1 Onboarding (new)

No tutorial exists today — first launch drops the player straight to Start/Chaos/Zen buttons.
New: a **skippable, ~20-second guided walkthrough**, advanced one click/step at a time (short
callouts, not a wall of text), covering:

1. Core loop — watch the sequence, repeat it back
2. Score/combo basics
3. Mode differences — Normal / Chaos / Zen
4. The every-3rd-round modifier choice

**Explicitly excluded** from the walkthrough: unlocks/progression. These should be self-evident
when they happen (unlock-moment fanfare, greyed-out Settings entries with requirement text) rather
than pre-explained.

Triggers automatically once on first launch (persisted flag in `user://simon_save.json`).
Replayable anytime via a small, persistent **"?" button** in a UI corner.

### 3.2 Mid-game pacing (minor tweaks, three areas)

No single issue dominates; three small, independent improvements:

- **End-of-run feedback**: today `_game_over()` (Main.gd ~line 533) just sets
  `round_label.text = "Game Over! Round %d"`. Add a proper end-of-run summary
  (final score/round/combo, new-best callouts) instead of a label change.
- **Modifier-choice clarity**: modifier cards in `modifier_panel` get clearer presentation —
  icon + short description + a stacking indicator (several modifiers explicitly stack, e.g.
  Safety Net charges, Sharper Ear growth) so stacking state is visible, not just implied.
- **Round-transition breathing room**: a clear beat/animation between "you got it right" and "here
  comes the next longer sequence" (ties into §1.3's transition table).

### 3.3 Settings panel restructure

Settings is growing (existing Scale grid, existing Palette grid, new Theme picker, new 4-slider
Audio mix, existing Bests display) and needs reorganizing. Chosen approach: **collapsible
sections** within a single panel — Scales / Palettes / Themes / Audio / Bests — each independently
expandable, rather than tabs or one long scroll. Locked-entry visual pattern (greyed out +
requirement text) from the existing Scale/Palette grids extends to the new Themes section.

---

## 4. Accessibility

- **Screen-shake/flash toggle**: new Settings option to disable/reduce the existing
  `_screen_shake()` / `_flash_screen()` calls (used on hit, miss, forgiveness, easter egg).
- **Pad identification**: already substantially covered — `Main.gd` displays a note-letter label
  per pad (`note_labels`, set from `scale["notes"][i]`) independent of color, including through
  Chaos Mode's reshuffles. No new work required here beyond ensuring new Themes/palette shimmer
  don't reduce label contrast/legibility — fold into visual QA rather than a separate feature.
- **Audio defaults**: new Master/Tones/Ambient/UI sliders should default to modest, non-jarring
  levels, particularly Ambient.

---

## 5. Implementation sequencing

Phased **UX → Visual → Audio**, since Settings needs its new structure in place to host the Theme
picker and mix sliders regardless of when their content lands.

1. **Phase 1 — UX/flow**: Settings collapsible restructure (§3.3), onboarding walkthrough + "?"
   button (§3.1), end-of-run summary screen, modifier-card clarity, round-transition beat (§3.2).
2. **Phase 2 — Visual**: Theme system + Cosmic & Atmospheric theme (§1.1), flat-palette shimmer
   shader (§1.2), per-context transition treatments (§1.3) — feeding the transition needs
   identified in Phase 1.
3. **Phase 3 — Audio**: bus architecture, ambient layer, UI SFX, mix sliders (§2) — surfaced in
   the Settings structure built in Phase 1.

---

## Open items for the implementation plan

- Exact shimmer shader parameters (color/speed/intensity ranges) for the flat-palette upgrade —
  a visual-tuning task, not a design decision.
- Exact copy/callout text for the onboarding walkthrough.
- Whether the Theme system needs its own save-file schema addition beyond what
  `user://simon_save.json` already tracks for palettes (structurally identical: unlocked-set +
  selected-id).
