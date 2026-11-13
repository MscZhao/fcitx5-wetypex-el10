# WeTypeX EL10

在 EL10（AlmaLinux / Rocky Linux / RHEL / CentOS Stream 10）上**原生构建的 fcitx5 全链 RPM**，以及 [WeTypeX](https://github.com/panxuc/fcitx5-wetypex)（微信输入法兼容层）的一键安装包。

> 背景：EPEL 10 完全没有 fcitx5 生态包。本项目在 AlmaLinux 10.2 x86_64 上从源码构建整套 `.el10` RPM，让 WeTypeX（MIT 适配器 + 用户自行下载的腾讯 WeType 运行时）能在 EL10 系发行版上通过 Fcitx5 正常使用。
>
> 完整交接文档见 [wetypex-el10/HANDOFF.md](wetypex-el10/HANDOFF.md)。

## 原作者项目

WeTypeX 由 [panxuc](https://github.com/panxuc) 开发，上游仓库：**https://github.com/panxuc/fcitx5-wetypex**

本仓库仅做 EL10 平台的 RPM 打包与适配，不修改上游功能；问题反馈请区分：上游功能问题到原作者仓库提 Issue，本仓库只处理 EL10 打包问题。

## 产出（8 包链条，全部构建 + 验证通过）

| # | 包 | 版本 | 说明 |
|---|---|---|---|
| 1 | xcb-imdkit | 1.0.9 | git clone 自制 tarball（无上游发布包） |
| 2 | libcxx | 21.1.8 | LLVM 21.1.8 runtimes，`-DLLVM_LIBDIR_SUFFIX=64` 装 lib64 |
| 3 | fcitx5 | 5.1.23 | 上游最新；含 nlohmann_json（EL10 包名 `json-devel`）、plasma-wayland-protocols、librsvg2 依赖 |
| 4 | fcitx5-qt | 5.1.16 | Qt6 输入上下文插件 + WidgetsAddons/DBusAddons |
| 5 | fcitx5-gtk | 5.1.7 | gtk3 + gtk4 immodule |
| 6 | libime | 1.1.17 | 引擎库；45MB 语言模型拆为独立的 libime-data 子包（WeTypeX 不需要） |
| 7 | fcitx5-configtool | 5.1.16 | 真 KF6 图形配置器（kcm + migrator + kbd-layout-viewer5） |
| 8 | fcitx5-wetypex | 3.0.1.684-6.el10 | nfpm 打包；弱依赖 ffmpeg 已移除 |

验证结论：整链 dnf 解析安装成功；`wcwss_bridge.so` 链到自建 libc++ 21.1.8；`fcitx5 --version` = 5.1.23；wetypex 全部二进制依赖零缺失。

## 安装

### 方式 A：一键安装（推荐，离线）

从 [Releases](../../releases) 下载 `wetypex-el10-bundle-*.run`：

```bash
sudo ./wetypex-el10-bundle-3.0.1.684-6.el10.x86_64.run
# 自动：SHA 自校验 → 装 epel-release → dnf 装 9 个运行时 RPM（外部依赖走发行版仓库）
#     → 以 SUDO_USER 身份执行 fcitx5-wetypex-setup --download --accept-upstream-license
#     → fcitx5-wetypex-setup --check --transport
# 参数：--no-download 跳过运行时下载；--extract-only [目录] 只解包
```

装完：重启 fcitx5（`fcitx5 -r -d`；GNOME Wayland 配 environment.d：`GTK_IM_MODULE=fcitx`、`QT_IM_MODULE=fcitx`、`XMODIFIERS=@im=fcitx`），然后用 `fcitx5-configtool` 把 WeTypeX 加入输入法列表。

### 方式 B：本地仓库

从 Releases 下载 `el10-repo-*.tar.gz` 解压后：

```bash
sudo tee /etc/yum.repos.d/el10-local.repo <<'EOF'
[el10-local]
name=WeTypeX EL10 local build repo
baseurl=file:///解压路径/el10-repo
enabled=1
gpgcheck=0
EOF
sudo dnf install fcitx5-wetypex fcitx5-configtool fcitx5-gtk
```

（也可参考 [el10-local.repo.example](el10-local.repo.example)）

**体积预期**：裸机全量 ~555 包/441MB（QtWebEngine 即 Chromium 89MB 是大头）；真实桌面机已装图形栈，实际增量 ~150-250 包。

**限制**：仅 x86_64；需 EL10（Alma/Rocky/RHEL/CentOS Stream/OEL）；RHEL 需先手动启用 EPEL10。

## 复现构建

在装好工具链的 EL10 机器上（前置依赖见 HANDOFF.md：EPEL10+CRB、gcc/cmake/ninja/rpmbuild/clang 21、KF6 全套 devel 等；源码下载可走代理）：

```bash
# 1. 源码 tarball 放 ~/rpmbuild/SOURCES/，按链条构建：
#    xcb-imdkit → libcxx → fcitx5 → (fcitx5-qt | fcitx5-gtk | libime) → configtool
for s in xcb-imdkit libcxx fcitx5 fcitx5-qt fcitx5-gtk libime fcitx5-configtool; do
  rpmbuild -ba ~/rpmbuild/SPECS/$s.spec && sudo dnf install -y ~/rpmbuild/RPMS/x86_64/$s-*.rpm
done
# 2. wetypex staging（spec 与打包模板见 wetypex-el10/）
# 3. 刷新仓库 + 一键包
createrepo_c ~/el10-repo && ./wetypex-el10/build-bundle.sh
```

## 仓库结构

```
├── README.md                  ← 本文件
├── el10-local.repo.example    ← 本地 dnf 仓库配置示例
├── wetypex-el10/              ← 工作树（git 主体）
│   ├── HANDOFF.md             ← 完整交接文档
│   ├── specs/                 ← 7 个已沉淀修正的 RPM spec
│   ├── build-bundle.sh        ← 一键安装包构建脚本（可复现）
│   ├── sync-to-debian.sh      ← 回传构建机脚本（按需改 SSH/路径）
│   └── fcitx5-wetypex/        ← 上游 WeTypeX v3.0.1.684 源码快照（vendored，MIT）
├── el10-repo/                 ← 本地构建产物（git 忽略，走 Releases）
└── src-rpms/                  ← 源码 RPM（git 忽略，走 Releases）
```

## 许可与声明

- 本仓库的 spec、脚本、文档：[MIT](LICENSE)
- vendored 的 `wetypex-el10/fcitx5-wetypex/` 源码：上游 [panxuc/fcitx5-wetypex](https://github.com/panxuc/fcitx5-wetypex) 的 MIT 许可，随快照保留其 LICENSE 与 NOTICE
- **本仓库不包含、不分发腾讯 WeType（微信输入法）的任何专有二进制、词典、模型或资源**；运行时由用户在安装时通过 `fcitx5-wetypex-setup --download` 自行从官方渠道获取
- WeTypeX 是非官方第三方项目，与腾讯公司无任何关联或背书关系；"微信""微信输入法"相关商标归腾讯所有，仅供个人学习交流使用
