# TinyUSB + AT32F435/437 (hathach master `d9fa95d`, researched 2026-09-06)

## BSP `hw/bsp/at32f435_437/`

Boards: `at_start_f435` (AT32F435ZMT7, linker `AT32F435xM`), `at_start_f437`. Files:
`family.c/.mk/.cmake`, `at32f435_437_clock.c/.h`, `_conf.h`, `_int.c/.h`, `FreeRTOSConfig/`.

- **OTG usage**: both OTG cores are clocked and both pin pairs are muxed
  (`usb_gpio_config`: PA11/PA12 MUX10 = OTG1, PB14/PB15 MUX12 = OTG2). `family.mk` /
  `family.cmake` hardcode `BOARD_TUD_RHPORT=1` (device on **OTG2, PB14/PB15 = CN3**) and
  `BOARD_TUH_RHPORT=0` (host on **OTG1, PA11/PA12 = CN2**), both `OPT_MODE_FULL_SPEED`.
  Not configurable via make variables (unlike `at32f402_405/family.mk`, which has
  `RHPORT_DEVICE` / `RHPORT_HOST` overrides).
- **Clocks** (`at32f435_437_clock.c`): HEXT = 8 MHz (`HEXT_VALUE` in `_conf.h`),
  PLL ns=144 / ms=1 / fr=4 -> **SCLK 288 MHz**, AHB /1, APB1/APB2 /2 = 144 MHz, LDO 1.3 V,
  flash div 3. USB 48 MHz: `usb_clock48m_select(USB_CLK_HEXT)` ->
  `crm_usb_clock_div_set(CRM_USB_DIV_6)` (288/6). The HICK+ACC auto-trim path exists in
  `family.c` but is not selected.
- **VBUS**: `board_vbus_sense_init()` in `board.h` pokes bit 21 of `0x50000038` and
  `0x40040038` (GCCFG of OTG1/OTG2, "vbus ignore") with raw magic addresses.
- **UART**: USART1 TX on **PA9** (MUX7), 115200, TX only; `board_uart_read` returns 0.
- **LED** PD13 active-low (also sets PD14/PD15 high); **button** PA0 active-high, pull-down.
- IRQs: `OTGFS1_IRQHandler` -> `tusb_int_handler(0)`, `OTGFS2_IRQHandler` ->
  `tusb_int_handler(1)`, plus WKUP variants. `board_get_unique_id` reads 12 bytes at
  `0x1FFFF7E8`.

## Vendor library

Not a git submodule; fetched by `tools/get_deps.py` into `hw/mcu/artery/at32f435_437`
from `https://github.com/ArteryTek/AT32F435_437_Firmware_Library.git`, pinned commit
`25439cc6650a8ae0345934e8707a5f38c7ae41f8` = "update version to v2.2.0" (2024-08-27).
Upstream master is v2.2.5 (2026-07-16). GitHub reports the repo license as BSD-3-Clause
(`LICENSE` at root); the BSP's `_clock.c` / `_int.c` copied into tinyusb carry Artery's
own "use with Artery MCUs" copyright notice, not MIT. CMSIS core,
`system_at32f435_437.c`, `startup_at32f435_437.s` and `AT32F435xM_FLASH.ld` all come from
the library (`libraries/cmsis/cm4/device_support/startup/gcc/...`); nothing vendored in
tinyusb since commit `b67e0089` (2025-07-31).

## `src/portable/synopsys/dwc2/dwc2_at32.h`

Selected via `TUP_USBIP_DWC2_AT32` in `src/common/tusb_mcu.h` (`TUP_DCD_ENDPOINT_MAX 8`
for F435). For F435_437: OTG1 base `0x50000000` / `OTGFS1_IRQn`, OTG2 base `0x40040000` /
`OTGFS2_IRQn`, both 320-word FIFOs; two-entry `_dwc2_controller[]` so **both OTG1 and
OTG2 are supported**. `dwc2_clock_init` is empty (BSP enables clocks). `dwc2_int_set` is
plain NVIC enable/disable. `dwc2_phy_init` is a no-op; `dwc2_phy_update` sets
`stm32_gccfg |= PWRDWN|DCDEN|PDEN` (reusing STM32 bit names); `dwc2_phy_deinit` clears
them. F405: OTG2 = `OTGHS_IRQn`, 1024-word FIFO, `TUP_RHPORT_HIGHSPEED 1` only for the
AT32F405xx part numbers listed in `tusb_mcu.h`; `dwc2_common.c` forces 8-bit UTMI width
for F402_405. `hw/mcu` header is `<at32f435_437.h>`.

History: added in PR #3163 (author zhiqiang, `zhiqiangyou@arterytek.com`; merged
2025-08-01 via #3191); prior attempts #2933 (ArteryTek org, Jan 2025, closed) and #2839
(@rhgndf, F403A). First release: **0.19.0 (2025-10-06)**. Later: #3236 (dual-OTG rework,
`at_start_f435` board split, 2025-09-05), #3247 (compile fix), #3292 (fsdev IRQ remap,
0.20.0), #3442 (F45x, 0.21.0), #3476 (DWC2 VBUS sensing).

## CI

`.github/scripts/ci_set_matrix.py`: `at32f435_437: ["arm-gcc"]` only. GitHub Actions
cmake builds one board per family (first alphabetically = `at_start_f435`); CircleCI does
the full set. No `skip.txt` mentions at32, so all **device** examples build. **Host**:
only `examples/host/audio_host/only.txt` lists `family:at32f435_437`. **Dual**: none.
Not in HIL (`test/hil/*.json`: 0 hits).

## Issues / PRs

No open issues or PRs mention AT32F435/437. AT32-related closed issues are all F405:
#3198 (HS not enumerating, missing `TUP_RHPORT_HIGHSPEED`, fixed) and #3315 (stuck
suspended from a spurious suspend IRQ at init, fixed by `80309e4d`). DWC2 DMA defaults
off (`CFG_TUD_DWC2_DMA_ENABLE_DEFAULT 0`). Field reports for F435 specifically: unknown.

## Flashing

`family.mk`: `flash: flash-atlink`, but **no `flash-atlink` rule exists anywhere**
(`hw/bsp/family_rules.mk` defines jlink/stlink/pyocd/openocd/... only), so `make flash`
fails; same dangling target in all 8 at32 families. CMake path calls `family_flash_jlink`
with `JLINK_DEVICE=AT32F435ZMT7`. No openocd cfg.

## Context on other Artery parts

Support was contributed by Artery employees (`@arterytek.com`). Families: F402_405
(dwc2, F405 HS), F403A_407/F413 (`stm32_fsdev` variant, 768 B PMA per #3757),
F415/F423/F425/F45x (dwc2). README table: F435_437 device+host, no HS. The at32 BSPs
derive from Artery's own USB examples (`_int.c` still says "437_USB_device_msc").

## Sources

- https://github.com/hathach/tinyusb (`hw/bsp/at32f435_437/*`,
  `src/portable/synopsys/dwc2/dwc2_at32.h`, `src/common/tusb_mcu.h`, `tools/get_deps.py`,
  `.github/scripts/ci_set_matrix.py`, `hw/bsp/family_rules.mk`, `docs/changelog/0.19.0.md`)
- PRs #3163 #3191 #3236 #3247 #3292 #3442 #3476 #2933 #2839 #3757; issues #3198 #3315
- https://github.com/ArteryTek/AT32F435_437_Firmware_Library (commit 25439cc6, LICENSE)
