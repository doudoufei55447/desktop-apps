; -- 网信办公 Defines --

#define sCompanyName                    "网信办公"
#define sIntCompanyName                 sCompanyName
#define sProductName                    "桌面编辑器"
#define sIntProductName                 "DesktopEditors"
#define sAppName                        str(sCompanyName)
#define sPackageName                    str(sIntCompanyName + "-" + sIntProductName)
#define sAppPublisher                   "网信科技"
#define sAppPublisherURL                "https://www.wx12345.com/"
#define sAppSupportURL                  "https://www.wx12345.com/support.aspx"
#define sAppCopyright                   str("© " + sAppPublisher + " " + GetDateTimeString("yyyy",,) + ". All rights reserved.")
#define sAppIconName                    "网信办公"
#define sOldAppIconName                 "网信办公"
#define sAppProtocol                    'WX-office'

#define APP_PATH                        str(sIntCompanyName + "\" + sIntProductName)
#define UPD_PATH                        str(sIntProductName + "Updates")
#define APP_REG_PATH                    str("Software\" + APP_PATH)
#define APP_REG_UNINST_KEY              str(sCompanyName + " " + sProductName)
#define APP_USER_MODEL_ID               "ASC.Documents.5"
#define APP_MUTEX_NAME                  "TEAMLAB"
#define APPWND_CLASS_NAME               "DocEditorsWindowClass"

#define iconsExe                        "DesktopEditors.exe"
#define NAME_EXE_OUT                    "editors.exe"

#define ASSC_APP_NAME                   "网信办公"
#define ASCC_REG_PREFIX                 "ASC"
#define ASCC_REG_REGISTERED_APP_NAME    "网信办公"
#define ASSOC_PROG_ID                   "ASC.Editors"
#define ASSOC_APP_FRIENDLY_NAME         "网信办公"
