# Files the AT32 Zephyr module must carry (from ArteryTek/zephyr artery-v1.1-branch @ 456548bdfa9)

Scope: only what `at_start_f435` needs. Other AT32 series and boards are left out.

## Board
- `boards/at/at_start_f435/` (9 files: Kconfig.*, `-pinctrl.dtsi`, `.dts`, `.yaml`,
  `_defconfig`, `board.cmake`, `board.yml`, `doc/index.rst`) -> `boards/artery/at_start_f435/`

## SoC
- `soc/at/at32/{CMakeLists.txt,Kconfig,Kconfig.defconfig,Kconfig.soc,soc.yml}`
- `soc/at/at32/at32f435_437/{CMakeLists.txt,Kconfig*,at32_regs.h,linker.xx,soc.c,soc.h}`
- `soc/at/at32/common/{CMakeLists.txt,pinctrl_soc.h}`
- `modules/hal_at32/{CMakeLists.txt,Kconfig}` (glue for the hal_at32 west module)

## Devicetree
- `dts/arm/at/at32f435_437/at32f435_437.dtsi`, `at32f435xmt7.dtsi`, `at32f435zmt7.dtsi`
- `include/zephyr/dt-bindings/clock/at32f435_437_clocks.h`,
  `include/zephyr/dt-bindings/reset/at32f435_437_reset.h`, `dma/at32_dma.h`
- Bindings (`dts/bindings/*/at,at32-*.yaml`), rename `at,` -> `artery,`:
  clock (cctl, crm, hext, pll, pll-mul), flash_controller, gpio (+iomux),
  interrupt-controller (exint), misc (syscfg), mtd (nv-flash), pinctrl (common, iomap,
  mux), reset (rctl), serial (usart), usb (otg-dwc2), timer, pwm, adc, dma, i2c, spi,
  i2s, watchdog, can as needed.

## Drivers (minimum for blinky + console + CDC)
- `drivers/clock_control/{Kconfig.at32,clock_control_at32.c}` +
  `include/zephyr/drivers/clock_control/at32_clock_control.h`
- `drivers/gpio/{Kconfig.at32,gpio_at32.c}`
- `drivers/pinctrl/{Kconfig.at32,pinctrl_at32_iomap.c,pinctrl_at32_mux.c}`
- `drivers/reset/{Kconfig.at32,reset_at32.c}`
- `drivers/interrupt_controller/{Kconfig.at32,intc_exint_at32.c}` +
  `include/zephyr/drivers/interrupt_controller/intc_at32.h`
- `drivers/serial/{Kconfig.at32,usart_at32.c}`
- `drivers/flash/{Kconfig.at32,flash_at32.c,flash_at32.h,flash_at32_v1.c}` (CIRCUITPY)
- USB: F435 uses upstream `udc_dwc2`; the fork's quirk block lives at
  `drivers/usb/udc/udc_dwc2_vendor_quirks.h:718` (`at_at32_otg_dwc2`: clock on via
  CCTL, GGPIO PWRDWN|VBDEN, caps hook). Upstream 4.4 split quirks into per-vendor
  headers, so this becomes `udc_dwc2_at32_otgfs.h` in the module (or a small upstream
  patch on the zephyr fork branch `at32f435` if the include list is not extensible).
- Later: adc, pwm, i2c, spi, dma, counter, watchdog, i2s, can.

## Out of scope (fork touches them but a module must not)
`cmake/*`, `scripts/*`, `arch/*` changes in the fork: 5219 files differ from v4.3.0
because the base is main after 4.3.0, not the tag; the AT32-specific delta is the list
above.

## hal_at32 (west module, Apache-2.0)
`modules/hal/at32`: `at32f435_437/` (Artery std periph lib), `common_include/`,
`common_source/` (incl. `at32_hal_udc.c`, not needed for dwc2 parts), `zephyr/module.yml`
(cmake-ext, kconfig-ext, `dts_root: .`). 5.7 MB.
