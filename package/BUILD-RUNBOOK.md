# 网信办公 v1.0.0 — Windows / macOS 安装包构建 Runbook

> 目标：从 `rebrand/wangxin-1.0.0` 分支构建并打出 **Windows 安装包** 与 **macOS 安装包**。
> 生成日期：2026-09-25

---

## 0. 重要前提（本环境现状）

- **本机（WorkBuddy 沙箱）无法编译**：无 Visual Studio / Qt / CMake / Ninja / Xcode。命令行直连 github:443 被墙（VPN 仅覆盖浏览器），但清除 WorkBuddy 注入的代理变量后，`cmake.org` / `download.qt.io` / `aka.ms` 可 200 直连下载工具链。即便如此，**完整 ONLYOFFICE C++ 源码编译（需 VS2022+Qt5.15，耗时数小时、依赖版本敏感、失败率高）不在此环境进行**。
  → **C++ 编译必须在本机/专用构建机上完成**，本 runbook 提供的是「在你的构建机上怎么打包装」+「编译前置与命令框架」。
- **rebrand 已落在代码里**：`desktop-apps` 的 `inno/defines.iss`（网信办公/网信科技/WX-office）、`advinst/*.aip`（Protocol=WX-office）、`branding.mk`、`win-linux/src/version.h`、`macos/*` 均已改好。你只需在 `rebrand/wangxin-1.0.0` 分支上构建即可，无需再改品牌。
- 两个仓库的 rebrand 分支已推送至 fork：`doudoufei55447/DesktopEditors`、`doudoufei55447/desktop-apps`。

---

## 1. 通用：取代码（rebrand 分支）

```bash
git clone --recurse-submodules -b rebrand/wangxin-1.0.0 ssh://git@github.com/doudoufei55447/DesktopEditors.git WangXinOffice
cd WangXinOffice
git submodule update --init --recursive   # 拉齐 core/sdkjs/web-apps/desktop-sdk/dictionaries
# 确认 desktop-apps 在 rebrand 分支
git -C desktop-apps rev-parse --abbrev-ref HEAD   # 应为 rebrand/wangxin-1.0.0
```

> 子模块 github:443 直连被墙时走 SSH（`git config --global url."ssh://git@github.com/".insteadOf https://github.com/`）。

---

## 2. Windows：编译 + 打包

### 2.1 编译前置（构建机，Windows）
- **Visual Studio 2022**（含 MSVC v143、Windows 10/11 SDK、CMake、Ninja 工作负载）
- **Qt 5.15.x**（ONLYOFFICE 指定版本，预编译；勿用 Qt6）
- **Python 3.11+**、**Node.js 18+**
- **Inno Setup 6**（打 .exe，注册表自动识别）
- **Advanced Installer**（可选，打 .msi）
- VCRedist 由 `make_inno.ps1` 自动下载（构建机需联网）

### 2.2 编译（C++，步骤参照 ONLYOFFICE 官方 Windows 构建文档）
> `build_tools` 仓库 README 目前**只写 Linux**；Windows 用 `configure.py` 生成 VS 工程后 MSBuild 编译。命令框架如下（具体 flag 以 ONLYOFFICE 官方 Windows 构建指南为准）：

```powershell
# 取 build_tools（构建编排，非子模块）
git clone https://github.com/ONLYOFFICE/build_tools.git   # 或用 SSH
cd build_tools
python configure.py --platform=win --arch=64 --build_dir <out>   # 生成 VS 解决方案
# 用 VS / MSBuild 编译 DesktopEditors（core + sdkjs + desktop-sdk + desktop-apps 前端）
```

打包脚本会把你传入的 `-BuildDir`（**该目录需包含 `desktop\` 子目录**，内含 `DesktopEditors.exe`、`converter/`、`editors/`、`updatesvc.exe` 等）通过 junction 挂到 `desktop-apps/package/build/<arch>`，iscc 读取 `{#BUILD_DIR}\desktop\*` 即命中。
→ 你只需把 `-BuildDir` 指向「包含 `desktop\` 的那个目录」即可，不必手动把产物挪到固定路径。

### 2.3 打包（✅ 本步可在你的构建机上直接跑，且已就绪）
随附脚本已提交进仓库 `desktop-apps/package/build_win_installer.ps1`（clone 后即在仓库内，无需另拷；也可放在任意目录，脚本会自动探测仓库根）：

```powershell
# 在构建机 PowerShell 中（以管理员非必需，但需要写权限）
.\desktop-apps\package\build_win_installer.ps1 -Version 1.0.0.0 -BuildDir D:\path\to\built\dir   # 该 dir 含 desktop\ 子目录
# 同时出 .msi：
.\desktop-apps\package\build_win_installer.ps1 -Version 1.0.0.0 -BuildDir D:\path\to\built\dir -AdvInst
# 如需签名（需证书）：
.\desktop-apps\package\build_win_installer.ps1 -Version 1.0.0.0 -BuildDir D:\path\to\built\dir -AdvInst -Sign
```

脚本会：
1. 将你的构建目录通过**目录 junction** 挂到 `desktop-apps/package/build/<arch>`（即 iscc 默认 `{#BUILD_DIR}` 所在，可逆：构建完 `cmd /c rmdir <junction>` 即删）。
2. 调 `desktop-apps/package/make_inno.ps1` → 生成 **`网信办公-DesktopEditors-1.0.0.0-x64.exe`**。
   - BrandingDir 不传，默认 `BRANDING_DIR='.'` 即 `inno/defines.iss`（已含 rebrand：AppName=网信办公、Publisher=网信科技、Protocol=WX-office）。
3. 可选调 `make_advinst.ps1` → `.msi`（已改 `.aip` Protocol=WX-office）。

> Inno 原 `make_inno.ps1` 的 `-BuildDir` 只做存在性检查、**未转发给 iscc**；故本脚本用 junction 确保 Inno/AdvInst 都读对位置，不改动上游打包脚本。

### 2.4 默认语言（简体中文已内置）

「完全简体汉化」所需的源码改造**已全部落在 `rebrand/wangxin-1.0.0` 分支**，构建机直接构建即得中文产品，**无需在构建机再改任何本地化**：

- **默认界面语言 = 简体中文**：`win-linux/src/defines.h` 的 `APP_DEFAULT_LOCALE` 已由 `en-US` 改为 `zh-CN`；`clangater.cpp` 会自动在 `zh-CN` ↔ `zh_CN` 间匹配 `.qm`。
- **安装器中文**：`package/inno/common.iss` 已含 `zh_CN`（ChineseSimplified.isl）；安装器会把所选语言写入注册表 `locale=zh-CN`，中文 Windows 上自动选中中文向导，首启动即中文。
- **外壳翻译 100%**：`win-linux/langs/zh_CN.ts` 无空翻译 / 无 unfinished；`zh_CN.qm` 已编译存在。
- **编辑器 Web UI 中文**：`web-apps/apps/*/locale/zh.json`（document/spreadsheet/presentation/pdf 均存在）随外壳语言加载。
- **显示名中文化**：标题栏 / 应用名 = `网信办公`；关于面板应用名 = `网信办公 桌面编辑器`；版权 = `© 网信科技 … 保留所有权利。`；卸载项 = `网信办公 桌面编辑器`；官网链接 = `https://www.wx12345.com/`。

> 注意：注册表键名（`REG_GROUP_KEY=ONLYOFFICE`、`APP_DATA_PATH` 等）与数据目录路径**刻意未改**，以免丢失用户设置 / 破坏版本升级；仅改用户可见的显示字符串。

### 2.5 构建后校验（装完核对）
- [ ] 注册表 `HKEY_CLASSES_ROOT\WX-office` 存在（深链协议生效）
- [ ] **首启动界面为简体中文**（菜单/对话框/标题栏/关于面板无英文泄漏）
- [ ] **安装向导为中文**（下一步/完成等按钮中文）
- [ ] **编辑器内菜单为中文**（document/spreadsheet/presentation/pdf）
- [ ] 关于面板：应用名=`网信办公 桌面编辑器`、版权单行 `© 网信科技 … 保留所有权利。`（无双 ©）
- [ ] 安装目录 LICENSE.txt 含 AGPL 附加条款（662–728 行）
- [ ] 开始菜单/EXE 属性厂商=网信科技，无 ONLYOFFICE 商标

---

## 3. macOS：编译 + 打包

### 3.1 前置（构建机，macOS）
- **Xcode**（含 Command Line Tools）
- **Qt 5.15.x**（同 Windows 指定版本）
- **Ruby + Bundler**（macOS 目录含 `Gemfile`/`fastlane` → `bundle install`）
- 代码签名证书（如需签名/公证）

### 3.2 编译 + 打包
macOS 走 Xcode 工程：`desktop-apps/macos/ONLYOFFICE.xcodeproj`
```bash
cd desktop-apps/macos
bundle install            # 装 fastlane 等
# 用 Xcode 打开 ONLYOFFICE.xcodeproj，或：
xcodebuild -project ONLYOFFICE.xcodeproj -scheme ONLYOFFICE -configuration Release archive
# 产物签名/打包 .dmg 通常用 fastlane（Fastfile/Gemfile 已就位）
bundle exec fastlane <lane>   # 具体 lane 以仓库 fastlane 配置为准
```
> `macos/` 下无独立 .sh/.ps1 构建脚本，构建由 Xcode + fastlane 驱动；具体 lane 命令以 `macos/fastlane/Fastfile` 为准（本环境无 Mac 无法验证）。

### 3.3 构建后校验
- [ ] AppIcon 为网信办公图标（非 ONLYOFFICE）
- [ ] 显示名 / Bundle ID 正确
- [ ] 3 份 `Info.plist` 无 `SUFeedURL`/`SUPublicEDKey`（已移除）
- [ ] 关于面板含修改声明（NSHumanReadableCopyright 已含 wx12345.com）

---

## 4. 提交/打包纪律小结
- rebrand 改动**已全部在 `rebrand/wangxin-1.0.0` 并已推送 fork**，构建机直接基于该分支。
- 打出的安装包命名已含品牌（网信办公-DesktopEditors-…），LICENSE 含附加条款。
- 本环境只负责「代码 rebrand + 推 fork + 打包脚本/runbook」；**实际编译与出包在你的构建机**。

## 5. 待你确认/补充
- Windows 编译的确切 `configure.py` flag 与 MSBuild 目标（以 ONLYOFFICE 官方 Windows 构建文档为准，本环境无法验证）。
- macOS 的确切 fastlane lane 名称（读 `macos/fastlane/Fastfile`）。
- 如需要，我可把 `build_win_installer.ps1` 也提交进 fork 的 `desktop-apps`（作为 rebrand 工具脚本），或改成 Linux 也适用的统一入口。
