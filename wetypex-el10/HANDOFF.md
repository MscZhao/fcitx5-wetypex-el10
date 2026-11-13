# 交接文档：EL10 fcitx5 + WeTypeX RPM 构建任务

> 给新会话：请读完本文档后从「下一步（按序）」继续执行。本机 = AlmaLinux 10.2 构建机。

## ✅ 2026-11-14 更新：8 包全部构建完成并已在本机验证（fcitx5 已升至 5.1.23）

**包清单（8 个，全部产出并装到本机）**：xcb-imdkit 1.0.9 → libcxx 21.1.8 → fcitx5 **5.1.23**（上游最新；SOVERSION 不变 Core .so.7/Utils .so.2/Config .so.6）→ fcitx5-gtk 5.1.7 → fcitx5-qt 5.1.16 → libime 1.1.17 → fcitx5-configtool 5.1.16 → fcitx5-wetypex 3.0.1.684（nfpm，**release 6.el10**，对齐 5.1.23 重编译）

已验证：
- 本地仓库 `~/el10-repo/`（30 个 RPM + repodata，dnf 配置 `/etc/yum.repos.d/el10-local.repo` 默认 disabled）
- `fcitx5-wetypex-3.0.1.684-6.el10` 经本地仓库整链解析安装成功，postinstall 正常执行
- `ldd wcwss_bridge.so` 解析到自建 libcxx 21.1.8 ✅；`wetypex.so`/`libwetypexconfig.so`/configtool 依赖无缺失；`fcitx5 --version` = 5.1.23
- 7 个 spec 已全部同步回 `~/wetypex-el10/specs/`（与 ~/rpmbuild/SPECS 一致）
- 除 fcitx5 外其余组件均已是上游最新（gtk 5.1.7 / qt 5.1.16 / libime 1.1.17 / configtool 5.1.16 / xcb-imdkit 1.0.9）；LLVM 上游已到 23.1.5 但评估后**不升**（EPEL10 clang 为 21.1.8，libc++ 跨大版本 ABI 风险，现链已验证）

**5.1.23 升级要点**：
1. 5.1.20→5.1.23 仅 fcitx5 一个包需要动；下游四包全链重编零返工（spec 已沉淀踩坑修正）
2. 5.1.23 新增 REQUIRED：**librsvg2-devel**（BuildRequires 已加）；cairo/pango/glib2-devel 也显式列入
3. 早期 5.1.17→5.1.20 的变更背景：libime 1.1.17 硬性要求 `Fcitx5Utils >= 5.1.20`；fcitx5 5.1.20 起新增 `plasma-wayland-protocols-devel`（EPEL10 有 1.20.0）；wayland-protocols 上游要求 ≥1.46 但 EL10 只有 1.45，所需协议 XML 在 1.45 全部存在，已在 spec %prep 里 sed 降级版本下限
4. EL10 的 nlohmann-json 包名是 **json-devel**（provides cmake(nlohmann_json)），不是 nlohmann-json-devel
5. `~/el10-repo/` 只保留 5.1.23 链条；wetypex release 递增规则：每次重编译 +1（当前 6.el10）

### 一键安装 bundle（2026-11-14 新增）
- 产物：`~/el10-repo/wetypex-el10-bundle-3.0.1.684-6.el10.x86_64.run`（15MB，自解压单文件）
- 构建脚本：`~/wetypex-el10/build-bundle.sh`（运行时 9 主包集合 = 8 包链条去掉 devel/debuginfo；**libime-data 已拆为独立子包**，zh_CN.lm 45MB 是 chinese-addons/table 引擎数据，WeTypeX 用不到）
- 安装器流程：sha256 自校验 → 预检（x86_64 / RHEL 系 / EL10 / root）→ 自动装 epel-release → `dnf install rpms/*.rpm`（系统依赖从发行版仓库自动解析）→ **自动以 SUDO_USER 身份执行 `fcitx5-wetypex-setup --download --accept-upstream-license`**（runtime 是用户态数据，root 直跑无 SUDO_USER 时退化为打印手动命令）→ 成功后自动跑 `--check --transport` → 按结果打印条件化后续步骤
- 参数：默认=安装+自动下载；`--no-download` 跳过运行时下载；`--extract-only [目录]` 只解包
- 已验证：自解压 + SHA 校验 OK；空 rpmdb installroot 模拟新机 → 365 包全量解析成功（321M 下载，外系统依赖全来自 EPEL/AppStream）；本机全流程实测：dnf 安装 → SUDO_USER 下载/校验运行时 → `core_ready: true` / `transport_checked: true`
- 注意：RHEL 需先手动启用 EPEL10（脚本有提示）；脚本末尾必须 `exit 0`（否则 bash 读穿 payload 报二进制乱码——已修）
- 依赖体积结论（已评估、**用户拍板不改**）：裸机全量装 ~555 包/441MB，长尾主要是 WebEngine(Chromium 89MB)+GTK/KF6 伴生+dnf 默认弱依赖；关弱依赖可省 127 包但会误伤 wl-clipboard/libnotify/pipewire-utils，维持默认

### 仅剩：回传 Debian 机 + 更新其仓库文档（被隧道阻断）
- Debian 机反向隧道 `ssh -p2222 psm@127.0.0.1` 持续拒连（Connection refused）
- 一键回传脚本已备好：`~/wetypex-el10/sync-to-debian.sh <目标目录>`（隧道恢复后执行即可）
- 待办：scp `~/el10-repo/*.rpm`（30 个，fcitx5 5.1.23 链条 + wetypex 6.el10）→ Debian 机 `dist/el10/`；更新其 `packaging/el10/` 的 build-el10.sh（版本 5.1.12→**5.1.23**、加 json-devel、plasma-wayland-protocols-devel、librsvg2-devel、cairo/pango/glib2-devel、kf6-kitemviews/kpackage/kiconthemes/ksvg/kcmutils/libplasma-devel、configtool spec、wayland-protocols 版本下限 sed 说明）和 README.md

## 任务目标（原始记录）

EPEL 10 **完全没有** fcitx5 生态包（已查证镜像目录），目标是原生构建一套 `.el10` RPM，让 WeTypeX（微信输入法兼容层，MIT 适配器 + 用户自行下载的腾讯 WeType 运行时）能在 Rocky/Alma/RHEL 10 上使用。

**包清单（原计划）**：xcb-imdkit 1.0.9 → libcxx 21.1.8 → fcitx5 5.1.17 → fcitx5-gtk 5.1.7 → fcitx5-qt 5.1.16 → libime 1.1.17 → fcitx5-configtool 5.1.16 → fcitx5-wetypex 3.0.1.684

## 本机状态（AlmaLinux 10.2, x86_64, psm 用户，sudo 免密）

### 已就绪
- EPEL10 + CRB 已启用；工具链齐全（gcc/cmake 3.31.8/clang 21.1.8/rpmbuild/ninja/createrepo_c/zstd/dnf-plugins-core）
- **全部构建依赖已装齐**，包括 KF6 全套 devel（configtool 用，6.25.0）、qt6-qtbase-private-devel、gtk3/gtk4-devel、boost/json-c/expat/fmt/libuv/enchant2/iso-codes 等
- 代理可用：`--socks5-hostname 127.0.0.1:10808`（download.fcitx-im.org 直连很慢且易断，务必走代理 + 断点续传）
- 源码包全在 `~/rpmbuild/SOURCES/`：llvm-project-llvmorg-21.1.8.tar.gz(232M)、libime-1.1.17_dict.tar.zst(82M)、fcitx5-5.1.17_dict.tar.zst(8.1M)、fcitx5-gtk-5.1.7.tar.zst、fcitx5-qt-5.1.16.tar.zst、fcitx5-configtool-5.1.16.tar.zst(155K)、xcb-imdkit-1.0.9.tar.xz(990K，git clone --recurse-submodules 自制，无上游 tarball)
- spec 文件：`~/wetypex-el10/specs/*.spec`（7 个，已按踩坑修正）
- nfpm v2.47.0 静态二进制：`~/wetypex-el10/tools/nfpm`
- wetypex 源码树：`~/wetypex-el10/fcitx5-wetypex/`（v3.0.1.684，与 Debian 机 git 仓库一致）

### 已产出并安装的 RPM（`~/rpmbuild/RPMS/x86_64/`）
| 包 | 状态 |
|---|---|
| xcb-imdkit 1.0.9 + devel | ✅ 已装 |
| libcxx 21.1.8 + devel | ✅ 已装（注意 `-DLLVM_LIBDIR_SUFFIX=64` 装 lib64）|
| fcitx5 5.1.12 + devel | ✅ 已装（**需升级到 5.1.17**，见下）|
| fcitx5-gtk 5.1.7 + devel | ✅ RPM 已产出，**需对 5.1.17 重编**（soname 带完整版本号 libFcitx5Core.so.5.1.x，换版必须重编依赖包）|

## 下一步（按序）

### 1. 修复 fcitx5 5.1.17 构建失败（根因已定位）
错误：`CMake Error at src/im/keyboard/CMakeLists.txt:2 — Target "keyboard" links to: nlohmann_json::nlohmann_json, but the target was not found`。
**fcitx5 5.1.17 新增 nlohmann-json 依赖**：
```bash
sudo dnf install -y nlohmann-json-devel   # EPEL10 有，若无则 EPEL/CRB 里找
# 同时在 fcitx5.spec 的 BuildRequires 加一行：nlohmann-json-devel
rpmbuild -ba ~/rpmbuild/SPECS/fcitx5.spec   # 日志参考 /tmp/fcitx5-build17.log
sudo dnf install -y ~/rpmbuild/RPMS/x86_64/fcitx5-5.1.17*.rpm fcitx5-devel
```
为什么必须 5.1.17：fcitx5-qt 5.1.16 的 widgetsaddons include `fcitx-utils/standardpaths.h`，而 5.1.12 只有 `standardpath.h`（版本不配对）。

### 2. 重编对齐 5.1.17 ABI 的三个包
```bash
for s in fcitx5-qt fcitx5-gtk libime; do rpmbuild -ba ~/rpmbuild/SPECS/$s.spec; done
# fcitx5-qt 需要 qt6-qtbase-private-devel（已装）；gtk 需要 gobject-introspection-devel（已装）
# 然后 sudo dnf install 三个包及其 devel
```

### 3. fcitx5-configtool 5.1.16（真图形配置器；占位脚本已在 fcitx5 包里）
KF6 依赖已装齐。builddep 后直接 `rpmbuild -ba`。%files 按实际安装清单修正（预期会撞 1-2 轮 unpackaged-files，照旧法：从 rpmbuild 错误列表把文件加进 %files）。

### 4. fcitx5-wetypex 打包
```bash
cd ~/wetypex-el10/fcitx5-wetypex
WETYPE_LAYER_SHELL=ON packaging/container-stage.sh /tmp/el10-root lib64
# 注意 container-stage.sh 里写死了 cmake -S /src —— 本机路径不同，需 sed 成实际路径或临时复制
sed -e "s|@WETYPEX_VERSION@|3.0.1.684|g" -e "s|@WETYPEX_RELEASE@|5.el10|g" \
    -e "s|@WETYPEX_STAGE@|/tmp/el10-root|g" -e "s|@WETYPEX_PROJECT_ROOT@|$PWD|g" \
    packaging/nfpm.yaml > /tmp/nfpm-el10.yaml
# 依赖调整（rpm 段）：保留 fcitx5/fcitx5-qt-libfcitx5qt6widgets/libime，新增 libcxx；
# ffmpeg/wl-clipboard/libnotify/pipewire-utils 改成弱依赖（Recommends，EL10 无 ffmpeg）
~/wetypex-el10/tools/nfpm package --config /tmp/nfpm-el10.yaml --packager rpm --target ~/el10-repo/
```
wetypex 硬依赖（CMakeLists.txt:143 起）：clang++ + `-stdlib=libc++`（用我们的 libcxx）、Fcitx5Core≥5.0.14、LibIMEPinyin≥1.0.11、Qt6≥6.2、qt6-qtwebengine（EPEL10 有 6.10.1）、layer-shell-qt（EPEL10 有 6.6.4）。

### 5. 验证
```bash
createrepo_c ~/el10-repo   # 全部 RPM 放进一个目录
sudo dnf install --disablerepo='*' --enablerepo=el10-local fcitx5-wetypex   # 验整链依赖解析
ldd /usr/lib64/fcitx5-wetypex/wcwss_bridge.so | grep libc++   # 应解析到我们 libcxx 21.1.8
fcitx5 --version
```

### 6. 产物回传 + 文档更新
- 全部 RPM scp 回 Debian 机 `dist/el10/`（Debian 机 ssh: `ssh -p2222 psm@127.0.0.1` 即本机）
- Debian 机仓库 `packaging/el10/`：更新 build-el10.sh（版本 5.1.12→5.1.17、加 nlohmann-json-devel、加 configtool spec）和 README.md

## 踩坑记录（写 spec 必读）

1. **%files 不支持 shell 语法**（`|| true`、`2>/dev/null` 都不行），只能用 glob；拿不准就先看 BUILDROOT 实际清单再填
2. rpmbuild 报「发现已安装(但未打包的)文件」= 编译成功，只差 %files 收编，`grep -A20 "发现已安装" 日志`拿清单
3. fcitx5-gtk 选项名是 `ENABLE_GTK2_IM_MODULE`（不是 ENABLE_GTK2）；它产出 GClient 库（devel 子包）+ immodule-probing 工具
4. fcitx5 编译选项：`-DUSE_SYSTEM_XCB_IMDKIT=ON -DENABLE_ENCHANT=ON`；BuildRequires 要：ECM、xcb-util{,-wm,-keysyms}-devel、libuv-devel、fmt-devel、expat-devel、json-c-devel、libuuid-devel、xkeyboard-config(-devel)、nlohmann-json-devel(5.1.17)
5. libcxx（LLVM runtimes）：`-DLLVM_LIBDIR_SUFFIX=64` 决定 lib64；runtimes 不导出 cmake config，devel 只收符号链接+静态库；libunwind 头文件（unwind.h/mach-o/ 等）也装了，要收进 %files
6. 下载一律走代理 + `curl -fL -C - --retry 5`（直连大文件必断；曾有双 curl 并发写同一文件导致包损坏——永远只起一个下载）
7. GNOME Wayland 目标机需要 environment.d 环境变量（GTK_IM_MODULE/QT_IM_MODULE=fcitx、XMODIFIERS=@im=fcitx），装完 `fcitx5-wetypex-setup --download --accept-upstream-license` + `--activate-pending` 才有字（运行时 382MB 从腾讯官方 ZIP 提取）
8. **%files 的 soname glob 坑**：`libX.so.2*` 匹配不到真实文件 `libX.so.5.1.16`（前缀不同）；用 `libX.so.*` + 单独列裸 `.so`（如 devel 用）才稳。fcitx5-qt 实际库名带 Addons（libFcitx5Qt6WidgetsAddons.so.2），libime 实际是驼峰（libIMECore/Pinyin/Table.so.0），libime 1.1.17 无 fcitx3 迁移工具且 LM 数据装在 `%{_libdir}/libime/` 不在 share
9. **fcitx5-configtool 额外依赖**（spec 初稿漏）：KF6ItemViews、KF6IconThemes、KF6Package、KF6Svg(=kf6-ksvg-devel)、KF6KCMUtils、Plasma(=libplasma-devel)；产出含 migrator/kbd-layout-viewer5/plasma-theme-generator，locale 需 `%find_lang` 两个 domain（fcitx5-configtool + kcm_fcitx5）合并进一个 .lang
10. **nfpm rpm 段支持 `recommends:`** 弱依赖（v2.47.0 验证过）；ffmpeg 在 EL10 无包，直接从 depends 里删掉而不是放 recommends
11. BundledCurl 在 staging 时从 curl.se 下载 curl 8.22.0，需 `export ALL_PROXY=socks5h://127.0.0.1:10808`
12. 换 fcitx5 版本 = 所有链接 Fcitx5Core 的包全部重编（soname 带完整版本），本次 5.1.20 的 soname 是 libFcitx5Core.so.7
