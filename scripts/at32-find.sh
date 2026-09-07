#!/usr/bin/env bash
# Locate the AT-Link-EZ (2e3c:f000) and the target's DFU (2e3c:df11) on the bus by
# sysfs path. Prints KEY=VALUE lines. Never cache the results across a replug.
for d in /sys/bus/usb/devices/*; do
  [ -f "$d/idVendor" ] || continue
  [ "$(cat "$d/idVendor")" = 2e3c ] || continue
  pid=$(cat "$d/idProduct"); path=$(basename "$d")
  case "$pid" in
    f000)
      echo "ATLINK_PATH=$path"
      echo "ATLINK_SERIAL=$(cat "$d/serial" 2>/dev/null)"
      echo "ATLINK_BCD=$(cat "$d/bcdDevice" 2>/dev/null)"
      for tty in "$d"/"$path":1.*/tty/tty*; do
        [ -e "$tty" ] && echo "ATLINK_TTY=/dev/$(basename "$tty")"
      done
      ;;
    df11) echo "DFU_PATH=$path" ;;
    *)    echo "OTHER_2E3C=$path pid=$pid product=$(cat "$d/product" 2>/dev/null)" ;;
  esac
done
