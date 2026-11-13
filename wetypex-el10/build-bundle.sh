#!/usr/bin/env bash
# 将 WeTypeX EL10 运行时 RPM（8 包链条的主包）打包成自解压一键安装 .run
# 产物: wetypex-el10-bundle-<ver>.run   用法见包内 install.sh
set -euo pipefail

REPO=${REPO:-/home/psm/el10-repo}
OUT=${OUT:-/home/psm/el10-repo}

WETYPEX_RPM=$(ls -t "$REPO"/fcitx5-wetypex-*.rpm | head -1)
BUNDLE_VER=$(basename "$WETYPEX_RPM" .rpm | sed 's/^fcitx5-wetypex-//')   # 例: 3.0.1.684-6.el10
STAGE=$(mktemp -d /tmp/wetypex-bundle.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT
mkdir "$STAGE/rpms"

# 运行时主包集合（不含 -devel/-debuginfo/-debugsource/libime-data）
PKGS=(xcb-imdkit libcxx fcitx5 fcitx5-qt fcitx5-qt-libfcitx5qt6widgets \
      fcitx5-gtk libime fcitx5-configtool)
for p in "${PKGS[@]}"; do
  # -[0-9]* 确保匹配主包自身（排除 fcitx5-qt-libfcitx5qt6widgets 这类名称前缀子包）
  f=$(ls -t "$REPO"/"$p"-[0-9]*.rpm | grep -vE -- '-devel-|-debuginfo-|-debugsource-|-data-' | head -1) || {
    echo "❌ 找不到 $p 的运行时主包" >&2; exit 1; }
  cp "$f" "$STAGE/rpms/"
done
cp "$WETYPEX_RPM" "$STAGE/rpms/"

echo "运行时集合:"
ls -la "$STAGE/rpms/"
du -sh "$STAGE/rpms/"

# 校验清单
( cd "$STAGE" && sha256sum rpms/*.rpm > SHA256SUMS )

# 安装器（@@SKIP@@ 与 @@VER@@ 由下方 sed 原位替换，行数不变）
cat > "$STAGE/install.sh" <<'INSTALLER'
#!/bin/bash
# WeTypeX EL10 一键安装包（自解压 .run，内嵌 RPM，无需配置任何仓库）
# 用法: ./wetypex-el10-bundle-*.run [--extract-only [目录]]
set -euo pipefail

BUNDLE_VERSION="@VER@"
SKIP=@@SKIP@@
WORK=$(mktemp -d /tmp/wetypex-bundle.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

die(){ echo "❌ $*" >&2; exit 1; }
step(){ echo; echo "==> $*"; }
# 以指定用户身份运行命令（安装器通常以 root/sudo 执行，而 setup 数据是用户态）
RUN_AS(){ local u="$1"; shift; if [ "$(id -u)" = 0 ]; then sudo -u "$u" "$@"; else "$@"; fi; }

echo "WeTypeX EL10 一键安装包 $BUNDLE_VERSION"

step "解压内置 RPM 并校验"
tail -n +"$SKIP" "$0" | tar xzf - -C "$WORK"
( cd "$WORK" && sha256sum -c --quiet SHA256SUMS ) || die "内置 RPM 校验失败"
echo "OK：$(ls "$WORK"/rpms/*.rpm | wc -l) 个 RPM"

case "${1:-install}" in
  --extract-only)
    DEST="${2:-$PWD/wetypex-el10-rpms}"
    mkdir -p "$DEST"
    cp "$WORK"/rpms/*.rpm "$WORK"/SHA256SUMS "$DEST"/
    echo "已解包至 $DEST"
    echo "手动安装: sudo dnf install '$DEST'/*.rpm"
    exit 0 ;;
  install) AUTO_DOWNLOAD=1 ;;
  --no-download) AUTO_DOWNLOAD=0 ;;
  *) die "用法: $0 [--no-download] [--extract-only [目录]]" ;;
esac

# ---- 预检 ----
[ "$(uname -m)" = "x86_64" ] || die "仅支持 x86_64（当前 $(uname -m)）"
[ -r /etc/os-release ] || die "无法读取 /etc/os-release"
. /etc/os-release
case "${ID:-}" in
  almalinux|rocky|rhel|centos|ol) ;;
  *) die "仅支持 RHEL 系 EL10（当前 ${ID:-unknown}）" ;;
esac
[ "${VERSION_ID:-}" = "10" ] || [ "${VERSION_ID:-0}" = 10 ] || [ "${VERSION_ID%%.*}" = "10" ] \
  || die "需要 EL10（当前 ${PRETTY_NAME:-版本未知}）"

SUDO=""
[ "$(id -u)" = 0 ] || SUDO=sudo
$SUDO true 2>/dev/null || die "请用 root 运行，或配置免密 sudo"

step "检查 EPEL10 仓库（layer-shell-qt/qt6-qtwebengine/KF6 等运行时依赖需要）"
if ! $SUDO rpm -q epel-release >/dev/null 2>&1; then
  if [ "${ID:-}" = rhel ]; then
    echo "⚠️  RHEL 10 需先手动启用 EPEL10："
    echo "   sudo dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm"
    die "启用 EPEL10 后重新运行本安装包"
  else
    $SUDO dnf install -y epel-release 2>/dev/null \
      || $SUDO dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm"
  fi
fi
echo "EPEL10 OK"

step "安装 WeTypeX 全链（系统依赖由 dnf 自动从发行版仓库解析）"
$SUDO dnf install -y "$WORK"/rpms/*.rpm

# ---- 自动下载并安装腾讯官方 WeType 运行时（用户态数据，~382MB）----
# runtime 存在 ~/.local/share/fcitx5-wetypex/，必须以实际使用者身份运行，
# 因此取 SUDO_USER（root 直跑则无法确定目标用户，退化为打印手动命令）。
DL_OK=0
if [ "${AUTO_DOWNLOAD:-1}" = 1 ]; then
  REAL_USER="${SUDO_USER:-}"
  if [ -z "$REAL_USER" ] && [ "$(id -u)" != 0 ]; then REAL_USER="$(id -un)"; fi
  if [ -n "$REAL_USER" ] && [ "$REAL_USER" != root ]; then
    step "以 $REAL_USER 身份下载腾讯官方 WeType 运行时（~382MB，视网速几分钟）"
    if RUN_AS "$REAL_USER" fcitx5-wetypex-setup --download --accept-upstream-license; then
      DL_OK=1
      step "运行时就绪，检查核心与本地传输："
      RUN_AS "$REAL_USER" fcitx5-wetypex-setup --check --transport || true
    else
      echo "⚠️  运行时自动下载未完成（可离线装或稍后手动执行）。"
    fi
  else
    echo "⚠️  以 root 身份直接运行，无法确定目标用户，跳过自动下载。"
  fi
  [ "$DL_OK" = 1 ] || echo "    手动执行: fcitx5-wetypex-setup --download --accept-upstream-license"
else
  echo "==> 已跳过运行时自动下载（--no-download）"
fi

step "安装完成。后续步骤："
if [ "$DL_OK" = 1 ]; then cat <<'POST'
  ✓ 腾讯官方 WeType 运行时已自动下载并安装（以 SUDO_USER 身份）。

  1. 重启 Fcitx5：
     X11 或独立启动的 Fcitx5：  fcitx5 -r -d
     GNOME Wayland 需设置环境变量，写入 ~/.config/environment.d/90-fcitx.conf：
       GTK_IM_MODULE=fcitx
       QT_IM_MODULE=fcitx
       XMODIFIERS=@im=fcitx
     （KDE Plasma Wayland：系统设置 → 虚拟键盘 → 选 Fcitx 5）

  2. 运行 fcitx5-configtool，把 WeTypeX 加入输入法列表。
POST
else cat <<'POST'
  1. 下载官方运行时（先阅读并接受上游腾讯软件许可，约 382MB）：
     fcitx5-wetypex-setup --download --accept-upstream-license

  2. 检查核心与本地传输：
     fcitx5-wetypex-setup --check --transport

  3. 重启 Fcitx5：
     X11 或独立启动的 Fcitx5：  fcitx5 -r -d
     GNOME Wayland 需设置环境变量，写入 ~/.config/environment.d/90-fcitx.conf：
       GTK_IM_MODULE=fcitx
       QT_IM_MODULE=fcitx
       XMODIFIERS=@im=fcitx
     （KDE Plasma Wayland：系统设置 → 虚拟键盘 → 选 Fcitx 5）

  4. 运行 fcitx5-configtool，把 WeTypeX 加入输入法列表。
POST
fi
cat <<'POST'

卸载：sudo dnf remove fcitx5-wetypex fcitx5 fcitx5-qt fcitx5-gtk libime \
      libime-data xcb-imdkit libcxx fcitx5-configtool
详细文档: https://github.com/panxuc/fcitx5-wetypex/blob/main/docs/installation.md
POST
exit 0
INSTALLER

sed -i "s|@VER@|$BUNDLE_VER|g" "$STAGE/install.sh"
SKIP=$(( $(wc -l < "$STAGE/install.sh") + 1 ))
sed -i "s|@@SKIP@@|$SKIP|" "$STAGE/install.sh"

# 组装：脚本头 + gzip payload
tar czf "$STAGE/payload.tar.gz" -C "$STAGE" rpms SHA256SUMS
RUN="$OUT/wetypex-el10-bundle-$BUNDLE_VER.run"
cat "$STAGE/install.sh" "$STAGE/payload.tar.gz" > "$RUN"
chmod +x "$RUN"

echo
echo "✅ 产物: $RUN ($(du -h "$RUN" | cut -f1))"
echo "   目标机执行: ./$(basename "$RUN")"
