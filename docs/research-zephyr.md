# Zephyr on Artery AT32F435/437 and AT-START-F435 (researched 2026-09-06)

## Upstream zephyrproject-rtos/zephyr

**Nothing merged.** `soc/artery`, `dts/arm/artery`, `boards/artery`, `modules/hal_at32`
all absent on `main`; `west.yml` has no `hal_at32`.

All upstream activity is one person, **Maxjta** (Jun Tan, Artery engineer), all for
**AT32F405**, none for F435:

| Item | Date | Status |
|---|---|---|
| PR #86694 "Add Support Artery AT32F405" | 2025-03-06 | closed 2025-06-09 (superseded) |
| Issue #87602 "Add Support for ArteryTek SoC's HAL driver" (module RFC) | 2025-03-25 | **open**; reopened 2026-09-04 by martinjaeger after Artery's official account jalyli2027 committed vendor engineering resources and offered a fresh RFC "based on the current Zephyr Hardware Model" |
| PR #91273 | 2025-06-09 | closed 2025-12-22 (branch lost in fork sync) |
| PR #101403 | 2025-12-22 | closed same day (duplicate) |
| PR #101409 (current) | 2025-12-22 | **open**, CHANGES_REQUESTED (nordicjm), last commits 2026-05-20, reopened 2026-09-04, "needs a rebase" |

PR #101409 scope: `soc/artery/at32/at32f402_405`, `boards/artery/at_start_f405`, drivers
clock/gpio/pinctrl/reset/exint/usart, `west.yml` pointing at `Maxjta/hal_at32`. No flash,
no USB, no F435. HAL license blockers (custom Artery header, bundled CMSIS) were resolved
Sept 2025; TSC never acted, so it stalled.

## ArteryTek's fork and hal_at32

- https://github.com/ArteryTek/zephyr, default branch `artery-v1.1-branch`, Apache-2.0.
  Merge-base with upstream is `8aaa5031f` (2025-12-01), i.e. **v4.3.0 + a few days**
  (VERSION says 4.3.99). 77 commits on top; last 2026-02-28. `developer` branch is older
  (v4.1 base, Nov 2025).
- https://github.com/ArteryTek/hal_at32 (also `Maxjta/hal_at32`). LICENSE = Apache-2.0;
  driver files carry `Copyright (c) 2025, Artery Technology` + `SPDX-License-Identifier:
  Apache-2.0`. Last commit 2026-01-22 (adds AT32F45x). Contains Artery's standard periph
  library per series plus a Zephyr-specific `common_source/at32_hal_udc.c` and
  `zephyr/module.yml` (cmake-ext/kconfig-ext, `dts_root: .`): a proper west module.
- **west manifest: yes.** Fork `west.yml` adds remote `ArteryTek` and project `hal_at32`
  at `c6b6c1dad4` (2025-12-02), path `modules/hal/at32`.
  `west init -m https://github.com/ArteryTek/zephyr --mr artery-v1.1-branch` works as-is.
- SoC series (`soc/at/at32/soc.yml`): at32f402_405, at32f423, **at32f435_437**,
  at32f403a_407, at32f45x. Boards under `boards/at/`: at_start_f403a / f405 / f407 / f423
  / **f435** / f437 / f455 / f456 / f457.
- `boards/at/at_start_f435`: board.cmake uses pyocd (`--target=AT32F435ZMT7`) and J-Link;
  console on usart1; LEDs PD13/14/15; `zephyr_udc0: &usbotg_fs` enabled with pinctrl;
  defconfig sets `CONFIG_USB_DEVICE_VID=0x2E3C`. Doc index is copy-pasted from F405 (says
  "AT-START-F437") and `at_start_f435.yaml` lists only `gpio` as supported.
- AT32 drivers in fork: clock_control, gpio, pinctrl (iomap + mux variants), reset, exint,
  usart, **flash (`flash_at32.c`, `flash_at32_v1.c`)**, adc, dma, i2c, i2s, spi, pwm,
  counter/timer, can (bxcan), watchdog, plus two USB paths:
  - `drivers/usb/udc/udc_at32.c` (1214 lines) and legacy `usb_dc_at32.c`: wrap
    `at32_hal_udc.c`, used for compat `at,at32-usb` (**F403A/407 only**).
  - **F435/437, F405, F423, F45x use upstream `udc_dwc2`**: dtsi node is
    `compatible = "at,at32-otg-dwc2","snps,dwc2"` (OTGFS1 @0x50000000, OTGFS2
    @0x40040000, 8 IN/8 OUT EPs, ghwcfg2 = 0x228FDD00) and the fork appends an
    `at_at32_otg_dwc2` section (~83 lines) to the then-monolithic
    `udc_dwc2_vendor_quirks.h`: clock on via AT32 CCTL, set STM32-style
    `GGPIO PWRDWN|VBDEN`, `caps` hook for HS PHY. Whether CDC on F435 was
    hardware-tested: unknown.

## Community ports outside ArteryTek

None found. Searches return only ChibiOS-Contrib, rusEFI, tinyusb, QMK, rt-thread
(koendv/at32f435-board). The only outside participants are testers on #87602/#101409.

## Upstream udc_dwc2 vendor quirk hooks

`drivers/usb/udc/udc_dwc2.h` defines `struct dwc2_vendor_quirks` (init, pre_enable,
post_enable, disable, shutdown, irq_clear, caps, is_phy_clk_off, post/pre hibernation)
and includes one per-vendor header under `#if DT_HAS_COMPAT_STATUS_OKAY(<vendor compat>)`;
`UDC_DWC2_VENDOR_QUIRK_GET(n)` picks `dwc2_vendor_quirks_##n` when the node has a second
vendor compat. Reference to clone: `udc_dwc2_stm32f4_fsotg.h` (~100 lines, binding
`st,stm32f4-fsotg.yaml` includes `snps,dwc2.yaml`). Upstream since 4.3 split the quirk
file into per-vendor headers and switched to `dwc2_get_base(dev)`, so Artery's quirk
block needs a ~10-line rewrite into `udc_dwc2_at32_otgfs.h`. `Kconfig.dwc2` has no
vendor gating to touch.

## Assessment: blinky + console + USB CDC on AT-START-F435

Needed: SoC init (SystemInit from HAL), CRM clock driver, GPIO, pinctrl, USART, flash
(optional), dwc2 quirk + dts node, board files, probe runner. Every piece exists in the fork.

- **(a) Fork as-is**: fastest, days. Frozen at v4.3-era Zephyr, vendor prefix `at,` and
  `boards/at/` layout that upstream already rejected (renamed to `artery`), `linker.xx`
  hacks, thin docs. Fine for a prototype.
- **(b) Out-of-tree module against upstream main**: realistic, ~1-2 weeks. Lift `soc/`,
  `dts/`, bindings, drivers, and `hal_at32` into a module repo, rename `at,` -> `artery,`,
  rebase drivers on current APIs, port the quirk block into a per-vendor header. Also the
  shape Artery said (2026-09-04) it wants to re-propose.
- **(c) From scratch on STM32F4 SoC support**: not worth it; CRM, IOMUX, flash register
  maps differ from STM32.

Recommendation: (a) for a smoke test, then (b) starting from `artery-v1.1-branch` +
`hal_at32@c6b6c1d`; watch #87602 for the new vendor RFC.

## Sources

- https://github.com/zephyrproject-rtos/zephyr/issues/87602
- https://github.com/zephyrproject-rtos/zephyr/pull/101409 (also #91273, #86694, #101403)
- https://github.com/ArteryTek/zephyr/tree/artery-v1.1-branch
- https://github.com/ArteryTek/hal_at32 , https://github.com/Maxjta/hal_at32
- https://github.com/zephyrproject-rtos/zephyr/blob/main/drivers/usb/udc/udc_dwc2.h
- https://github.com/zephyrproject-rtos/zephyr/blob/main/drivers/usb/udc/udc_dwc2_stm32f4_fsotg.h
- https://github.com/koendv/at32f435-board (rt-thread), https://github.com/dron0gus/artery (ChibiOS)
