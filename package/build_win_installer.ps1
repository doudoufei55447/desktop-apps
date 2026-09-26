<#
.SYNOPSIS
    生成「网信办公」Windows 安装包（Inno Setup .exe，可选 Advanced Installer .msi）
.DESCRIPTION
    前置条件：已用 VS+Qt 编译出 app，产物位于某目录下的 desktop\ 子目录。
    本脚本把该目录通过目录 junction 挂到 desktop-apps\build\<arch>（Inno/AdvInst 的默认产物根），
    再调用仓库内 make_inno.ps1 / make_advinst.ps1 生成安装包。
    不修改上游打包脚本，junction 可逆（删除即还原）。
.PARAMETER Version
    四位版本号，例如 1.0.0.0（必填）
.PARAMETER Arch
    架构：x64（默认）/ x86 / arm64
.PARAMETER BuildDir
    已编译 app 所在目录（包含 desktop\ 子目录），绝对路径或相对 desktop-apps\package。
    若省略，按默认 desktop-apps\build\<arch> 处理（即你已把产物放到了规范位置）。
.PARAMETER RepoRoot
    WangXinOffice 仓库根目录；默认自动取“本脚本上级”。
.PARAMETER Target
    留空=社区版；可选 commercial / standalone / update / xp
.PARAMETER AdvInst
    同时生成 .msi（需要安装 Advanced Installer）
.PARAMETER Sign
    对安装包签名（需要证书与 signtool）
.EXAMPLE
    .\build_win_installer.ps1 -Version 1.0.0.0 -BuildDir D:\build\wxoffice-x64
    .\build_win_installer.ps1 -Version 1.0.0.0 -BuildDir D:\build\wxoffice-x64 -AdvInst -Sign
#>
param(
    [Parameter(Mandatory=$true)] [string]$Version,
    [string]$Arch = "x64",
    [string]$BuildDir,
    [string]$RepoRoot,
    [string]$Target = "",
    [switch]$AdvInst,
    [switch]$Sign
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    # 自动探测 WangXinOffice 顶层仓库根（脚本可放两处都能跑）：
    #   - 放 desktop-apps/package/ 内：向上两级即顶层；
    #   - 放 wangxin-office/ 工具目录（与 desktop-apps 同级）：本级即顶层。
    if (Test-Path (Join-Path $PSScriptRoot "make_inno.ps1")) {
        $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    } elseif (Test-Path (Join-Path $PSScriptRoot "desktop-apps\package\make_inno.ps1")) {
        $RepoRoot = Resolve-Path $PSScriptRoot
    } else {
        $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
    }
}
$pkg      = Join-Path $RepoRoot "desktop-apps\package"
$innoDir  = Join-Path $pkg "inno"
$advDir   = Join-Path $pkg "advinst"
if (-not (Test-Path $pkg)) { Write-Error "找不到 $pkg（请确认 RepoRoot 正确）"; exit 1 }

# ---- 规范产物根：desktop-apps\package\build\<arch> ----
# 注：make_inno.ps1 不转发 -BuildDir，iscc 读取的 {#BUILD_DIR} 默认是
# '..\build\'+ARCH（相对 inno/ 目录），即 desktop-apps\package\build\<arch>。
# 故 junction 必须建在此处，iscc 才能找到 {#BUILD_DIR}\desktop\*。
$normRoot = Join-Path $RepoRoot ("desktop-apps\package\build\" + $Arch)
$normDesktop = Join-Path $normRoot "desktop"

# ---- 把规范产物根 junction 指向真实构建目录（含 desktop\）----
if ($BuildDir) {
    $realDir = Resolve-Path $BuildDir
    if (-not (Test-Path (Join-Path $realDir "desktop"))) {
        Write-Error "BuildDir 下未找到 desktop\ 子目录：$realDir"
        exit 1
    }
    if (Test-Path $normRoot) {
        $item = Get-Item $normRoot
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            # 已是 junction，先删再重建
            cmd /c "rmdir `"$normRoot`"" | Out-Null
        } else {
            Write-Error "规范路径 $normRoot 已是真实目录且非空，请先移走或改用默认位置。"
            exit 1
        }
    } else {
        New-Item -ItemType Directory -Path (Split-Path $normRoot) -Force | Out-Null
    }
    Write-Host "==> 建立 junction: $normRoot -> $realDir"
    New-Item -ItemType Junction -Path $normRoot -Target $realDir | Out-Null
} else {
    if (-not (Test-Path $normDesktop)) {
        Write-Error "未找到 $normDesktop。请用 -BuildDir 指定已编译产物目录。"
        exit 1
    }
}

# ---- 检测 Inno Setup 6 ----
if (-not $env:INNOPATH) {
    $reg = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1"
    if (Test-Path $reg) { $env:INNOPATH = (Get-ItemProperty $reg)."Inno Setup: App Path" }
}
if (-not $env:INNOPATH -or -not (Test-Path $env:INNOPATH)) {
    Write-Error "未检测到 Inno Setup 6（HKLM 注册表或环境变量 INNOPATH）。请先安装。"
    exit 1
}

# ---- 调用 make_inno.ps1（BrandingDir 不传，默认 BRANDING_DIR='.' 即 inno\defines.iss，已含 rebrand）----
$innoParams = @{ Version = $Version; Arch = $Arch }
if ($Target) { $innoParams.Target = $Target }
if ($Sign)   { $innoParams.Sign = $true }
$env:Path = "$env:INNOPATH;$env:Path"
Write-Host "==> 生成 Inno 安装包 (make_inno.ps1)"
& "$pkg\make_inno.ps1" @innoParams
if ($LastExitCode -ne 0) { throw "Inno 构建失败（exit=$LastExitCode）" }
Write-Host "✅ Inno 安装包已生成：$(Join-Path $pkg ('网信办公-DesktopEditors-' + $Version + '-' + $Arch + '.exe'))"

# ---- 可选：Advanced Installer .msi ----
if ($AdvInst) {
    if (-not $env:ADVINSTPATH) {
        $areg = "HKLM:\SOFTWARE\WOW6432Node\Caphyon\Advanced Installer"
        if (Test-Path $areg) { $env:ADVINSTPATH = (Get-ItemProperty $areg)."InstallRoot" + "bin\x86" }
    }
    if (-not $env:ADVINSTPATH -or -not (Test-Path $env:ADVINSTPATH)) {
        Write-Warning "未检测到 Advanced Installer（跳过 .msi 生成）。"
    } else {
        $env:Path = "$env:ADVINSTPATH;$env:Path"
        $advParams = @{ Version = $Version; Arch = $Arch }
        if ($Target) { $advParams.Target = $Target }
        if ($Sign)   { $advParams.Sign = $true }
        Write-Host "==> 生成 AdvInst .msi (make_advinst.ps1)"
        & "$pkg\make_advinst.ps1" @advParams
        if ($LastExitCode -ne 0) { throw "AdvInst 构建失败（exit=$LastExitCode）" }
        Write-Host "✅ AdvInst .msi 已生成"
    }
}

Write-Host "`n完成。规范产物根 junction: $normRoot （构建结束后可手动删除：cmd /c rmdir `"$normRoot`"）"
