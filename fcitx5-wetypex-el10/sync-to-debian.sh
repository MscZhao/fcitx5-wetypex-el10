#!/usr/bin/env bash
# 将 EL10 构建产物回传 Debian 机（dist/el10/）
# 前提：Debian 机反向 SSH 隧道已开（本机执行 ssh -p2222 psm@127.0.0.1 可达）
set -euo pipefail

DEST=${1:-~/wetypex/dist/el10/}   # Debian 机上的目标目录，按实际仓库路径调整
SSH="ssh -p 2222 psm@127.0.0.1"

# 连通性预检
$SSH true 2>/dev/null || { echo "❌ SSH -p2222 psm@127.0.0.1 不可达（隧道未开？）" >&2; exit 1; }

$SSH "mkdir -p $DEST"
rsync -av --info=progress2 -e "$SSH" /home/psm/el10-repo/*.rpm "$DEST"/
rsync -av -e "$SSH" /home/psm/el10-repo/*.run "$DEST"/
rsync -av -e "$SSH" /home/psm/fcitx5-wetypex-el10/specs/ "$DEST"/../specs/ 2>/dev/null || \
  rsync -av -e "$SSH" /home/psm/fcitx5-wetypex-el10/specs/ "$DEST"/specs/

echo "✅ 回传完成：$(ls /home/psm/el10-repo/*.rpm | wc -l) 个 RPM + $(ls /home/psm/el10-repo/*.run 2>/dev/null | wc -l) 个一键安装包 + specs/"
