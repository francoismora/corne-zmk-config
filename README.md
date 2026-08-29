# corne-zmk-config

ZMK firmware configuration for the **Keebart Corne Choc Pro** (nRF52840, 36-key
split). Slimmed down from [Keebart/zmk-config](https://github.com/Keebart/zmk-config)
to contain only this keyboard.

**New to this repo?** Read the [User Guide](GUIDE.md) — it covers configuring
layouts, building, flashing, the settings-reset firmware, and troubleshooting.

## What's here

```
corne-zmk-config/
├── config/
│   ├── west.yml              # pins ZMK to v0.3.0; bump revision to upgrade
│   ├── corne_choc_pro.conf    # your config overrides (Kconfig)
│   └── corne_choc_pro.keymap  # your keymap (overrides the board's default)
├── boards/
│   ├── arm/corne_choc_pro/    # board definition (pinout, matrix, defconfigs)
│   └── shields/nice_view_disp/# Keebart's custom nice!view display shield
├── zephyr/module.yml         # makes Zephyr find boards/ (for cloud builds)
├── build.yaml                # GitHub Actions build matrix
├── build.sh                  # local build script
└── .github/workflows/build.yml
```

The board and shield files are hardware definitions — you normally won't edit
them. Your customizations live in `config/corne_choc_pro.conf` and
`config/corne_choc_pro.keymap`.

## Build locally

Prerequisites (one-time, see the [ZMK native setup docs](https://zmk.dev/docs/development/local-toolchain/setup/native)):

- Zephyr SDK (e.g. `/opt/zephyr-sdk-0.17.0`) and `~/.zephyrrc` pointing at it
- `cmake`, `ninja-build`, `dfu-util`, `python3-venv`, `gcc-arm-none-eabi`

Then:

```bash
./build.sh
```

First run initializes the west workspace (fetches ZMK + Zephyr + modules).
Subsequent runs skip that. Output in the repo root:

| File | Goes to |
|------|---------|
| `corne_choc_pro_left.uf2` | LEFT half (central, connects to host) |
| `corne_choc_pro_right.uf2` | RIGHT half (peripheral, BLE to left) |
| `settings_reset_left.uf2` | LEFT half — clears bonded BLE state |
| `settings_reset_right.uf2` | RIGHT half — clears bonded BLE state |

### How the board is found

No symlink hack. Two mechanisms, one per build path:

- **Local** (`build.sh`): passes `-DBOARD_ROOT=<repo>` to `west build`, so
  Zephyr finds `<repo>/boards/` directly.
- **Cloud** (GitHub Actions): `zephyr/module.yml` (with `board_root: .`) makes
  the ZMK reusable workflow load the repo as a Zephyr extra module, so Zephyr
  finds `boards/` the same way.

## Build in the cloud (GitHub Actions)

Push to GitHub. `.github/workflows/build.yml` calls ZMK's reusable workflow at
the tag pinned in `config/west.yml`. Artifacts are downloadable from the Actions
run. No local toolchain needed.

## Upgrade ZMK

Edit `config/west.yml` and change `revision:`:

```yaml
projects:
  - name: zmk
    remote: zmkfirmware
    revision: v0.3.0   # <- bump this (tag, branch, or SHA)
    import: app/west.yml
```

Then:

```bash
source .venv/bin/activate
west update
```

Also bump the tag in `.github/workflows/build.yml` to match, so cloud builds use
the same ZMK version.

## Flash

1. Double-press reset on one half → it mounts as a `KEEBART` drive.
2. Copy the matching `.uf2` with `cp` (drag-and-drop is unreliable):
   ```bash
   cp corne_choc_pro_left.uf2 /run/media/francois/KEEBART/
   ```
3. Repeat for the right half with `corne_choc_pro_right.uf2`.
4. Re-pair halves: single-press reset on both within 2-3 seconds.

Never swap left/right firmware — each half has position-specific firmware.

## Customize

- **Keymap:** `config/corne_choc_pro.keymap` (overrides the board default).
- **Config options:** `config/corne_choc_pro.conf` (e.g. enable pointing,
  change idle timeout, rename keyboard).
- **Hardware/pinout:** `boards/arm/corne_choc_pro/` (normally leave alone).
