# Ball Sort Puzzle — Complete Upgrade Prompt
### Flutter + GetX | AI Agent Dev Specification

---

## 📸 Screenshot Analysis (What's Broken Right Now)

| Screenshot | Issue Observed |
|---|---|
| Level 5 | All 4 reds in Tube 1, all 4 blues in Tube 2, all 4 yellows in Tube 4, all 4 greens in Tube 5 — already sorted, game completes with 0 meaningful moves |
| Level 9 | Same pre-sorted issue. Second row of tubes clips out of the screen viewport |
| Level 14 | Some mixing visible but many tubes still monochromatic. UI overflow persists. Mute button cut off on right edge |
| Level 14 (2nd) | Ball animation is a simple position jump — no arc, no lift, no curve in air. Floating ball has no physics feel |

---

## 🐛 Bug Fix 1 — Level Generation (Most Critical)

### Problem
Levels generate with all balls of the same color already grouped in one tube.
A user can "complete" the puzzle by moving one ball to the empty tube and moving it back.
This is **not a puzzle** — it's a bug.

### Fix: Proper Shuffle Algorithm

```dart
// LevelGeneratorService — Dart pseudocode

List<List<int>> generateLevel(int level) {
  int colors = getColorCountForLevel(level);       // 4 at level 1, scales up
  int tubesPerColor = 4;                            // each color has 4 balls
  int emptyTubes = getEmptyTubesForLevel(level);   // 1 at early levels, 2 later

  // Step 1: Create flat list of all balls
  List<int> allBalls = [];
  for (int c = 0; c < colors; c++) {
    for (int i = 0; i < tubesPerColor; i++) allBalls.add(c);
  }

  // Step 2: Shuffle
  allBalls.shuffle(Random());

  // Step 3: Fill tubes (each tube gets exactly 4 balls)
  List<List<int>> tubes = [];
  for (int t = 0; t < colors; t++) {
    tubes.add(allBalls.sublist(t * 4, t * 4 + 4));
  }

  // Step 4: Add empty tubes
  for (int e = 0; e < emptyTubes; e++) tubes.add([]);

  // Step 5: Validate — reject if already solved or too easy
  if (isAlreadySolved(tubes) || minimumMovesToSolve(tubes) < minMovesForLevel(level)) {
    return generateLevel(level); // regenerate
  }

  return tubes;
}
```

### Validation Rules
- **No tube may start with 4 balls of the same color.**
- **Every color must appear in at least 2 different tubes** at game start.
- **Minimum move count must be ≥ threshold per level** (see difficulty table below).
- **Puzzle must be solvable** — run a BFS/DFS solver to verify before presenting to user.

### ✅ Correct Start State Example (Level 5)
```
Tube 1: [Red,  Blue,  Green, Yellow]
Tube 2: [Yellow, Red,  Blue,  Green ]
Tube 3: [Green, Yellow, Red,  Blue  ]
Tube 4: [Blue,  Green, Yellow, Red  ]
Tube 5: [Empty]
```

### ❌ Forbidden Start State (Currently Happening)
```
Tube 1: [Red,   Red,   Red,   Red  ]
Tube 2: [Blue,  Blue,  Blue,  Blue ]
Tube 3: [Empty]
Tube 4: [Yellow,Yellow,Yellow,Yellow]
Tube 5: [Green, Green, Green, Green ]
```

---

## 📈 Bug Fix 2 — Dynamic Difficulty Progression

| Level Range | Colors | Empty Tubes | Min Moves Required | Max Allowed Moves |
|---|---|---|---|---|
| 1–5 | 4 | 1 | 8 | 20 |
| 6–15 | 5–6 | 1–2 | 14 | 30 |
| 16–30 | 7–8 | 2 | 20 | 45 |
| 31–50 | 9–10 | 2 | 28 | 60 |
| 51+ | 10–12 | 2–3 | 35+ | Dynamic |

**Use permutation-based generation, not random shuffling alone.**
Think Tower of Hanoi — the goal is to teach the user optimal move planning.

---

## 🎯 Bug Fix 3 — Move Limit System

### Display in Top Bar
```
Best: 12 moves   |   Avg: 18 moves   |   Your moves: [live counter]
```

### Game Over Condition
If `playerMoves > maxAllowedMoves`:
- Show Game Over screen
- Play `Game_Over.mp3`
- Show options: **Retry** | **See Best Solution** | **Exit**

### Move Counter Logic
```dart
// GameController
void onBallMoved() {
  moveCount++;
  if (moveCount > maxMovesForLevel) triggerGameOver();
  update();
}
```

---

## 🏆 Bug Fix 4 — Score System Redesign

### Current Problem
Score shows random values like 7175 at Level 5 with 0 moves played. This is broken.

### New Formula
```
Score = (baseLevelScore * difficultyMultiplier)
      + (remainingMoves * 50)
      + (speedBonus if completed in < half time limit)
      - (hintsUsed * 200)
      - (undosUsed * 100)
```

| Variable | Value |
|---|---|
| baseLevelScore | level × 500 |
| difficultyMultiplier | 1.0 to 3.0 based on level |
| speedBonus | up to 1000 if fast |
| hintPenalty | −200 per hint |
| undoPenalty | −100 per undo |

Score starts at **0** when a level begins. Never pre-populate a score from a previous level into the new level's display.

---

## 🎬 Bug Fix 5 — Ball Movement Animation

### Current State
Ball teleports instantly. No arc. No physics feel. Rating: 0/10.

### Required Animation: "Pick → Lift → Arc → Drop"

```dart
// AnimationManager — BallMoveAnimation

Future<void> animateBallMove({
  required Offset sourcePosition,
  required Offset destinationPosition,
  required AnimationController controller,
}) async {
  final path = buildArcPath(sourcePosition, destinationPosition);

  // Phase 1: Lift up (0.0 → 0.3)
  // Phase 2: Arc through air (0.3 → 0.7)
  // Phase 3: Drop with slight bounce (0.7 → 1.0)

  controller.forward();
}

Path buildArcPath(Offset src, Offset dst) {
  final Path path = Path();
  path.moveTo(src.dx, src.dy);

  // Control point: above midpoint for upward arc
  final controlPoint = Offset(
    (src.dx + dst.dx) / 2,
    min(src.dy, dst.dy) - 120.0,   // 120px above the lower of the two tubes
  );

  path.quadraticBezierTo(
    controlPoint.dx, controlPoint.dy,
    dst.dx, dst.dy,
  );
  return path;
}
```

### Use These Flutter Tools
- `AnimationController` with `vsync`
- `TweenSequence` for multi-phase easing
- `CurvedAnimation` with `Curves.easeInOutCubic`
- `CustomPainter` to draw the ball along the path
- `PathMetrics` to compute position at each frame

### Ball Visual During Move
- Ball scales up slightly (1.0 → 1.15) when lifted
- Ball casts a soft shadow during arc
- Ball scales back to 1.0 on landing
- Play `Tile Moving 02.mp3` on lift

---

## 🎨 Bug Fix 6 — UI Layout & Overflow

### Background
Remove the current dark navy game background entirely.
```dart
// Scaffold / Container
color: Colors.transparent,  // or Colors.black.withOpacity(0.0)
```
The app's existing wallpaper/background should show through.
Apply a **glassmorphism** container for the game area:
```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.08),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.white.withOpacity(0.15)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 20,
        spreadRadius: 2,
      )
    ],
  ),
)
```

### Tube Layout — Fix Overflow
```dart
// Use LayoutBuilder + Wrap or GridView
LayoutBuilder(
  builder: (context, constraints) {
    final tubeWidth = (constraints.maxWidth - padding) / maxTubesPerRow;
    final tubeHeight = tubeWidth * 2.8;  // maintain aspect ratio

    return Wrap(
      spacing: 8,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: tubes.map((tube) => TubeWidget(
        width: tubeWidth.clamp(48.0, 72.0),
        height: tubeHeight.clamp(130.0, 200.0),
        balls: tube,
      )).toList(),
    );
  },
)
```

Tubes per row by level:
| Level | Tubes | Max per Row |
|---|---|---|
| 1–5 | 5 | 5 |
| 6–15 | 7–8 | 4 |
| 16+ | 10–12 | 5 |

### Top Bar — Fix Mute Button Overflow
```dart
Row(
  children: [
    Flexible(child: _levelChip()),
    Flexible(child: _movesChip()),
    Flexible(child: _scoreChip()),
    Flexible(child: _timerChip()),
    _muteButton(),  // fixed width, never Expanded
  ],
)
```
All chips use `Flexible` + `FittedBox`. Never use fixed pixel widths in the top bar.

---

## 🔊 Bug Fix 7 — Sound System (SoundManager)

### Problem
Multiple sounds play simultaneously. "Excellent" and "Game Over" overlap.
Background music doesn't duck when effects play.

### SoundManager Architecture (GetX Service)

```dart
class SoundManager extends GetxService {
  AudioPlayer _bgPlayer = AudioPlayer();
  AudioPlayer _fxPlayer = AudioPlayer();

  final _bgTracks = ['chinese_map.mp3', 'fairy_tale_level.mp3'];

  // Start looping background music
  Future<void> startBackgroundMusic() async {
    final track = _bgTracks[Random().nextInt(_bgTracks.length)];
    await _bgPlayer.setAsset('assets/sounds/$track');
    _bgPlayer.setLoopMode(LoopMode.one);
    _bgPlayer.setVolume(0.6);
    _bgPlayer.play();
  }

  // Play FX and auto-duck bg
  Future<void> playFX(String filename, {bool duck = false}) async {
    if (duck) await _bgPlayer.setVolume(0.15);  // duck to 15%
    await _fxPlayer.setAsset('assets/sounds/$filename');
    await _fxPlayer.play();
    if (duck) {
      await Future.delayed(_fxPlayer.duration ?? Duration(seconds: 2));
      await _bgPlayer.setVolume(0.6);  // restore
    }
  }

  void stopAll() {
    _bgPlayer.stop();
    _fxPlayer.stop();
  }
}
```

### Sound Trigger Map

| Event | Sound File | Duck BG? |
|---|---|---|
| App/Level Start | `Get_ready.mp3` or `Pixelus Start of Puzzle v02.mp3` | No |
| Ball Moved | `Tile Moving 02.mp3` | No |
| Button Click | `click_enter.mp3` or `button1.mp3` | No |
| Correct Progress | `excellent1.mp3` or `right-ans.mp3` | Yes |
| Wrong Move | `warning1.mp3` or `wrong-ans.mp3` | No |
| Hint Requested | `Pixelus Hint Screen v01.mp3` | Yes |
| 10 Seconds Left | `heart-beat-10sec-timer.mp3` | No |
| Level Complete | `Level_Complete.mp3` → `A_New_High_Score.mp3` | Yes |
| Game Over | `Game_Over.mp3` | Yes |
| Good Move Streak | `crowd-cheer.mp3` or `Crowd Applause 01.mp3` | Yes |
| Unexpected Comeback | `tiger-roar.mp3` or `wow.mp3` | Yes |
| User Idle Too Long | `rooster-cry.mp3` or `Go.mp3` | No |

### Rules
- Only ONE fx sound at a time. If a new FX triggers while one plays, stop the previous.
- Background music loops continuously throughout gameplay.
- BG music rotates randomly on each new level.
- BG volume ducks to 15% during Level Complete / Game Over / Hint events, then restores.

---

## 💡 Bug Fix 8 — Post-Level Solution Replay

After a level is completed:

### Show Stats Screen
```
┌─────────────────────────────┐
│  Level 5 Complete! 🎉        │
│                              │
│  Best Solution:   12 moves   │
│  Average:         18 moves   │
│  You Used:        15 moves   │
│                              │
│  Efficiency: ⭐⭐⭐⭐ GREAT!    │
│                              │
│  [▶ Watch Best Solution]     │
│  [▶ Watch Average Solution]  │
│  [🔁 Retry Level]            │
│  [➡ Next Level]              │
└─────────────────────────────┘
```

### Auto-Play Animation
When user taps "Watch Best Solution":
1. Reset board to original state
2. Execute each move in the optimal path with full arc animation
3. 600ms delay between moves so user can follow
4. After all moves play: show "That's the best way!" overlay
5. Offer Retry / Next Level

```dart
// PuzzleSolverService
List<Move> computeBestSolution(List<List<int>> initialState) {
  // BFS / A* solver
  // Returns ordered list of Move(fromTube, toTube)
}

// AnimationManager
Future<void> replaySolution(List<Move> moves) async {
  for (final move in moves) {
    await animateBallMove(from: move.from, to: move.to);
    await Future.delayed(Duration(milliseconds: 600));
  }
}
```

---

## 🧪 Feature: Alternate Liquid Sort Mode

### Concept
Every alternate level uses **colored liquids** instead of balls.
Same sorting logic — but visuals and terminology change.

| Level | Mode |
|---|---|
| Odd levels (1,3,5…) | Ball Sort |
| Even levels (2,4,6…) | Liquid Sort |

### Liquid Sort Differences
- Tubes look like glass lab flasks/beakers
- Balls are replaced by layered liquid fill (gradient rectangle per color layer)
- Volume unit displayed as **ml** (e.g., 25ml per layer, 100ml total per flask)
- Pour animation: liquid "flows" from source flask, arcs, and settles into destination
- Bubbles particle effect when liquid is poured
- Score formula same but display shows "Pour efficiency"

### Flutter Implementation
```dart
// TubeWidget switches between BallTube and LiquidTube based on level mode
Widget buildTube(TubeType type, List<int> contents) {
  return type == TubeType.ball
    ? BallTubeWidget(balls: contents)
    : LiquidTubeWidget(layers: contents);
}

// LiquidTubeWidget renders stacked colored rectangles with gradient fill
// AnimatedLiquidPour uses a custom painter to simulate flowing liquid
```

---

## 🏗 Architecture

Create these GetX classes:

```
lib/
├── controllers/
│   └── GameController.dart         ← selected tube, move validation, win check
├── services/
│   ├── LevelGeneratorService.dart  ← generates valid, unsolved levels
│   ├── PuzzleSolverService.dart    ← BFS solver for best/avg case
│   ├── SoundManager.dart           ← all audio, ducking, rotation
│   ├── ScoreManager.dart           ← score formula, persistence
│   └── AnimationManager.dart       ← arc paths, replay logic
├── models/
│   ├── Tube.dart
│   ├── Ball.dart
│   ├── LiquidLayer.dart
│   └── Move.dart
├── widgets/
│   ├── BallTubeWidget.dart
│   ├── LiquidTubeWidget.dart
│   ├── TopBarWidget.dart
│   └── PostLevelDialog.dart
└── screens/
    └── BallSortGameScreen.dart
```

### Dependency Injection
```dart
// main.dart or binding
Get.put(SoundManager());
Get.put(LevelGeneratorService());
Get.put(PuzzleSolverService());
Get.put(ScoreManager());
Get.lazyPut(() => GameController());
```

---

## 📋 Complete Checklist for AI Agent

- [ ] Fix level generator — no pre-sorted levels, all colors mixed
- [ ] Add solvability validation — BFS check before presenting level
- [ ] Implement difficulty table — complexity scales per level range
- [ ] Add move limit system — game over when exceeded
- [ ] Fix score formula — starts at 0, depends on performance
- [ ] Implement arc ball animation — lift, curve through air, drop with bounce
- [ ] Remove game background — transparent + glassmorphism
- [ ] Fix tube layout — responsive Wrap, no overflow on any screen size
- [ ] Fix top bar — all chips Flexible, mute button never clips
- [ ] Build SoundManager — single FX at a time, BG ducking, track rotation
- [ ] Map all sound events to correct files from sound_effects.txt
- [ ] Build post-level stats screen — best/avg/your moves + efficiency rating
- [ ] Implement solution replay — auto-play with arc animation, 600ms delay
- [ ] Add Liquid Sort alternate mode — even levels use flasks + pour animation
- [ ] Implement GetX architecture — all services via Get.put(), UI separated from logic

---

## 🎓 Educational Goal

The game should teach children **computational thinking** — the same concepts as Tower of Hanoi:

> "In how few moves can you solve this? What is the best case? The average case?"

Every level should feel like a **nail-biter** — not a nursery color-matching activity.
The child should finish each level feeling they've **solved something real**.

---

*App: Flutter + GetX | Sound assets at: `assets/sounds/` and `assets/sounds/game_sounds/` | Target: All screen sizes*
