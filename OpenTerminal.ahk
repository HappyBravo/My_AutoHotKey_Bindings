#Requires AutoHotkey v2

^!t::
{
    hwnd := WinExist("ahk_exe WindowsTerminal.exe")

    if !hwnd
        Run("wt")
    else if WinActive("ahk_id " hwnd)
        WinMinimize("ahk_id " hwnd)
    else
    {
        WinRestore("ahk_id " hwnd)
        WinActivate("ahk_id " hwnd)
    }
}