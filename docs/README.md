# Simon — Steel Tongue Drum Edition: Docs

Internal documentation for how this codebase is put together, and — more importantly —
*why* it's built the way it is. These aren't API references (the code is short enough to
just read); they're the reasoning that isn't visible from the code alone.

- [architecture.md](architecture.md) — file layout and module split, the pad ring, why pads are built in code, testing
- [game-modes.md](game-modes.md) — Normal/Chaos/Zen/Music/Duet, and the mode-switch pattern they share
- [scoring-and-modifiers.md](scoring-and-modifiers.md) — combo math, the modifier system, gold steps
- [scales-palettes-themes.md](scales-palettes-themes.md) — the three unlock tracks and `ring_order`
- [audio.md](audio.md) — procedural synthesis, buses, the voice pool
- [music-mode.md](music-mode.md) — the generative Euclidean-rhythm + melody-walk system, in depth
- [modifier-expansion.md](modifier-expansion.md) — 24-modifier roster, slot system, leveling curves
- [modifier-audit.md](modifier-audit.md) — usefulness pass over the roster: verdicts + redesign proposals
- [scoring-escalation.md](scoring-escalation.md) — cash-out economy, wave/streak reset, what persists
- [deployment.md](deployment.md) — how the GitHub Pages build/deploy pipeline works
- [round-goals-and-big-numbers.md](round-goals-and-big-numbers.md) — proposal: bounded round goals replacing voluntary Cash Out, plus compounding/Balatro-style scoring

Two documents outside `/docs` are the source of truth for scope:
- `GAME_OVERVIEW.md` — the frozen core design (rules, modes, scoring, scales, palettes)
- `GAME_DESIGN.md` — the current polish/expansion pass (theming, audio architecture, UX) and its
  explicit scope boundary (no new game modes/scoring/scales — Music Mode was scoped separately,
  as an exception, see `music-mode.md`)
