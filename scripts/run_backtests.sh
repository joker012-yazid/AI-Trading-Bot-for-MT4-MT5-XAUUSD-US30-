#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEMPLATE="$ROOT_DIR/botdata/tester/mt5_tester.tpl.ini"
SECRETS_FILE="$ROOT_DIR/botdata/tester/secrets.env"
PRESET_DIR="$ROOT_DIR/botdata/presets"
REPORT_DIR="$ROOT_DIR/botdata/reports"
LOG_PATH="$ROOT_DIR/botdata/logs/trade_log.csv"
MT5_TERMINAL=${MT5_TERMINAL:-/opt/mt5/terminal64.exe}
PRESETS=(
  "XAUUSD_M15_Conservative.set"
  "US30_M15_Conservative.set"
  "XAUUSD_M15_Reserve.set"
  "US30_M15_Reserve.set"
)

if [[ ! -f "$TEMPLATE" ]]; then
  echo "[ERROR] Template not found: $TEMPLATE" >&2
  exit 1
fi

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "[ERROR] Secrets file not found: $SECRETS_FILE" >&2
  exit 1
fi

chmod 600 "$SECRETS_FILE"

set -a
# shellcheck disable=SC1090
source "$SECRETS_FILE"
set +a

for var in MT5_LOGIN MT5_PASSWORD MT5_SERVER; do
  if [[ -z "${!var:-}" ]]; then
    echo "[ERROR] Missing required variable: $var" >&2
    exit 1
  fi
done

if [[ ! -f "$MT5_TERMINAL" ]]; then
  echo "[ERROR] terminal64.exe not found at $MT5_TERMINAL" >&2
  exit 1
fi

mkdir -p "$REPORT_DIR"

TMP_DIR=$(mktemp -d)
XVFB_PID=""

cleanup() {
  if [[ -n "$XVFB_PID" ]]; then
    kill "$XVFB_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

XVFB_DISPLAY=:99
export DISPLAY=$XVFB_DISPLAY

Xvfb $XVFB_DISPLAY -screen 0 1280x720x24 > /dev/null 2>&1 &
XVFB_PID=$!

run_backtest() {
  local preset_name="$1"
  local preset_path="$PRESET_DIR/$preset_name"
  if [[ ! -f "$preset_path" ]]; then
    echo "[WARN] Preset missing, skipping: $preset_name" >&2
    return 1
  fi

  local symbol
  symbol="${preset_name%%_*}"

  local report_path="$REPORT_DIR/${preset_name%.set}.html"
  rm -f "$report_path"

  local preset_win report_win
  preset_win=$(winepath -w "$preset_path")
  report_win=$(winepath -w "$report_path")

  local template_copy="$TMP_DIR/${preset_name%.set}.ini.tpl"
  local config_path="$TMP_DIR/${preset_name%.set}.ini"

  local preset_escaped="${preset_win//\\/\\\\}"
  local report_escaped="${report_win//\\/\\\\}"

  sed -e "s|{PRESET_PATH}|$preset_escaped|g" \
      -e "s|{SYMBOL}|$symbol|g" \
      -e "s|{REPORT_PATH}|$report_escaped|g" \
      "$TEMPLATE" > "$template_copy"

  envsubst '${MT5_LOGIN} ${MT5_PASSWORD} ${MT5_SERVER}' < "$template_copy" > "$config_path"

  local config_win
  config_win=$(winepath -w "$config_path")

  echo "[INFO] Running backtest for $symbol using $preset_name"
  if ! wine "$MT5_TERMINAL" /config:"$config_win" /portable /skipupdate >/dev/null 2>&1; then
    echo "[ERROR] Backtest failed for $preset_name" >&2
    return 1
  fi

  if [[ ! -f "$report_path" ]]; then
    echo "[WARN] Report not generated for $preset_name" >&2
  else
    echo "[INFO] Report saved to $report_path"
  fi
}

result=0
for preset in "${PRESETS[@]}"; do
  if ! run_backtest "$preset"; then
    result=1
  fi
done

if [[ -n "$XVFB_PID" ]]; then
  kill "$XVFB_PID" >/dev/null 2>&1 || true
  XVFB_PID=""
fi

if python "$ROOT_DIR/tools/validate_logs.py" "$LOG_PATH"; then
  echo "OK"
else
  echo "FAILED"
  result=1
fi

exit $result
