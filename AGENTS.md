# Repository instructions

## Run and verify

- Use Redot 26.2 (`redot`), GDScript, and the Compatibility renderer. `./launch.sh` accepts `REDOT_BIN` and resolves the project independently of the current directory.
- Import before running scripts on a fresh checkout or after adding global classes/assets; this builds the ignored `.godot/` cache and class registry:

```sh
redot --headless --path . --import
redot --headless --path . -s tests/gameplay_test.gd
redot --headless --path . -s tests/input_test.gd
```

- Tests are standalone `SceneTree` scripts, not a test-framework runner. Focused syntax check: `redot --headless --path . --check-only --script scripts/arcade_view.gd`. No repo lint/typecheck task is configured.
- Headless input tests skip fullscreen and cannot verify rendered shaders/layout. With a graphics display, run `redot --path . -s tests/input_test.gd -- --1440p`; inspect captured normal and powered states for visual changes.
- The view and input tests use the real `user://dot_eater.cfg` for persistent score/mute preferences. The app opens in autoplay; `./launch.sh -- --play` starts a human run. App arguments belong after `--`.

## Wiring and invariants

- Entry chain: `project.godot` → `scenes/arcade.tscn` → `scripts/arcade_view.gd`. `GameSession` is rendering-independent and ticked at 120 Hz; `MazeRunner` moves in grid units. `arcade_event` connects rules to presentation/audio.
- `ArcadeMaze.ROWS` is the collision/pickup/pathfinding source of truth. Playable lanes must stay connected, one tile wide (no open 2×2 blocks), and without dead ends; the ghost house is intentionally inaccessible to the player. Only row 12 wraps horizontally.
- UI drawing and button hit rectangles share fixed 1600×900 design coordinates. Keep hit areas aligned when moving controls; decorative `Label`/`ColorRect` children must ignore mouse input.
- Preserve filtering of `InputEvent.DEVICE_ID_EMULATION`: accepting both touch and its emulated mouse event double-toggles controls. Tests convert design positions through canvas/screen transforms before injecting input.
- Shared website colors/shaders live in `scripts/redot_style.gd`; UI fonts are Roboto variations, scores/telemetry use JetBrains Mono. Maze walls and warp cues are blue normally, Redot red while `power_time > 0`, then blue again.
- Web builds draw baked maze/background textures from `assets/web/`. After maze geometry or style changes, regenerate them with `redot --path . -s tools/bake_web_art.gd` on a graphics display, then run `bash export-web.sh`. Audio pause assignments must be transition-only: the web sample backend can restart/copy music on redundant unpause calls.

## Assets and captures

- `.godot/` is disposable/ignored; resource `.import` files and script/shader `.uid` files are tracked. Preserve their identities when editing or moving resources.
- `assets/redot_brand/` contains the complete original kit and has `.gdignore` to suppress unused imports. Use curated files in `assets/branding/` and `assets/fonts/`; retain original logo proportions and notices in `assets/ATTRIBUTION.md`.
- `marketing/.gdignore` suppresses engine import, not Git tracking. MP4, PNG, and README GIF are committed outputs; raw AVI is ignored. Keep regenerated media consistent with the README showcase.
- Native 1440p movies use `project.godot`'s `.movie` window-size overrides, while the logical UI stays 1600×900. Recording requires a graphics display (offscreen Xvfb must accommodate 2560×1440), not `--headless`.
- Reproducible still: `redot --path . --fixed-fps 60 -- --1440p --capture=/tmp/dot-eater.png --capture-frame=180` (normal blue); frame 548 shows red power mode. Use a fresh process: restarting autoplay does not reset its RNG or shader clock.
- Use the README's Movie Maker/FFmpeg commands for 20-second, 60 FPS video and BT.709/loudness conversion. Quit normally or use `--quit-after` so AVI headers finalize; derive the animated README preview from the final MP4.
