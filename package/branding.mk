# 网信办公 Linux 打包品牌覆盖 (Phase 2)
# 由 ONLYOFFICE Desktop Editors 9.4.0 (AGPL-3.0, (c) Ascensio System SIA) 修改而来。
#
# 保守策略：仅覆盖「厂商 / 支持」元数据，不动 COMPANY_NAME / PRODUCT_NAME，
# 以避免触及构建产物目录与安装前缀：
#   DESKTOPEDITORS_PREFIX := $(COMPANY_NAME_LOW)/$(PRODUCT_NAME_LOW)  ->  /opt/<company>/<product>
#   SOURCE_DIR            := ../../build_tools/out/$(PLATFORM)/$(COMPANY_NAME_LOW)
# 若把 COMPANY_NAME/PRODUCT_NAME 改成 wangxin/office，包名会变为 wangxin-office、
# 安装前缀变为 /opt/wangxin/office，且必须让 build_tools 同步输出到
# build_tools/out/<platform>/wangxin，否则构建失败；同时会失去上游
# %if "%{_company_name}" == "ONLYOFFICE" 分支带来的 -help 子包。
#
# 本文件随 fork 仓库提交（未被 .gitignore 忽略）。

PUBLISHER_NAME = 网信科技
PUBLISHER_URL  = https://www.wx12345.com
SUPPORT_URL    = https://www.wx12345.com
SUPPORT_MAIL   = bgrj@wx12345.com

# SCHEME_HANDLER 深链协议（"用本应用打开"）：须与 win-linux/src/defines.h APP_PROTOCOL、
# macos ASCConstants.h kSchemeApp、Windows defines.iss sAppProtocol、macOS plist CFBundleURLSchemes 完全一致，否则深链失效。
SCHEME_HANDLER = WX-office
