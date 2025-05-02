#!/usr/bin/env bash
#
# 📊 performance-collect.sh
# Raspberry Pi Exit Node 向けシステム＆ネットワーク各種メトリクスをまとめて収集するスクリプト
#
# 使い方:
#   1. スクリプトを実行権限にする: chmod +x performance-collect.sh
#   2. 収集先ディレクトリとリモート iperf3 サーバを指定して実行:
#        ./performance-collect.sh --host 192.0.2.10 --port 5201 --outdir ./metrics-$(date +%Y%m%d-%H%M%S)

set -euo pipefail

# ───────────────────────────────────────────────────────────
# 引数パース
# ───────────────────────────────────────────────────────────
REMOTE_HOST=""
REMOTE_PORT=5201
OUTDIR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --host)   REMOTE_HOST="$2"; shift 2 ;;
    --port)   REMOTE_PORT="$2"; shift 2 ;;
    --outdir) OUTDIR="$2";  shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$REMOTE_HOST" || -z "$OUTDIR" ]]; then
  echo "Usage: $0 --host <iperf3-server> --port <iperf3-port> --outdir <output-directory>"
  exit 1
fi

mkdir -p "$OUTDIR"
echo "Metrics will be saved under: $OUTDIR"

# タイムスタンプ
TS=$(date +"%Y-%m-%d %H:%M:%S")
echo "=== Collection start: $TS ===" | tee "$OUTDIR/README.txt"

# 1. iperf3 でスループット測定 (TCP, 10秒間, 1秒ごとレポート)
iperf3 -c "$REMOTE_HOST" -p "$REMOTE_PORT" -t 10 -i 1 \
  | tee "$OUTDIR/iperf3-tcp.log"

# 2. ping で RTT & packet loss (10回)
ping -c 10 "$REMOTE_HOST" \
  | tee "$OUTDIR/ping.log"

# 3. CPU / Load / Memory
echo "- CPU/Load/Memory -" | tee -a "$OUTDIR/system.log"
# CPU使用率とLoadAverage
mpstat 1 1 2>&1 | tee -a "$OUTDIR/system.log"
uptime                | tee -a "$OUTDIR/system.log"
free -m               | tee -a "$OUTDIR/system.log"

# 4. コンテキストスイッチ & 割り込み数
echo "- vmstat (cs & in) -" | tee -a "$OUTDIR/system.log"
vmstat 1 2           | tee -a "$OUTDIR/system.log"

# 5. /proc/interrupts（NIC 割り込み）
echo "- /proc/interrupts (NIC only) -" > "$OUTDIR/interrupts.log"
grep -E "eth0|wlan0|tailscale0" /proc/interrupts >> "$OUTDIR/interrupts.log"

# 6. ネットワーク統計 (/proc/net/dev)
echo "- /proc/net/dev -" > "$OUTDIR/net-dev.log"
awk 'NR>2 {print}' /proc/net/dev >> "$OUTDIR/net-dev.log"

# 7. tailscale ステータス
echo "- tailscale status --json -" > "$OUTDIR/tailscale-status.json"
tailscale status --json >> "$OUTDIR/tailscale-status.json"

# 8. 最後にまとめ
TS_END=$(date +"%Y-%m-%d %H:%M:%S")
echo "=== Collection end: $TS_END ===" | tee -a "$OUTDIR/README.txt"

echo "All metrics collected in $OUTDIR."
