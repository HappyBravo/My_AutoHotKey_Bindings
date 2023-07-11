;Press F12 to hide or unhide desktop icons
F12::
ControlGet, HWND, Hwnd,, SysListView321, ahk_class Progman
If HWND =
ControlGet, HWND, Hwnd,, SysListView321, ahk_class WorkerW
If DllCall("IsWindowVisible", UInt, HWND)
WinHide, ahk_id %HWND%
Else
WinShow, ahk_id %HWND%
Return