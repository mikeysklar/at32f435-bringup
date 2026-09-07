#!/usr/bin/env bash
# Flash an ELF/HEX/BIN to the AT32F435ZMT7 through the AT-Link-EZ with probe-rs.
# usage: at32-flash.sh <file.elf|.hex|.bin> [base-address-for-bin]
set -euo pipefail
export PATH=$HOME/.cargo/bin:$PATH
CHIP=${CHIP:-AT32F435ZMT7}
f=${1:?file}; base=${2:-0x08000000}
eval "$("$(dirname "$0")/at32-find.sh")"
: "${ATLINK_SERIAL:?AT-Link not on the bus}"
probe="2e3c:f000:${ATLINK_SERIAL}"
case "$f" in
  *.bin) probe-rs download --chip "$CHIP" --probe "$probe" --binary-format bin --base-address "$base" "$f" ;;
  # --binary-format defaults to "target", which for this chip means ELF, so an
  # Intel HEX file is parsed as ELF and rejected as "Unknown file magic".
  *.hex) probe-rs download --chip "$CHIP" --probe "$probe" --binary-format hex "$f" ;;
  *)     probe-rs download --chip "$CHIP" --probe "$probe" "$f" ;;
esac
probe-rs reset --chip "$CHIP" --probe "$probe"
