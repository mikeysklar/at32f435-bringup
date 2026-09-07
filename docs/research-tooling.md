# AT-START-F435 (AT32F435ZMT7) on Ubuntu 24.04: flash/debug and board facts (researched 2026-09-06)

Everything here is from documents and source; **nothing was verified on hardware yet**.

## Onboard AT-Link-EZ

- **USB ID `2e3c:f000`, product string "CMSIS-DAP"** (`lsusb`: `ID 2e3c:f000 Artery
  Technology CMSIS-DAP`). Same VID:PID is in the ArteryTek OpenOCD fork's
  `contrib/60-openocd.rules` ("# Artery ATLINK").
- Composite device: HID (CMSIS-DAP v1) + WinUSB bulk (CMSIS-DAP v2, "V2 and above
  firmware") + CDC ("ATLink-USART" VCP, plus "ATLink-Bridge"). UM0004 §3.1/3.2. The fork
  ships `interface/atlink.cfg` (`cmsis_dap_backend hid`) and `interface/atlink_dap_v2.cfg`
  (`cmsis_dap_backend usb_bulk`, `cmsis_dap_usb interface 3`), so bulk is interface 3.
- VCP is wired to target **USART1 PA9/PA10** through jumper **JP4** (UM_AT_START_F435
  §3.3; JP4 must be on "USART1", its other position routes PA9/PA10 to OTG1 VBUS/ID).
- Product string is literally "CMSIS-DAP", so stock OpenOCD, pyOCD and probe-rs should
  all enumerate it. No Linux user report found for pyOCD/probe-rs specifically.
- udev: see `scripts/99-at32.rules`.

## Board layout (UM_AT_START_F435 Rev 1.00, 2021-11-20)

- MCU: AT32F435ZMT7, LQFP144, **4032 KB flash, 384 KB SRAM**; 16 MB EN25QH128A on QSPI1
  (PF6-10, PG6).
- **CN2 = OTGFS1 (PA11/PA12)**, **CN3 = OTGFS2 (PB14/PB15)**, both micro-B; CN1 type-A =
  OTGFS1 host. R54/R55 (PA11/12) and R42/R53 (PB14/15) default OFF, i.e. those pins are
  not on the J1 headers.
- **VBUS1/VBUS2 from CN2/CN3 can power the whole board** (§3.1, §3.8) but "any other
  method cannot power the AT-Link-EZ"; AT-Link only powers from its own **CN6**.
- LED2 red **PD13**, LED3 yellow **PD14**, LED4 green **PD15**; LED1 = 3.3 V power.
- User button B2: **PA0** (R19 ON/R21 OFF, default) or PC13. Reset B1 on NRST.
- HEXT **8 MHz** (R1,R3 ON), LEXT 32.768 kHz.
- BOOT0 = **JP1** (pulled down internally; OFF or GND = flash), BOOT1 = JP2.
  JP1 -> VDD, JP2 -> GND = system memory bootloader.
- JP3/R17 = IDD measurement. No AT-Link isolation jumper: the AT-Link-EZ is separated by
  snapping the PCB at the score line; CN4/CN7 (unpopulated) reconnect it. 20-pin JTAG/SWD
  header J1 for external probes.

## OpenOCD

- **Upstream**: `src/flash/nor/artery.c` + `tcl/target/artery/at32f4x.cfg` landed
  2025-08-09 (commit ef188a30ac, Marc Schink). Latest tag is still **v0.12.0**; only git
  master has it. Docs: "Devices with dual-bank flash memory are currently not supported".
  The F435 part table has only C/D densities; **AT32F435ZMT7 is absent**. Not usable here.
- **ArteryTek/openocd fork** (0.11.0+dev, last commit 2025-11-14): driver `at32f435xx` in
  `src/flash/nor/at32f4xx.c`, configs `target/at32f435xM.cfg` (two banks: 0x08000000 2 MB
  + 0x08200000 remainder), `at32f435xM_qspi.cfg`, `interface/atlink.cfg`,
  `atlink_dap_v2.cfg`. Build: `./bootstrap && ./configure --enable-cmsis-dap
  --enable-cmsis-dap-v2 && make`. Artery also ships binaries
  (`OpenOCD_Linux_x86-64_V2.1.0.zip`, AUR `at32-openocd-bin`), and PlatformIO's
  `amoxu/tool-openocd-at32`.
- **Use the fork**: `openocd -f interface/atlink_dap_v2.cfg -f target/at32f435xM.cfg`.

## probe-rs

- `probe-rs/targets/AT32F4_Series.yaml` has **`AT32F435ZMT7`** (flash
  0x08000000-0x083F0000, RAM 0x20000000-0x20060000, algos `at32f435_4032`,
  `at32f435_usd_4096`). Added in PR #1759 (v0.21.0); flash fix PR #2561 (v0.24+). Current
  release v0.32.0 (2026-07-22).
- `probe-rs run --chip AT32F435ZMT7 ...`; works with any CMSIS-DAP probe. Installed on
  bravo at `~/.cargo/bin/probe-rs` (0.32.0).

## pyOCD

- No built-in AT32 targets (v0.45.1). Needs **`ArteryTek.AT32F435_437_DFP`** (2.0.8),
  **not in the Keil pack index**, so `pyocd pack install` won't find it; download the
  `.pack` from Artery's site and use `--pack ... --target at32f435zmt7`. Lowest priority.

## ROM bootloader

- Enter: JP1 (BOOT0) to VDD, JP2 (BOOT1) to GND, reset. Interfaces (UM0006 table 6):
  USART1 PA9/PA10, USART2 PD5/PD6, USART3 PC10/PC11, **DFU1 = PA11/PA12 (CN2)**,
  **DFU2 = PB14/PB15 (CN3)**.
- DFU enumerates as **`2e3c:df11` "Artery-Tech DFU in FS Mode"**; dfu-util works:
  `dfu-util -a 0 -d 2e3c:df11 --dfuse-address 0x08000000 -D fw.bin`.
- Artery Linux tools: `Artery_ISP_Console_Linux-x86_64_V3.0.23.zip` (UART + DFU) and
  `Artery_ATLINK_Console_Linux-x86_64_V3.0.20.zip` (SWD via AT-Link), both under
  arterytek.com/download/Program and Debug/.

## Linux gotchas

- Permissions: udev rules; Artery's own console tools document `sudo`.
- AT-Link firmware upgrade is done by the **Windows ICP tool**. V1 firmware = HID only;
  DAP-v2 bulk requires V2+. No Linux updater found.
- Unverified: whether the fork's `cmsis_dap_usb interface 3` is needed with stock OpenOCD
  auto-detection; whether pyOCD/probe-rs flash the 2nd bank (>2 MB) correctly; SWO.

## Sources

- UM_AT_START_F435 V1.00: https://cdn.promelec.ru/upload/items/2022/10/03/UM_AT_START_F435_EN_V1.00.pdf
- UM0004 AT-Link manual: https://arterychip.com/download/TOOL/UM0004_AT-Link_User_Manual_EN_V2.1.2.pdf
- UM0006 ISP Console: https://www.arterytek.com/file/download/1768 ; UM0007 AT-Link Console: https://www.arterychip.com/file/download/1758
- ArteryTek/openocd: https://github.com/ArteryTek/openocd ; PIO binaries: https://github.com/amoxu/tool-openocd-at32
- Upstream artery.c: https://www.mail-archive.com/openocd-devel@lists.sourceforge.net/msg17098.html
- probe-rs targets: https://github.com/probe-rs/probe-rs/blob/master/probe-rs/targets/AT32F4_Series.yaml (PRs #1759, #2561)
- DFU: https://github.com/koendv/at32f405-uf2boot ; https://github.com/qmk/qmk_firmware/pull/24747
- SEGGER KB: https://kb.segger.com/ArteryTek_AT-START-F435
