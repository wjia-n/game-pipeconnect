# Pipe Connect — RULES.md
_The authoritative source of truth for Pipe Connect. If the implementation
conflicts with this document, the implementation is wrong._

## 1. Objective
Twist the pipes on the grid until water from the central **pump** reaches
**every endpoint** (the brass-capped bulbs). When the last endpoint lights
up, the board is solved.

## 2. Setup
- A square grid: 5×5 (Easy), 7×7 (Medium), 9×9 (Hard).
- Exactly one **pump** tile sits near the center. It has all four sides
  open and can never be twisted.
- A solved pipe network is generated from the pump, then every rotatable
  tile is scrambled by a random number of 90° rotations. The puzzle is
  always solvable: untwisting every tile back to the solution wins.
- Empty grid areas are filled with decorative pipes that can never help
  (they are not part of the solution network).

## 3. Turn order
Single-player puzzle. There are no turns and no opponents: the player taps
pipes freely, in any order, as many times as they like. Every tap is one
twist.

## 4. Legal moves
- Tapping any pipe tile twists it 90° clockwise with a visible animation.
- Tapping a tile multiple times keeps rotating it.

## 5. Illegal moves
- The pump cannot be twisted. Tapping it plays an invalid (dull thud)
  sound and does nothing.
- No input is accepted while the board is celebrating a solve or while the
  game is paused.

## 6. Captures
Not applicable — Pipe Connect is a solo puzzle with no captures.

## 7. Special rules
- **Water spread:** after every twist, water flows from the pump through
  all connected matching openings. Newly reached tiles light up one at a
  time in wave order — the spread is always animated, never instant.
- **Hints:** the 💡 button highlights one wrongly-rotated pipe for ~3
  seconds. Free players get 3 hints per board; PRO players get unlimited.
- **Daily challenge:** one fixed puzzle per calendar day (seed =
  YYYYMMDD), Medium difficulty. Solving it extends the daily streak.
- **Seed puzzles:** any integer seed always builds the same puzzle.
- **Hard mode** (9×9) is a PRO feature.

## 8. Scoring
- Each board records the number of twists used.
- Lifetime stats: boards solved, best (fewest) twists on any board.
- Campaign progress: 60 boards per difficulty, tracked separately.

## 9. Winning conditions
All endpoints are in the connected set (water reaches every endpoint).
The board celebrates (~1.6s), then the win sheet offers Next / Replay /
Menu. In the campaign, "Next" advances to the next board.

## 10. Draw conditions
Not applicable — every board is winnable; there are no draws.

## 11. AI strategy
Not applicable — there are no bots. Difficulty comes from the puzzle
generator: larger grids, denser networks, more endpoints.

## 12. Edge cases
- A scrambled board that is already solved is impossible by construction:
  the generator re-twists one random tile if the scramble comes out clean.
- Twisting a pipe may disconnect previously-lit pipes; they dim again and
  will re-light with animation when reconnected.
- Backgrounding the app pauses all engine timers; the watchdog resumes
  them on return. No state can get stuck.
- Hints never highlight the pump (it has no wrong rotation).
- If every tile is already correct, the hint button reports "no hints
  needed" via the invalid sound.

## 13. Test cases
1. Generator: same (seed, difficulty) always yields the same puzzle.
2. Generator: the scrambled board differs from the solution in at least
   one tile.
3. Engine: untwisting every scrambled tile back to the solution lights
   all endpoints and reaches the `over` phase.
4. Engine: tapping the pump does not change its glyph or the move count.
5. Engine: twist increments the move counter exactly once per tap.
6. Settings: player names persist as one JSON string (never StringList);
   legacy keys migrate once and are removed.
7. Settings: free players cannot select Hard mode, PRO themes, PRO pipe
   styles, or the custom theme; PRO players can.
8. IAP: product IDs are exactly `pipeconnectpro`, `pipeconnectcoffee`,
   `pipeconnectchocolate` (no dots, no underscores).
