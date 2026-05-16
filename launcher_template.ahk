; THIS FILE IS A TEMPLATE... 
; COPY AND PASTE THIS FILE IN THE 'Startup' FOLDER. (TO OPEN STARTUP FOLDER : Win+R, shell:startup)
; OR MAKE A SHORTCUT OF THIS FILE AND PASTE IT IN THE 'Startup' FOLDER
; UPDATE THE SCRIPTS'S PATHS IN THIS FILE 

#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir ; In v2, everything is an expression. No % signs needed.

; =========================================================================
; 1. LAUNCH YOUR SCRIPTS
; =========================================================================
; If the scripts are in the same folder, simple filenames work perfectly:
Run("Script1_ComplexLogic.ahk")
Run("Script2_Shortcuts.ahk")

; If they are elsewhere, use absolute paths:
; Run("C:\Users\YourName\Documents\AHK\Script3_Background.ahk")


; =========================================================================
; 2. THE KILL SWITCH
; =========================================================================
; Press Ctrl + Shift + Alt + Escape to cleanly close the child scripts and this launcher.
^+!Esc:: {
    DetectHiddenWindows(true)
    SetTitleMatchMode(2) ; Allows matching the filename anywhere in the window title
    
    WM_COMMAND := 0x0111
    ID_FILE_EXIT := 65307
    
    ; 'try' statement prevents the script from crashing if a sub-script was already manually closed
    try PostMessage(WM_COMMAND, ID_FILE_EXIT, , , "Script1_ComplexLogic.ahk ahk_class AutoHotkey")
    try PostMessage(WM_COMMAND, ID_FILE_EXIT, , , "Script2_Shortcuts.ahk ahk_class AutoHotkey")
    
    ExitApp()
}