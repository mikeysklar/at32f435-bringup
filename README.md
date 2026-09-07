# AT-START-F435 bring-up plan: TinyUSB, CircuitPython, Zephyr

## Context

Board on the bench: Artery **AT-START-F435** dev kit, AT32F435ZMT7 (Cortex-M4F 288 MHz,
4032 KB flash, 384 KB SRAM, LQFP-144), with an onboard AT-Link-EZ debugger. It is the
same die as the AT32F435RMT7 (LQFP-64) that the `rmt7-board` KiCad design in this folder
targets, so everything proven here carries over to that board unchanged except pin tables.
Existing notes in `at32f35rmt7-lqfp64.md` already scoped the chip; this plan turns that
into tracked work against the user's GitHub forks, executed on bravo (the HIL host).

Goal: get TinyUSB, CircuitPython and Zephyr each to "USB CDC enumerates on the board",
with every step, finding and dead end recorded as an issue or PR so the history is
reconstructible.

## What research established (2026-09-06)

**TinyUSB** (hathach master `d9fa95d`): `hw/bsp/at32f435_437/boards/at_start_f435` exists,
`dwc2_at32.h` supports both OTG1 (`0x50000000`, PA11/12) and OTG2 (`0x40040000`, PB14/15).
BSP hard-codes `BOARD_TUD_RHPORT=1` (device on **OTG2 = CN3**), host on OTG1. Clock: 8 MHz
HEXT -> 288 MHz, USB 48 MHz = 288/6. Log UART = USART1 PA9 TX only. LED PD13, button PA0.
Vendor lib fetched by `tools/get_deps.py` into `hw/mcu/artery/at32f435_437` (BSD-3 repo,
pinned v2.2.0 `25439cc`). **`make flash` is broken**: target `flash-atlink` is undefined.
No open issues for F435. CircuitPython's pinned TinyUSB (`3daa5729f`, 2026-06-30) already
carries `dwc2_at32.h` and `OPT_MCU_AT32F435_437`.

**Zephyr**: nothing upstream (only AT32F405 PR #101409, open, stalled; Artery said on
2026-09-04 in #87602 they will re-propose). **ArteryTek/zephyr `artery-v1.1-branch`**
(v4.3.99 base, Apache-2.0, last commit 2026-02-28) has `soc/at/at32/at32f435_437`,
`boards/at/at_start_f435`, and uses upstream `udc_dwc2` with an `at,at32-otg-dwc2` quirk
block; `hal_at32` is a proper west module (Apache-2.0). CircuitPython's `zephyr-cp` pins
adafruit/zephyr at 4.4.99 (2026-08-25), so the fork's SoC code needs a rebase/port to
run under zephyr-cp.

**Tooling** (all unverified on hardware until the AT-Link enumerates):
- AT-Link-EZ = `2e3c:f000`, product string "CMSIS-DAP", HID (v1) + bulk (v2, interface 3)
  + CDC VCP on USART1 PA9/PA10 via jumper JP4 ("USART1" position).
- **probe-rs** has `AT32F435ZMT7` (since v0.21, current v0.32.0). Easiest flash path.
- **OpenOCD**: upstream master has `artery.c` but no F435 M-density and no release.
  ArteryTek/openocd fork has `target/at32f435xM.cfg` + `interface/atlink_dap_v2.cfg`.
- **pyOCD**: needs Artery's DFP pack, not in Keil index. Lowest priority.
- **ROM DFU** fallback: JP1 (BOOT0) to VDD, reset, `2e3c:df11` on **OTG1/CN2**, `dfu-util`
  works. Board can be powered from CN2/CN3 VBUS, but **AT-Link only powers from CN6**.
- LEDs PD13 red / PD14 yellow / PD15 green; button PA0; HEXT 8 MHz.

**bravo**: 4 cores, 11 GB RAM, 253 GB free, `gh` logged in as mikeysklar, ARM GCC at
`~/arm-toolchain/bin`, west 1.5.0 in `~/siwx917/.venv`, Zephyr SDK at
`~/siwx917/zephyr-sdk-1.0.1`, dfu-util 0.11, no probe-rs / pyocd. `~/circuitpython` has
local work on branch `stm32-dfu-remap`; build in worktrees.

**GitHub**: forks exist for circuitpython (issues on), zephyr (issues on), tinyusb
(issues **off**).

## Decisions and open questions

1. **Where issues live** (decided): one umbrella repo `mikeysklar/at32f435-bringup` for
   issues, labels, milestones, notes and scripts. Code lives on each fork: an `at32f435`
   integration branch plus **one topic branch per upstream-able change** (e.g.
   `tinyusb-rhport-override`, `tinyusb-flash-target`, `zephyr-at32-dwc2-quirk`), each
   PR'd into `at32f435`. Upstreaming later is one PR from the same topic branch to the
   real upstream. Local glue (bravo scripts, udev, experiments) stays in the umbrella
   repo. PRs reference issues cross-repo (`mikeysklar/at32f435-bringup#N`).
2. **USB port**: standardize on **OTG1 (CN2, PA11/PA12)** for device mode across all three
   stacks. Matches STM32F405 layout, the RMT7 board, and ROM DFU. TinyUSB BSP needs a
   `RHPORT_DEVICE`-style override (the at32f402_405 family already has one; copy it).
3. **Zephyr path**: run the ArteryTek fork as-is first for a smoke test (blinky + CDC),
   then port `soc/`, `dts/`, drivers and the dwc2 quirk header as an out-of-tree module
   against the adafruit/zephyr 4.4.99 that zephyr-cp uses. Not from scratch.
4. **CircuitPython path**: two candidates, do them in this order:
   - **zephyr-cp board** (`ports/zephyr-cp/boards/artery/at_start_f435`): once the
     Zephyr module works, this is a `.conf` + `.overlay` + `circuitpython.toml`.
   - **native `ports/artery`** using `ports/stm` as the template: the long-term target
     for the RMT7 board; supervisor + common-hal work, ~4-6 weeks. Start only after
     TinyUSB on the exact clock/flash config is proven.
5. **HAL license**: Artery repo LICENSE is BSD-3 but per-file headers say Artery-only.
   Track as an issue; ask Artery in writing before any upstream CP submission.

## Repo and tracking setup (first PR of the night)

- Create `mikeysklar/at32f435-bringup` (public) with: `README.md` (this plan), `docs/`
  (research summaries from today, copied from the three agent reports), `scripts/`
  (udev rules, flash helpers, bravo env setup), `.github/ISSUE_TEMPLATE/finding.md`.
- Labels: `stack:tinyusb`, `stack:circuitpython`, `stack:zephyr`, `area:tooling`,
  `area:hardware`, `type:blocker`, `type:finding`, `type:upstream-candidate`.
- Milestones: `M1 debug+flash`, `M2 tinyusb cdc`, `M3 zephyr cdc`, `M4 zephyr-cp board`,
  `M5 native cp port`.
- Branch `at32f435` on each fork (circuitpython, tinyusb, zephyr) from current upstream
  main; topic branches PR into it. Checkouts on bravo under `~/at32/`:
  `~/at32/tinyusb`, `~/at32/zephyr-ws` (west workspace), `~/at32/circuitpython`
  (git worktree of `~/circuitpython`).
- Every session ends with a `docs/log/YYYY-MM-DD.md` entry in the bring-up repo.

## Milestones and steps

### M1: talk to the chip (blocks everything)
1. **Needs the user**: plug **CN6 (AT-Link)** into bravo; keep CN2 (OTG1) plugged.
   Until then M1 steps 2-6 are blocked; repo/branch setup and toolchain installs are not. Record USB path,
   confirm `2e3c:f000`, check JP4 is on USART1 and JP1/JP2 (BOOT) are off.
2. udev rules for `2e3c:f000` (usb + hidraw) and `2e3c:df11` (DFU). Root step: attended.
3. Install probe-rs into `~/.local` (no sudo). `probe-rs info --chip AT32F435ZMT7`,
   then `probe-rs read` of 256 bytes at `0x08000000` and `0x1FFFF7E8` (UID) as the
   attach proof. Back up the factory demo flash image to `~/at32/backups/` before any write.
4. Build ArteryTek/openocd fork into `~/.local/openocd-at32` as second probe path
   (`interface/atlink_dap_v2.cfg` + `target/at32f435xM.cfg`). Compare both against the
   backup image.
5. Confirm the VCP tty by path (`/dev/serial/by-path/...`) and that the factory demo
   prints on it. Also try ROM DFU once (`dfu-util -l` shows `2e3c:df11`) so the recovery
   path is known-good before we need it.
6. Blinky from Artery's firmware library (PD13) flashed with probe-rs: proves toolchain,
   linker script `AT32F435xM_FLASH.ld`, startup and the 4 MB M-density flash algo.

### M2: TinyUSB CDC on OTG1
1. Worktree of tinyusb fork at branch `at32f435`; `python tools/get_deps.py at32f435_437`.
2. `make BOARD=at_start_f435 -C examples/device/cdc_msc` builds (ARM GCC from
   `~/arm-toolchain`). Flash via probe-rs, enumerate on CN3 first (stock OTG2) to get a
   known-good baseline.
3. PR: `family.mk`/`family.cmake` `RHPORT_DEVICE`/`RHPORT_HOST` overrides like
   `at32f402_405`; enumerate on **CN2/OTG1**.
4. PR: fix dangling `flash-atlink` target (add `flash-probers`/`flash-openocd` rules with
   the fork cfg). Both PRs are upstream candidates; tag them.
5. Run `cdc_msc`, `hid_composite`, `msc_dual_lun`; note anything failing as issues.
6. Optional: test the HICK+ACC crystal-less path that already exists in `family.c`
   (relevant to RMT7 board with DNP crystal). Finding issue either way.

### M3: Zephyr blinky + CDC
1. `west init -m https://github.com/ArteryTek/zephyr --mr artery-v1.1-branch
   ~/at32/zephyr-at32-ws`; `west build -b at_start_f435 samples/basic/blinky`, flash via
   probe-rs (the board.cmake expects pyocd/J-Link; add a probe-rs runner or flash the
   .hex by hand).
2. `samples/subsys/usb/cdc_acm` with `zephyr_udc0` = OTGFS1. Record whether the fork's
   dwc2 quirk block actually works on hardware (research says unknown).
3. Port: new module repo `mikeysklar/zephyr-at32-module` (or a dir in the bringup repo)
   holding `soc/artery/at32/`, `dts/arm/artery/`, bindings, drivers (clock, gpio, pinctrl,
   usart, flash, reset, exint), `udc_dwc2_at32_otgfs.h` quirk header, board
   `boards/artery/at_start_f435`, with `hal_at32` as a dependency. Vendor prefix `artery`,
   not `at` (upstream rejected `at`). Validate against **adafruit/zephyr @ 499310d**.
4. Rebase-related fixes to the Zephyr fork branch `at32f435` only if a core change is
   unavoidable; prefer keeping everything in the module.

### M4: CircuitPython via zephyr-cp
1. Add the module to `ports/zephyr-cp/zephyr-config/west.yml` on the circuitpython fork
   branch `at32f435`; add `boards/artery/at_start_f435/{circuitpython.toml, board.conf,
   board.overlay}` and `socs/at32f435zmt7.conf`; run the autogen board-info tooling.
2. `make BOARD=artery_at_start_f435` in `ports/zephyr-cp`; flash; REPL over CDC on CN2.
3. Storage: CIRCUITPY on internal flash via Zephyr flash driver (4 KB sectors on M density;
   ZW/NZW split, note in an issue).

### M5: native `ports/artery` (stretch, starts only after M2 is solid)
Skeleton from `ports/stm`: `Makefile`, linker script with ZW/NZW-aware layout,
`supervisor/port.c` (CRM to 288 MHz), `internal_flash.c`, `serial.c`, `usb.c` using the
in-tree `dwc2_at32.h`, pin tables generated per package (ZMT7 now, RMT7 later),
common-hal `microcontroller` + `digitalio` first. Each of those is its own PR.

## Working rules on bravo (from hil-farm)

- Resolve the board by USB path every time; never cache ttyACM numbers.
- `sudo` is attended: udev rule installs are batched into one message to the user.
- Back up flash before every first write to a new region; verify by md5 after.
- Build in worktrees, never in `~/circuitpython` directly.
- Every "it doesn't work" gets an issue with the exact command, output, and hypothesis
  before trying the next thing; every "it works" gets a log entry with the commit hash.

## Verification (per milestone exit)

- M1: `probe-rs info` prints the Cortex-M4 DPIDR and flash size; blinky toggles PD13;
  backup image md5 recorded in the bringup repo.
- M2: `lsusb` shows the TinyUSB CDC/MSC device on CN2's USB path; `cat` of the CDC echoes;
  MSC mounts. CI on the tinyusb fork builds `at_start_f435` green.
- M3: Zephyr `cdc_acm` sample enumerates on CN2 under the fork, then under the module on
  adafruit/zephyr 4.4.99.
- M4: `boot_out.txt` on a mounted CIRCUITPY names the board; REPL responds over CDC.
- Each milestone closes its GitHub milestone with all issues resolved or moved.
