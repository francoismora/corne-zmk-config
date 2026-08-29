# Corne Choc Pro — User Guide

This guide covers the practical workflow for configuring layouts, building
firmware, and flashing it to the Keebart Corne Choc Pro. It also explains the
settings-reset firmware and how to troubleshoot environment issues.

For the authoritative reference on ZMK behaviors, keycodes, and keymap syntax,
use the [ZMK documentation](https://zmk.dev/docs). This guide does not repeat
that material — it tells you *where* things live in this repo and *how* the
pieces fit together.

## Table of contents

1. [How the keymap is resolved](#how-the-keymap-is-resolved)
2. [Configuring your layout](#configuring-your-layout)
3. [Building firmware](#building-firmware)
4. [Flashing firmware](#flashing-firmware)
5. [The settings-reset firmware](#the-settings-reset-firmware)
6. [Troubleshooting environment issues](#troubleshooting-environment-issues)

---

## How the keymap is resolved

There are two keymap files in this repo, and understanding which one is used is
the single most important thing to know:

| File | Role | When it's used |
|------|------|----------------|
| `config/corne_choc_pro.keymap` | **Your keymap.** Edit this one. | Always — both local and cloud builds. |
| `boards/arm/corne_choc_pro/corne_choc_pro.keymap` | Board default. Do not edit. | Never, as long as `config/corne_choc_pro.keymap` exists. |

The build system searches for a keymap in a priority order. `config/` is
prepended to the search list (via `-DZMK_CONFIG`), so `config/corne_choc_pro.keymap`
always wins over the board's built-in default. The same applies to the config
file: `config/corne_choc_pro.conf` overrides the board's defconfig values.

If you delete `config/corne_choc_pro.keymap`, the build silently falls back to
the board default. Don't do that unless you want the Keebart stock layout.

## Configuring your layout

### What to edit

- **`config/corne_choc_pro.keymap`** — your keymap (layers, bindings, encoders).
- **`config/corne_choc_pro.conf`** — Kconfig overrides (idle timeout, keyboard
  name, pointing, etc.). Most options are commented out; uncomment to enable.

### The matrix and the gaps

The Corne Choc Pro uses a 4-row x 14-column matrix, but not every position has a
physical key. The bindings array must always have exactly 56 entries (14 per
row), with `&trans` filling the gaps:

```
Row 0:  cols 0-13 (all present)
Row 1:  cols 0-13 (all present)
Row 2:  cols 0-5, 8-13   (gap at 6-7)
Row 3:  cols 3-5, 8-10    (gaps at 0-2, 6-7, 11-13)
```

If you miscount the bindings or omit `&trans` in a gap, the devicetree parser
rejects the build. The existing keymap is a correct template — copy its
structure when adding layers.

### Layers

Layers are numbered from 0. The default keymap defines:

| Index | Name | Purpose |
|-------|------|---------|
| 0 | `default_layer` | QWERTY base |
| 1 | `lower_layer` | Numbers, Bluetooth, RGB, reset |
| 2 | `raise_layer` | Symbols |
| 3-8 | `extra_layer_1` to `extra_layer_6` | Empty placeholders |

To add a new layer, append a new block inside `keymap { ... }` and reference it
by index (e.g. `&mo 3` for momentary access, `&lt 3 SPACE` for layer-tap).

### Where to learn the syntax

The [ZMK keymap documentation](https://zmk.dev/docs/keymaps) covers behaviors
(`&kp`, `&mt`, `&lt`, `&mo`, `&to`), combos, and the full keycode list. This
guide does not duplicate that. The keymap file in this repo uses the standard
ZMK syntax — read it alongside the docs.

### Physical layouts

The board supports two physical layouts, selected in the keymap:

```dts
chosen {
    zmk,physical-layout = &default_layout;  // 6 columns/half, 42 keys
    // zmk,physical-layout = &five_col_layout;  // 5 columns/half, 36 keys
};
```

The `default_layout` (14 columns) is correct for the standard Corne Choc Pro.
Switch to `five_col_layout` only if you have the 36-key variant. The layout
definitions live in `boards/arm/corne_choc_pro/corne_choc_pro-layouts.dtsi` —
you normally won't edit them.

---

## Building firmware

### Local build

```bash
./build.sh
```

First run: creates a Python venv, fetches ZMK + Zephyr + modules (~1 GB
download), then builds all four firmware targets. Subsequent runs skip the
setup. Output in the repo root:

| File | Target |
|------|--------|
| `corne_choc_pro_left.uf2` | Left half (central) with display |
| `corne_choc_pro_right.uf2` | Right half (peripheral) with display |
| `settings_reset_left.uf2` | Left half settings reset |
| `settings_reset_right.uf2` | Right half settings reset |

### Cloud build (GitHub Actions)

Push to GitHub. The workflow in `.github/workflows/build.yml` calls ZMK's
reusable build workflow at the tag pinned in `config/west.yml`. Artifacts are
downloadable from the Actions run page. No local toolchain needed.

### Upgrading ZMK

1. Edit `config/west.yml` — change `revision:` to the target tag or SHA.
2. Edit `.github/workflows/build.yml` — change the `@v0.3.0` ref to match.
3. Locally: `source .venv/bin/activate && west update`
4. Rebuild with `./build.sh`.

Keep both pins in sync so local and cloud builds use the same ZMK version.

---

## Flashing firmware

Each half has position-specific firmware. Never swap them.

1. Double-press the reset button on one half with a SIM tool. It mounts as a
   USB drive named `KEEBART` (left) or `KEEBART1` (right).
2. Copy the matching `.uf2` with `cp` (drag-and-drop is unreliable):
   ```bash
   cp corne_choc_pro_left.uf2 /run/media/francois/KEEBART/
   ```
3. Wait for the drive to auto-eject, then repeat for the other half.
4. Re-pair the halves: single-press reset on both within 2-3 seconds of each
   other. This triggers BLE pairing between central and peripheral.

### Verifying the flash

```bash
lsusb | grep 1d50:615e       # should show the Corne Choc Pro
ls /dev/input/by-id/ | grep ZMK
```

### Diagnosing a swapped flash

If a half appears bricked (no LED, no input), the firmware may be swapped. The
encoder labels in the firmware reveal which half it belongs to:

```bash
strings corne_choc_pro_left.uf2 | grep encoder
# should show: encoder_left_ex1, encoder_left_ex2

strings corne_choc_pro_right.uf2 | grep encoder
# should show: encoder_right_ex1, encoder_right_ex2
```

If you see `encoder_right` in the left firmware or vice versa, re-flash with
the correct file.

---

## The settings-reset firmware

The `settings_reset` shield produces a special firmware that clears all
persisted settings on a half — most importantly the BLE bond information.

### Why it exists

ZMK stores BLE pairing keys, RGB state, and other settings in non-volatile
storage (NVS). When the halves lose their pairing (after a firmware swap, a
failed update, or corruption), the old bond data prevents re-pairing. The
settings-reset firmware wipes this storage so the halves can pair cleanly.

### When to use it

- After flashing the wrong firmware to a half (swapped left/right).
- When the halves won't pair despite repeated reset-press attempts.
- After major ZMK version upgrades that change the settings layout.
- As a first step when BLE behavior is erratic.

### How to use it

1. Flash `settings_reset_left.uf2` to the left half.
2. Flash `settings_reset_right.uf2` to the right half.
3. The settings-reset firmware runs `&sys_reset` on boot, which clears NVS and
   reboots. You may not see any LED activity — that's normal.
4. Re-flash both halves with the normal firmware
   (`corne_choc_pro_left.uf2` and `corne_choc_pro_right.uf2`).
5. Re-pair: single-press reset on both halves within 2-3 seconds.

### What it does under the hood

The settings-reset shield (from ZMK's `app/boards/shields/settings_reset/`)
does three things:

- Enables `CONFIG_ZMK_SETTINGS_RESET_ON_START=y` — clears settings on boot.
- Disables BLE (`CONFIG_ZMK_BLE=n`) — so the halves don't try to re-pair while
  the reset firmware is running.
- Disables the display (`CONFIG_ZMK_DISPLAY=n`) — the status screen depends on
  BLE, which is disabled.

The keymap is a single key that triggers `&sys_reset`. There is no user
interaction — flashing and booting the firmware is the entire action.

---

## Troubleshooting environment issues

This section covers problems with the build environment, not the keyboard
behavior. For keymap/behavior questions, see the
[ZMK docs](https://zmk.dev/docs) or the [ZMK Discord](https://zmk.dev/discord).

### `west: unknown command "build"`

The west workspace is incomplete — usually `zephyr/` was deleted or
`west update` never finished. Fix:

```bash
source .venv/bin/activate
west update
west zephyr-export
```

`build.sh` does this automatically on subsequent runs if it detects
`zephyr/scripts/west-commands.yml` is missing.

### `ModuleNotFoundError: No module named 'elftools'`

The venv is missing Zephyr's Python dependencies. Fix:

```bash
source .venv/bin/activate
pip install -r zephyr/scripts/requirements-base.txt
```

`build.sh` installs these on first run. If you deleted the venv or upgraded
Python, re-run the install.

### `ModuleNotFoundError: No module named 'pkg_resources'`

You're on Python 3.14+ with setuptools 81+, which removed `pkg_resources`.
The nanopb protoc wrapper needs it. Fix:

```bash
pip install "setuptools<81"
```

`build.sh` pins `setuptools<81` for this reason. If you manually upgraded
setuptools, downgrade it.

### `No board named 'corne_choc_pro_left' found`

Zephyr can't find the board definition. Two causes:

- **Local build:** `BOARD_ROOT` isn't pointing at the repo. `build.sh` passes
  `-DBOARD_ROOT=<repo>`. If you invoke `west build` manually, add that flag.
- **Cloud build:** `zephyr/module.yml` is missing or not committed. This file
  (with `board_root: .`) makes the ZMK workflow load the repo as a Zephyr
  module. Verify it's tracked: `git ls-files zephyr/module.yml`.

### Build fails after changing `config/west.yml`

The build directory caches the old ZMK/Zephyr revision. Clean it:

```bash
rm -rf build
./build.sh
```

If you changed the ZMK revision, also run `west update` to fetch the new
version before building.

### `The build directory must be cleaned pristinely when changing user ZMK config`

You changed `-DZMK_CONFIG` or the config directory without cleaning. Fix:

```bash
rm -rf build
```

Then rebuild. `build.sh` always does `rm -rf build` before each target, so
this only happens if you run `west build` manually.

### Cloud build fails but local build works

Check that `zephyr/module.yml` is committed (not just present locally):

```bash
git ls-files zephyr/module.yml
```

If empty, the file isn't tracked. The `.gitignore` must not exclude it. See
the commit history for the fix that resolved this — the fetched `zephyr/`
workspace is a nested git repo, so `git add` needs the file to exist outside
that nested repo (i.e. before `west update` creates `zephyr/.git`).

### Cloud build fails with `Failed to locate keymap file`

The `config/corne_choc_pro.keymap` file isn't committed. Verify:

```bash
git ls-files config/corne_choc_pro.keymap
```

### Git push fails with credential helper error

If you see `gh auth git-credential: not found`, the git credential helper
points to a stale `gh` path. Fix:

```bash
git config --global credential.helper \
  "!$(which gh) auth git-credential"
```

This updates the helper to the current `gh` location.

### Firmware built but keyboard doesn't work

This is a keyboard issue, not a build issue. Common causes:

- **Swapped firmware** — see [Diagnosing a swapped flash](#diagnosing-a-swapped-flash).
- **Halves not paired** — single-press reset on both within 2-3 seconds.
- **Stale BLE bonds** — flash the [settings-reset firmware](#the-settings-reset-firmware),
  then re-flash normal firmware and re-pair.
- **Peripheral connected to host via USB** — the right half only connects to
  the left via BLE. Power it via battery or USB power-only (no data).
