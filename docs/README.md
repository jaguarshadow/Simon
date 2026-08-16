# Simon — Steel Tongue Drum Edition: Docs

Internal documentation for how this codebase is put together, and — more importantly —
*why* it's built the way it is. These aren't API references (the code is short enough to
just read); they're the reasoning that isn't visible from the code alone.

- [architecture.md](architecture.md) — file layout, the pad ring, why pads are built in code
- [game-modes.md](game-modes.md) — Normal/Chaos/Zen/Music, and the mode-switch pattern they share
- [scoring-and-modifiers.md](scoring-and-modifiers.md) — combo math, the modifier system, gold steps
- [scales-palettes-themes.md](scales-palettes-themes.md) — the three unlock tracks and `ring_order`
- [audio.md](audio.md) — procedural synthesis, buses, the ambient layer
- [music-mode.md](music-mode.md) — the generative Euclidean-rhythm + melody-walk system, in depth
- [modifier-expansion.md](modifier-expansion.md) — 24-modifier roster, slot system, leveling curves
- [scoring-escalation.md](scoring-escalation.md) — cash-out economy, wave/streak reset, what persists
- [deployment.md](deployment.md) — how the GitHub Pages build/deploy pipeline works

Two documents outside `/docs` are the source of truth for scope:
- `GAME_OVERVIEW.md` — the frozen core design (rules, modes, scoring, scales, palettes)
- `GAME_DESIGN.md` — the current polish/expansion pass (theming, audio architecture, UX) and its
  explicit scope boundary (no new game modes/scoring/scales — Music Mode was scoped separately,
  as an exception, see `music-mode.md`)
