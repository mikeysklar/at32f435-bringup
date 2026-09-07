#!/usr/bin/env bash
# Dump the whole 4032 KB internal flash + UID before the first write. Records md5.
set -euo pipefail
export PATH=$HOME/.cargo/bin:$PATH
CHIP=${CHIP:-AT32F435ZMT7}
FLASH_BYTES=$((4032 * 1024))
out=${1:-$HOME/at32/backups/flash-$(date +%Y%m%d-%H%M%S).bin}
eval "$("$(dirname "$0")/at32-find.sh")"
: "${ATLINK_SERIAL:?AT-Link not on the bus}"
probe="2e3c:f000:${ATLINK_SERIAL}"
probe-rs read --chip "$CHIP" --probe "$probe" b32 0x1FFFF7E8 3 | tee "${out%.bin}.uid.txt"
# --output is written in --format, which defaults to hex-table. Without
# "--format binary" the file is an ASCII dump that cannot be flashed back.
probe-rs read --chip "$CHIP" --probe "$probe" --format binary b8 0x08000000 "$FLASH_BYTES" --output "$out"
got=$(stat -c %s "$out")
[ "$got" -eq "$FLASH_BYTES" ] || { echo "$out is $got bytes, expected $FLASH_BYTES" >&2; exit 1; }
ls -la "$out" "${out%.bin}".* 2>/dev/null
md5sum "$out" 2>/dev/null | tee "${out%.bin}.md5"
