#!/usr/bin/env bash
# Flashes WLED onto a plain ESP32 board, ready for Luma Flux.
#
# Downloads everything it needs, builds the partition table, and writes it all
# to the board. Run it with the ESP32 plugged into USB:
#
#   ./install.sh
#   ./install.sh --port /dev/cu.usbserial-10     # if it picks the wrong port
#
set -euo pipefail

WLED_VERSION="16.0.1"
BUILD_DIR="$(cd "$(dirname "$0")" && pwd)/build"

WLED_URL="https://github.com/wled/WLED/releases/download/v${WLED_VERSION}/WLED_${WLED_VERSION}_ESP32.bin"
INSTALLER_RAW="https://raw.githubusercontent.com/wled/WLED-WebInstaller/master/bin/boot"
BOOTLOADER_URL="${INSTALLER_RAW}/bootloaders/esp32/bootloader_esp32_8m.bin"
BOOT_APP0_URL="${INSTALLER_RAW}/boot_app0.bin"

PORT=""
[ "${1:-}" = "--port" ] && PORT="${2:-}"

bold(){ printf '\n\033[1m%s\033[0m\n' "$*"; }
warn(){ printf '\033[33m%s\033[0m\n' "$*"; }
die(){ printf '\n\033[31m%s\033[0m\n\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- tools ----
bold "Checking what's installed"

command -v python3 >/dev/null || die "python3 is missing. On macOS: brew install python3"
command -v curl    >/dev/null || die "curl is missing."

ESPTOOL=""
for c in esptool esptool.py; do command -v "$c" >/dev/null && { ESPTOOL="$c"; break; }; done
[ -n "$ESPTOOL" ] || die "esptool is missing. Install it with one of:
    brew install esptool
    pip3 install --user esptool"
echo "  python3, curl, $ESPTOOL — all present"

# ----------------------------------------------------------------- port ----
if [ -z "$PORT" ]; then
  bold "Looking for the board"
  PORTS=()
  for pat in /dev/cu.usbserial* /dev/cu.wchusbserial* /dev/cu.SLAB_USBtoUART* \
             /dev/ttyUSB* /dev/ttyACM*; do
    for p in $pat; do [ -e "$p" ] && PORTS+=("$p"); done
  done 2>/dev/null

  case "${#PORTS[@]}" in
    0) die "No board found.
Check that:
  - the ESP32 is plugged in,
  - the USB cable carries data (many charging cables do not),
  - the USB-to-serial driver is installed (CH340 or CP210x, depending on the board).";;
    1) PORT="${PORTS[0]}"; echo "  found: $PORT";;
    *) echo "  more than one board is connected:"
       i=1; for p in "${PORTS[@]}"; do echo "    $i) $p"; i=$((i+1)); done
       printf "\n  Which one? [1-%d] " "${#PORTS[@]}"; read -r pick
       PORT="${PORTS[$((pick-1))]:-}"
       [ -n "$PORT" ] || die "That wasn't one of the choices.";;
  esac
fi

bold "Identifying the chip"
"$ESPTOOL" --port "$PORT" flash-id 2>&1 | grep -E "Chip type|Detected flash size" | sed 's/^/  /' \
  || die "Could not talk to the board on $PORT.
Some boards need the BOOT button held down while this starts."

# ------------------------------------------------------------- download ----
bold "Fetching WLED $WLED_VERSION"
mkdir -p "$BUILD_DIR"

fetch(){  # url, destination, label
  if [ -s "$2" ]; then echo "  $3 — already downloaded"; return; fi
  printf '  %s — downloading… ' "$3"
  curl -fsSL -o "$2" "$1" || die "Download failed: $1"
  echo "$(( $(wc -c < "$2") / 1024 )) KB"
}

fetch "$WLED_URL"       "$BUILD_DIR/wled.bin"       "WLED firmware"
fetch "$BOOTLOADER_URL" "$BUILD_DIR/bootloader.bin" "bootloader"
fetch "$BOOT_APP0_URL"  "$BUILD_DIR/boot_app0.bin"  "boot selector"

printf '  partition table — building… '
"$(dirname "$0")/tools/make_partitions.py" "$BUILD_DIR/partitions.bin" >/dev/null
echo "$(( $(wc -c < "$BUILD_DIR/partitions.bin") / 1024 )) KB"

# ---------------------------------------------------------------- flash ----
bold "Ready to write to the board"
echo "  port: $PORT"
warn "  This erases everything on the ESP32, including any WiFi settings."
printf "\n  Type 'yes' to go ahead: "
read -r confirm
[ "$confirm" = "yes" ] || die "Nothing was written. Stopped at your request."

LOG="$BUILD_DIR/last-run.log"

bold "Erasing the board"
if "$ESPTOOL" --port "$PORT" --baud 460800 erase-flash >"$LOG" 2>&1; then
  echo "  done"
else
  cat "$LOG"; die "Erasing failed. The full output is above."
fi

# The WLED release image holds the application only, so it goes to 0x10000 with
# the bootloader and partition table written separately. Flashed to 0x0 instead,
# the board boot-loops with "invalid header".
# The 8 MB bootloader is correct here: esptool rewrites the flash-size field in
# its header to match --flash-size.
bold "Writing WLED — this takes about half a minute"
if "$ESPTOOL" --port "$PORT" --baud 460800 --chip esp32 write-flash -z \
  --flash-mode dio --flash-freq 40m --flash-size 4MB \
  0x1000  "$BUILD_DIR/bootloader.bin" \
  0x8000  "$BUILD_DIR/partitions.bin" \
  0xe000  "$BUILD_DIR/boot_app0.bin" \
  0x10000 "$BUILD_DIR/wled.bin" >>"$LOG" 2>&1
then
  echo "  bootloader, partition table, boot selector and WLED — written"
  verified=$(grep -c "Hash of data verified" "$LOG" || true)
  [ "$verified" -ge 4 ] || { cat "$LOG"; die "Only $verified of 4 parts verified. The full output is above."; }
  echo "  all four read back and verified"
else
  cat "$LOG"; die "Writing failed. The full output is above."
fi

bold "Done — WLED is on the board"
cat <<'NEXT'

  What happens next:

  1. The board is now broadcasting its own WiFi network, WLED-AP.
     Connect a phone to it. The password is  wled1234
  2. Open  http://4.3.2.1  and enter your home WiFi there. The board reboots
     and joins your network.
  3. Find the address it was given (your router's device list, or try
     http://wled.local ), then set up the strips and the interface:

         ./deploy.sh <that-address>

  If you don't know how many LEDs each strip has, that's fine — the interface
  has a "Measure strip lengths" mode that works it out for you.

NEXT
