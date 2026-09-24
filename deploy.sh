#!/usr/bin/env bash
# Uploads the Luma Flux interface and configures the strips.
#
#   ./deploy.sh <lamp-address>                       # interface + segments for current outputs
#   ./deploy.sh <lamp-address> ui                    # interface only
#   ./deploy.sh <lamp-address> leds 144 60 90 30 20  # new strip lengths (one number per strip)
#   ./deploy.sh <lamp-address> sync                  # rebuild segments for current outputs
#   ./deploy.sh <lamp-address> check                 # report only
#
# Set strip lengths HERE, not in the WLED panel. A change there moves only the
# outputs; the segment bounds stay frozen in the boot preset and the strips
# start overlapping. If that happens, 'sync' repairs it.
set -euo pipefail

HOST="${1:-}"
WHAT="${2:-all}"
[ -n "$HOST" ] || { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
shift 2 2>/dev/null || shift 1 2>/dev/null || true

cd "$(dirname "$0")"
say(){ printf '\n\033[1m%s\033[0m\n' "$*"; }

upload_ui(){
  say "Uploading the interface ($(( $(wc -c < index.htm) / 1024 )) KB) to the ESP32"
  curl -fsS -m 60 -F "data=@index.htm;filename=/index.htm" "http://$HOST/upload" && echo " -> uploaded"
}

case "$WHAT" in
  ui)    upload_ui ;;
  leds)  say "Configuring strips"; ./configure.py "$HOST" set "$@" ;;
  sync)  ./configure.py "$HOST" sync ;;
  check) ./configure.py "$HOST" check ;;
  all)   upload_ui; say "Checking outputs against segments"; ./configure.py "$HOST" sync ;;
  *)     echo "Unknown mode: $WHAT"; exit 1 ;;
esac

if [ "$WHAT" = "ui" ] || [ "$WHAT" = "all" ]; then
  say "Lamp: http://$HOST"
  echo "WLED panel: http://$HOST/settings   Files: http://$HOST/edit"
fi
