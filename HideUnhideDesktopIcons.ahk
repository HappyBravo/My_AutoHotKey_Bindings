#Requires AutoHotKey v2

; Ctrl+Alt+H to hide/unhide desktop icons
^!h::
{
    hwnd := GetDesktopIconsHwnd()

    if hwnd
        DllCall("ShowWindow", "Ptr", hwnd, "Int"
            , DllCall("IsWindowVisible", "Ptr", hwnd) ? 0 : 5)
}

GetDesktopIconsHwnd()
{
    for className in ["Progman", "WorkerW"]
    {
        try
            return ControlGetHwnd("SysListView321", "ahk_class " className)
    }

    return 0
}
