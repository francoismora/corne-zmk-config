# ZMK Lessons Learned

Practical findings from building a custom ZMK keymap for the Keebart
Corne Choc Pro (5-column, 36-key split). These are things that aren't
obvious from the ZMK docs and cost real debugging time.

## Keymap structure

### The matrix transform controls everything

The `matrix-transform` in the board's `.dtsi` file decides which
physical matrix positions map to keymap bindings. The binding array
order matches the transform's `map` property, left to right, row by
row. If a position is absent from the map, there is no binding for it
— no `&trans` needed.

The Corne Choc Pro has two transforms:
- `default_transform` — 14 columns (6 keys per half + 2 cluster keys
  in the middle + 2 outer keys). For the 42-key variant.
- `five_col_transform` — for the 36-key variant (5 keys per half).

### The 5-column layout has cluster keys in the middle

The 4 cluster keys (2 per half: a standard key + the encoder push
button) are at columns 6-7 — the middle of the matrix, between the two
halves. They are NOT at the outer edges (cols 0 and 13).

The 5-column transform maps:
```
[L1-L5] [cluster-L cluster-R] [R1-R5] = 12 bindings (rows 0-1)
[L1-L5] [R1-R5]               = 10 bindings (row 2, no cluster)
[thumb-L] [thumb-R]            =  6 bindings (row 3)
```

Columns 0 and 13 (the outer edges of the 6-column layout) are skipped
on the 5-column keyboard — those positions don't exist physically.

### Encoder push buttons are kscan keys, not encoder GPIOs

The EC11 rotary encoder driver only handles rotation (a-gpios,
b-gpios). The encoder push button is a separate switch wired into the
kscan matrix at columns 6-7. It behaves as a regular key — bind it
with `&kp` like any other key.

### `&trans` fills gaps, `&none` disables

- `&trans` — transparent: falls through to the layer below. Use for
  positions that should inherit from lower layers.
- `&none` — no-op: the key does nothing. Use when you want to block
  fall-through.

## Behaviors

### Mod-tap uses keycodes, not MOD_ constants

`&mt` takes modifier keycodes directly:

```c
&mt LGUI A    // correct: LGUI on hold, A on tap
&mt MOD_LGUI A  // WRONG: MOD_LGUI is a bitmask (0x08), not a keycode
```

The modifier keycodes are: `LGUI`, `LALT`, `LCTL`, `LSHFT`, `RGUI`,
`RALT`, `RCTL`, `RSHFT`.

### Layer-tap syntax

```c
&lt LAYER_NAME KEY    // hold = layer, tap = key
```

The layer name must be a `#define` placed BEFORE any `/ {` block. The
C preprocessor expands it to the layer index.

### Custom sensor behavior for mouse scroll

ZMK has no built-in encoder binding for mouse scroll. To use encoders
for scrolling, define a custom `behavior-sensor-rotate-var` that
wraps `&msc` (mouse scroll):

```dts
behaviors {
    inc_dec_ms: inc_dec_ms {
        compatible = "zmk,behavior-sensor-rotate-var";
        #sensor-binding-cells = <2>;
        bindings = <&msc>, <&msc>;
    };
};
```

Then use `&inc_dec_ms SCRL_LEFT SCRL_RIGHT` in `sensor-bindings`.

Requires `CONFIG_ZMK_POINTING=y` in the `.conf` file.

### Mouse behaviors

| Behavior | Purpose | Example |
|----------|---------|---------|
| `&mkp` | Mouse button click | `&mkp LCLK` (left click) |
| `&mmv` | Mouse move | `&mmv MOVE_UP` |
| `&msc` | Mouse scroll | `&msc SCRL_DOWN` |

Include `<dt-bindings/zmk/mouse.h>` for the move/scroll constants.

## Build system

### Keymap resolution priority

The build searches for a keymap in this order:
1. `config/` directory (via `-DZMK_CONFIG`) — highest priority
2. Board directory (`boards/arm/.../`)
3. Shield directory

`config/corne_choc_pro.keymap` always wins over the board's default.
The same applies to `.conf` files.

### `-DZMK_CONFIG` is required for local builds

Without `-DZMK_CONFIG`, the local build falls back to the board's
default keymap. The cloud build (GitHub Actions) passes it
automatically. `build.sh` passes `-DZMK_CONFIG=$REPO/config` to keep
local and cloud builds consistent.

### Board discovery: `-DBOARD_ROOT` vs `zephyr/module.yml`

Two mechanisms, one per build path:
- **Local**: `-DBOARD_ROOT=<repo>` tells Zephyr where to find
  `boards/`.
- **Cloud**: `zephyr/module.yml` with `board_root: .` makes the ZMK
  reusable workflow load the repo as a Zephyr module.

Both are needed. The `zephyr/module.yml` file must be committed to git
(not just present locally) — the fetched `zephyr/` workspace is a
nested git repo that blocks `git add` inside it.

### Python dependencies

The venv needs Zephyr's `requirements-base.txt` (pyelftools, PyYAML,
etc.) and ZMK's `scripts/requirements.txt` (jsonschema, remarshal).
Also pin `setuptools<81` — Python 3.14 + setuptools 81+ removed
`pkg_resources`, which nanopb's protoc wrapper needs.

## Keycodes

Use the full canonical name, not short aliases, when in doubt:
- `INSERT` (not `INS`) — both work, but the full name is safer
- `CAPSLOCK` (not `CAPS`)
- `KP_NUMLOCK` (not `KP_NLCK`)
- `PAUSE_BREAK` (not `PAUSE`)

Keycodes are defined in `zmk/app/include/dt-bindings/zmk/keys.h`.
Grep this file to find the correct name for any key.

## Flashing

### Drive labels don't indicate left/right

`KEEBART` vs `KEEBART1` depends on which half entered bootloader mode
first, not which is left or right. Flash one half at a time to avoid
ambiguity.

### `cp` not drag-and-drop

Drag-and-drop is unreliable for UF2 flashing. Use `cp`:
```bash
cp firmware.uf2 /run/media/francois/KEEBART/
```

### Re-pair after flashing

Single-press reset on both halves within 2-3 seconds to trigger BLE
pairing. The peripheral (right) half only connects to the central
(left) via BLE — it will not work if connected to the host via USB
data.
