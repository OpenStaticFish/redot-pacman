# DOT EATER

**Eat dots. Chase your upstream.**

A native Redot/Godot arcade maze game built for deeply unserious marketing.
Play as **Redion**, the Redot mascot, dodge the Godot-logo upstream ghosts,
and grab a power dot to turn your upstream into a snack.

## Play

Open `project.godot` in **Redot 26.2** and press **F6/F5**, or run:

```sh
./launch.sh
```

The launcher works from any directory and forwards engine arguments, such as
`./launch.sh --fullscreen`. If needed, set `REDOT_BIN` to your Redot executable.

The title screen is a live autoplay attract mode. Click **PLAY NOW** or press
**Enter** to start your own three-life run. The project uses Godot 4-compatible
GDScript and the Compatibility renderer.

| Control | Action |
| --- | --- |
| Arrow keys / WASD | Move; turns are buffered, reversals are instant |
| Enter / Space | Start from the attract screen or game over |
| P / Esc / Space | Pause or resume during a run |
| R | Restart |
| Tab | Restart the autoplay demo |
| M | Mute/unmute music and effects |
| F11 | Toggle fullscreen |
| F9 | Save a clean screenshot to the engine's user-data directory |
| C | Credits |
| Gamepad | Left stick / D-pad to move, A to start, Start to pause |
| Mouse / touch | Click the buttons; swipe on the maze to steer |

### Rules

- Small dots: **10** points. Big power dots: **50** points and **8 seconds** of
  upstream panic.
- Eat frightened ghosts for **200 / 400 / 800 / 1600** points per combo.
- One-tile-wide lanes form connected loops with no dead ends. The side tunnels
  wrap between the labeled warp ports. Ghosts return to their house after being eaten.
- A bonus **fork** appears after 65 dots: collect it for **500** points.
- Clear every dot for **1000** bonus points and a faster next release.
- Three lives per run. Personal best and sound preferences persist locally.
- Four ghost personalities: direct pursuit, ambush, flanking, and shy pursuit.

## Make an X clip

Ready-made files are in `marketing/`: a gameplay still and a **20-second,
1600 × 900, 60 FPS MP4** with arcade audio.

The UI is composed at **1600 × 900 (16:9)**. Attract mode plays the real game
with an AI pilot, including power dots, ghost combos, and the live commit log.
Press **Tab** for a fresh demo, **F11** for fullscreen, and record it with OBS,
or use the engine's built-in Movie Maker:

```sh
redot --path . --resolution 1600x900 --fixed-fps 60 \
  --write-movie /tmp/dot-eater.avi --quit-after 1200 -- --demo

ffmpeg -i /tmp/dot-eater.avi \
  -vf "scale=in_color_matrix=bt601:out_color_matrix=bt709:in_range=full:out_range=limited,format=yuv420p" \
  -c:v libx264 -crf 18 -color_range tv -colorspace bt709 \
  -color_primaries bt709 -color_trc bt709 \
  -af "loudnorm=I=-16:TP=-1.5:LRA=11" -ar 48000 \
  -c:a aac -b:a 160k -movflags +faststart /tmp/dot-eater.mp4
```

That produces a **20-second** clip with the original synthesized arcade audio.
Give Movie Maker a normal graphics/display session. The output parent directory
must exist. Quit normally so the movie's header is finalized.

For a reproducible clean still:

```sh
redot --path . --resolution 1600x900 --fixed-fps 60 -- \
  --demo --capture=/tmp/dot-eater.png --capture-frame=480
```

Caption material:

> pov: your fork has an appetite
>
> upstream is now a downstream snack. 🟠
>
> we heard you like dots so we re-dotted your dots

## Assets

The **entire supplied brand kit** is copied into `assets/redot_brand/`, including
the PDF guidelines, all logo variants, and original font archives. A `.gdignore`
keeps unused high-resolution variants out of the import pipeline. The in-game
SVGs and fonts are copied into `assets/branding/` and `assets/fonts/`.

Godot ghost icons come from the official press kit. Original logo proportions
are preserved. Attribution is included in `assets/ATTRIBUTION.md`, the original
notices, and the in-game credits.

## Project layout

- `scenes/arcade.tscn` — the launch scene.
- `scripts/arcade_maze.gd` — maze data, pickups, tunnels, and routes.
- `scripts/maze_runner.gd` — continuous, tile-centered movement.
- `scripts/game_session.gd` — rules, ghost personalities, and autoplay.
- `scripts/arcade_view.gd` — custom-drawn cabinet UI, controls, and effects.
- `scripts/arcade_icons.gd` — crisp, shared vector icons for the arcade HUD.
- `scripts/arcade_audio.gd` — original procedural chip music and sound effects.

## Verify

```sh
redot --headless --path . --import
redot --headless --path . -s tests/gameplay_test.gd
redot --headless --path . -s tests/input_test.gd
```

The behavioral checks reject open 2×2 lane sections and dead ends, and cover
reachable pellets, buffered turning, smooth
reversals, tunnel wrapping, power-dot combos, lives, pause, level progression,
and a 45-second autoplay soak. The native input checks exercise the launch scene
through Godot's input system using keyboard, mouse, and touch events, including
start, steering, pause, mute, credits, autoplay, and restart. On a graphical
display they also verify the fullscreen button and F11. Touch-generated mouse
events are filtered so a tap never toggles a button twice.
