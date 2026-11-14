#!/usr/bin/env bash
# EL10 全链自动构建：7 个 spec RPM → wetypex staging → nfpm RPM → 本地仓库 → 一键包 → Release 资产
#
# 用法（GitHub Actions: almalinux:10 容器内 root；本机 EL10 亦可复跑）:
#   bash fcitx5-wetypex-el10/el10/build-el10.sh
#
# 环境变量:
#   JOBS            并行度（默认 nproc）
#   WETYPEX_RELEASE fcitx5-wetypex 的 release 号（默认取上游 packaging/PKGBUILD.in 的 pkgrel，当前为 5）
#   OUT_DIR         资产输出目录（默认 $PWD/ci-out）
#   SKIP_DEPS=1     跳过第 1 步依赖安装（本机复跑用）
#
# 产物（$OUT_DIR 下）:
#   repo/                                        全部 RPM（含 devel/debuginfo）+ repodata + bundle
#   fcitx5-wetypex-<ver>-bundle.el10.x86_64.run  一键安装包
#   fcitx5-wetypex-<ver>-rpms.el10.x86_64.tar.gz 运行时 9 包 + repodata（与 bundle 内容一致）
#   fcitx5-wetypex-el10-src-rpms.tar.gz          5 个源码 RPM（不含 libcxx/libime 巨型 src）
#   SHA256SUMS / release-notes.md / logs/
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)            # fcitx5-wetypex-el10/
OUT_DIR=${OUT_DIR:-$PWD/ci-out}
JOBS=${JOBS:-$(nproc)}
RPMTOP=/tmp/el10-rpmbuild
STAGE=/tmp/el10-root
SRC_MOUNT=/src                                  # container-stage.sh 写死 cmake -S /src
NFPM_VER=2.47.0
NFPM_SHA256=0660ca602b2d2d2ae4781a06c692b3eeb9d437ffea05b831d76e41f4a3188783

WETYPEX_SRC="$WT_DIR/fcitx5-wetypex"
[ -f "$WETYPEX_SRC/CMakeLists.txt" ] || { echo "❌ 找不到 wetypex 源码（submodule 未检出？）git submodule update --init" >&2; exit 1; }

log(){ echo "==> $*"; }
die(){ echo "❌ $*" >&2; exit 1; }
fetch(){ # fetch <保存名> <url> —— 已存在则跳过（支持断点续跑）
  local out=$1 url=$2
  [ -s "$out" ] && { log "已有 $out，跳过下载"; return 0; }
  log "下载 $url"
  curl -fL --retry 5 --retry-all-errors -C - -o "$out" "$url" || { rm -f "$out"; die "下载失败: $url"; }
}

mkdir -p "$OUT_DIR/logs"

# ========== 1. 工具链（EPEL10 + CRB + 构建工具） ==========
if [ "${SKIP_DEPS:-0}" != "1" ]; then
  log "安装基础工具与仓库配置"
  dnf install -y dnf5-plugins 2>/dev/null || true
  dnf install -y dnf-plugins-core
  dnf install -y epel-release 2>/dev/null \
    || dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm"
  dnf config-manager --set-enabled crb
  log "安装构建工具链（clang 取自 EPEL10，21.1.8）"
  dnf install -y gcc-c++ make cmake ninja-build git curl rpm-build createrepo_c \
    zstd python3 python3-pyyaml clang tar xz pkgconf-pkg-config findutils diffutils file
  dnf clean all
fi
command -v rpmbuild >/dev/null || die "缺 rpmbuild"
command -v clang++  >/dev/null || die "缺 clang++（wetypex 硬依赖）"

# ========== 2. rpmbuild 树 + 源码 ==========
log "准备 rpmbuild 树与源码"
mkdir -p "$RPMTOP"/{SPECS,SOURCES,BUILD,RPMS,SRPMS}
cp "$WT_DIR"/specs/*.spec "$RPMTOP/SPECS/"

cd "$RPMTOP/SOURCES"
fetch llvm-project-llvmorg-21.1.8.tar.gz https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-21.1.8.tar.gz
# 注意：fcitx-im.org 的 tarball 都在各自项目子目录下（/fcitx5/<project>/）
fetch fcitx5-5.1.23_dict.tar.zst        https://download.fcitx-im.org/fcitx5/fcitx5/fcitx5-5.1.23_dict.tar.zst
fetch fcitx5-qt-5.1.16.tar.zst          https://download.fcitx-im.org/fcitx5/fcitx5-qt/fcitx5-qt-5.1.16.tar.zst
fetch fcitx5-gtk-5.1.7.tar.zst          https://download.fcitx-im.org/fcitx5/fcitx5-gtk/fcitx5-gtk-5.1.7.tar.zst
fetch libime-1.1.17_dict.tar.zst        https://download.fcitx-im.org/fcitx5/libime/libime-1.1.17_dict.tar.zst
fetch fcitx5-configtool-5.1.16.tar.zst  https://download.fcitx-im.org/fcitx5/fcitx5-configtool/fcitx5-configtool-5.1.16.tar.zst

# xcb-imdkit 无上游发布包：git clone 自制 tarball
if [ ! -s xcb-imdkit-1.0.9.tar.xz ]; then
  rm -rf xcb-imdkit-1.0.9
  git clone --depth 1 --recurse-submodules -b 1.0.9 https://github.com/fcitx/xcb-imdkit xcb-imdkit-1.0.9
  tar --exclude-vcs --xz -cf xcb-imdkit-1.0.9.tar.xz xcb-imdkit-1.0.9
  rm -rf xcb-imdkit-1.0.9
fi
rm -f llvm-project-llvmorg-21.1.8.tar.gz.asc 2>/dev/null || true

# ========== 3. 按链条构建 7 个 RPM ==========
CHAIN="xcb-imdkit libcxx fcitx5 fcitx5-qt fcitx5-gtk libime fcitx5-configtool"
for s in $CHAIN; do
  log "dnf builddep $s"
  dnf builddep -y "$RPMTOP/SPECS/$s.spec"
  log "rpmbuild -ba $s"
  if ! rpmbuild --define "_topdir $RPMTOP" -ba "$RPMTOP/SPECS/$s.spec" > "$OUT_DIR/logs/$s.log" 2>&1; then
    tail -n 80 "$OUT_DIR/logs/$s.log" || true
    die "$s 构建失败（完整日志 $OUT_DIR/logs/$s.log）"
  fi
  tail -n 3 "$OUT_DIR/logs/$s.log"
  # 每包构建后安装 base+devel 供后续包使用（不装 debuginfo/data）
  case $s in
    xcb-imdkit)        dnf install -y "$RPMTOP"/RPMS/x86_64/xcb-imdkit-[0-9]*.rpm "$RPMTOP"/RPMS/x86_64/xcb-imdkit-devel-*.rpm ;;
    libcxx)            dnf install -y "$RPMTOP"/RPMS/x86_64/libcxx-[0-9]*.rpm "$RPMTOP"/RPMS/x86_64/libcxx-devel-*.rpm ;;
    fcitx5)            dnf install -y "$RPMTOP"/RPMS/x86_64/fcitx5-[0-9]*.rpm "$RPMTOP"/RPMS/x86_64/fcitx5-devel-*.rpm ;;
    fcitx5-qt)         dnf install -y "$RPMTOP"/RPMS/x86_64/fcitx5-qt-[0-9]*.rpm "$RPMTOP"/RPMS/x86_64/fcitx5-qt-libfcitx5qt6widgets-*.rpm "$RPMTOP"/RPMS/x86_64/fcitx5-qt-devel-*.rpm ;;
    fcitx5-gtk)        dnf install -y "$RPMTOP"/RPMS/x86_64/fcitx5-gtk-[0-9]*.rpm "$RPMTOP"/RPMS/x86_64/fcitx5-gtk-devel-*.rpm ;;
    libime)            dnf install -y "$RPMTOP"/RPMS/x86_64/libime-[0-9]*.rpm "$RPMTOP"/RPMS/x86_64/libime-devel-*.rpm ;;
    fcitx5-configtool) dnf install -y "$RPMTOP"/RPMS/x86_64/fcitx5-configtool-[0-9]*.rpm ;;
  esac
done

# ========== 4. wetypex staging ==========
WETYPEX_VERSION=$(sed -n 's/^project([^ ]* VERSION \([^ ]*\).*/\1/p' "$WETYPEX_SRC/CMakeLists.txt")
[ -n "$WETYPEX_VERSION" ] || die "无法从 CMakeLists.txt 解析 wetypex 版本号"
WETYPEX_RELEASE=${WETYPEX_RELEASE:-$(sed -n 's/^pkgrel=//p' "$WETYPEX_SRC/packaging/PKGBUILD.in")}
[ -n "$WETYPEX_RELEASE" ] || die "无法确定 release 号（PKGBUILD.in pkgrel / \$WETYPEX_RELEASE）"

log "wetypex staging（v$WETYPEX_VERSION, release $WETYPEX_RELEASE.el10）"
rm -rf "$SRC_MOUNT" "$STAGE" /tmp/wetypex-build
cp -a "$WETYPEX_SRC" "$SRC_MOUNT"        # container-stage.sh 写死 cmake -S /src
( cd "$SRC_MOUNT" && WETYPEX_LAYER_SHELL=ON WETYPEX_BUILD_JOBS=$JOBS \
    packaging/container-stage.sh "$STAGE" lib64 )
[ -f "$STAGE/usr/lib64/fcitx5-wetypex/wcwss_bridge.so" ] || die "staging 产物缺 wcwss_bridge.so"

# ========== 5. nfpm 打包 fcitx5-wetypex RPM ==========
log "安装 nfpm v$NFPM_VER"
mkdir -p /tmp/el10-tools && cd /tmp/el10-tools
fetch "nfpm_${NFPM_VER}_Linux_x86_64.tar.gz" "https://github.com/goreleaser/nfpm/releases/download/v${NFPM_VER}/nfpm_${NFPM_VER}_Linux_x86_64.tar.gz"
echo "$NFPM_SHA256  nfpm_${NFPM_VER}_Linux_x86_64.tar.gz" | sha256sum -c - || die "nfpm 校验失败"
tar xzf "nfpm_${NFPM_VER}_Linux_x86_64.tar.gz" nfpm
install -m 755 nfpm /usr/local/bin/nfpm

log "生成 EL10 版 nfpm 配置（依赖按 HANDOFF 调整：去 ffmpeg，wl-clipboard/libnotify/pipewire-utils 转弱依赖）"
python3 - "$WETYPEX_SRC/packaging/nfpm.yaml" > /tmp/nfpm-el10.yaml <<'PYEOF'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
rpm = d.setdefault('overrides', {}).setdefault('rpm', {})
deps = [x for x in rpm.get('depends', []) if x != '/usr/bin/ffmpeg']
weak = ['wl-clipboard', 'libnotify', 'pipewire-utils']
deps = [x for x in deps if x not in weak]
rpm['depends'] = deps
rpm['recommends'] = weak
yaml.safe_dump(d, sys.stdout, allow_unicode=True, sort_keys=False)
PYEOF
sed -i -e "s|@WETYPEX_VERSION@|$WETYPEX_VERSION|g" \
       -e "s|@WETYPEX_RELEASE@|$WETYPEX_RELEASE.el10|g" \
       -e "s|@WETYPEX_STAGE@|$STAGE|g" \
       -e "s|@WETYPEX_PROJECT_ROOT@|$SRC_MOUNT|g" /tmp/nfpm-el10.yaml

# ========== 6. 汇聚仓库 + createrepo + bundle ==========
REPO_DIR=$OUT_DIR/repo
mkdir -p "$REPO_DIR"
cp "$RPMTOP"/RPMS/x86_64/*.rpm "$REPO_DIR"/
log "nfpm package fcitx5-wetypex"
nfpm package --config /tmp/nfpm-el10.yaml --packager rpm --target "$REPO_DIR/"
createrepo_c -q "$REPO_DIR"

log "构建一键安装包"
REPO="$REPO_DIR" OUT="$REPO_DIR" bash "$WT_DIR/build-bundle.sh" > "$OUT_DIR/logs/build-bundle.log" 2>&1 \
  || { tail -n 40 "$OUT_DIR/logs/build-bundle.log"; die "bundle 构建失败"; }
WETYPE_RPM=$(ls -t "$REPO_DIR"/fcitx5-wetypex-[0-9]*.rpm | head -1)
NVR=$(basename "$WETYPE_RPM" .x86_64.rpm)          # fcitx5-wetypex-3.0.1.684-5.el10
WETYPE_VER=${NVR#fcitx5-wetypex-}                  # 3.0.1.684-5
BUNDLE=$(ls -t "$REPO_DIR"/fcitx5-wetypex-*bundle*.run | head -1)

# ========== 7. Release 资产（运行时仓库包 / 源码包 / 校验 / 说明） ==========
log "打包运行时 RPM 仓库（与 bundle 内容一致的 9 包 + repodata）"
RUNTIME_STAGING=/tmp/el10-runtime/el10-repo
rm -rf /tmp/el10-runtime && mkdir -p "$RUNTIME_STAGING"
RUNTIME_PKGS="xcb-imdkit libcxx fcitx5 fcitx5-qt fcitx5-qt-libfcitx5qt6widgets fcitx5-gtk libime fcitx5-configtool"
for p in $RUNTIME_PKGS; do
  f=$(ls -t "$REPO_DIR"/"$p"-[0-9]*.rpm | grep -vE -- '-devel-|-debuginfo-|-debugsource-|-data-' | head -1) \
    || die "找不到运行时包 $p"
  cp "$f" "$RUNTIME_STAGING"/
done
cp "$WETYPE_RPM" "$RUNTIME_STAGING"/
createrepo_c -q "$RUNTIME_STAGING"
tar -C /tmp/el10-runtime -czf "$OUT_DIR/fcitx5-wetypex-${WETYPE_VER}-rpms.el10.x86_64.tar.gz" el10-repo

log "打包源码 RPM（5 个，不含 libcxx/libime 巨型 src）"
SRC_STAGING=/tmp/el10-srprms/src-rpms
rm -rf /tmp/el10-srprms && mkdir -p "$SRC_STAGING"
cp "$RPMTOP"/SRPMS/xcb-imdkit-*.src.rpm "$RPMTOP"/SRPMS/fcitx5-*.src.rpm "$SRC_STAGING"/
tar -C /tmp/el10-srprms -czf "$OUT_DIR/fcitx5-wetypex-el10-src-rpms.tar.gz" src-rpms

mv "$BUNDLE" "$OUT_DIR/"
log "生成 SHA256SUMS 与发布说明"
cd "$OUT_DIR"
sha256sum "$(basename "$BUNDLE")" "fcitx5-wetypex-${WETYPE_VER}-rpms.el10.x86_64.tar.gz" "fcitx5-wetypex-el10-src-rpms.tar.gz" > SHA256SUMS

RPM_LIST=$(ls /tmp/el10-runtime/el10-repo/*.rpm | xargs -n1 basename | sort)
cat > release-notes.md <<EOF
Fcitx5 WeTypeX EL10 自动构建（GitHub Actions，AlmaLinux 10 容器）：fcitx5 全链 RPM（8 包链条）+ WeTypeX（微信输入法兼容层）一键安装包。

## 方式 A：一键安装（推荐，离线）

下载 \`fcitx5-wetypex-${WETYPE_VER}-bundle.el10.x86_64.run\`：

\`\`\`bash
sudo ./fcitx5-wetypex-${WETYPE_VER}-bundle.el10.x86_64.run
# 自动：SHA 自校验 → 装 epel-release → dnf 装 9 个运行时 RPM（外部依赖走发行版仓库）
#     → 以 SUDO_USER 身份执行 fcitx5-wetypex-setup --download --accept-upstream-license
#     → fcitx5-wetypex-setup --check --transport
# 参数：--no-download 跳过运行时下载；--extract-only [目录] 只解包
\`\`\`

装完：重启 fcitx5（\`fcitx5 -r -d\`；GNOME Wayland 需配 environment.d：\`GTK_IM_MODULE=fcitx\`、\`QT_IM_MODULE=fcitx\`、\`XMODIFIERS=@im=fcitx\`），然后用 \`fcitx5-configtool\` 把 WeTypeX 加入输入法列表。

## 方式 B：本地 dnf 仓库

下载并解压 \`fcitx5-wetypex-${WETYPE_VER}-rpms.el10.x86_64.tar.gz\`：

\`\`\`bash
tar xzf fcitx5-wetypex-${WETYPE_VER}-rpms.el10.x86_64.tar.gz
sudo tee /etc/yum.repos.d/el10-local.repo <<'REPO'
[el10-local]
name=WeTypeX EL10 local build repo
baseurl=file:///解压路径/el10-repo
enabled=1
gpgcheck=0
REPO
sudo dnf install fcitx5-wetypex fcitx5-configtool fcitx5-gtk
\`\`\`

## 校验完整性

\`\`\`bash
sha256sum -c SHA256SUMS
\`\`\`

## 运行时 RPM 清单

\`fcitx5-wetypex-${WETYPE_VER}-rpms.el10.x86_64.tar.gz\` 内含以下 9 个包（另附 \`repodata/\` 供 dnf 使用）：

\`\`\`
${RPM_LIST}
\`\`\`

## 限制

- 仅 x86_64；需 EL10 系（Alma/Rocky/RHEL/CentOS Stream/OEL）；RHEL 需先手动启用 EPEL10
- 裸机全量依赖 ~555 包/441MB（QtWebEngine/Chromium 89MB 是大头）；已装图形栈的桌面机实际增量 ~150-250 包

## 许可声明

本发布**不含**腾讯 WeType（微信输入法）的任何专有二进制、词典、模型或资源；运行时由 \`fcitx5-wetypex-setup\` 在用户明确同意后从官方渠道下载。上游项目：https://github.com/panxuc/fcitx5-wetypex （MIT）。本仓库的打包工作（spec/脚本）同样按 MIT 许可发布，详见仓库 README。
EOF

log "完成。$OUT_DIR 内容："
ls -lh "$OUT_DIR" | grep -v '^total'
