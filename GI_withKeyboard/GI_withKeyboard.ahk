#Requires AutoHotkey v2.0 

Persistent

; App to check 
App1 := "ahk_exe ZenlessZoneZero.exe"
App2 := "ahk_exe GenshinImpact.exe"

#SingleInstance Force

; check if GI or ZZZ is running or not after every 1 sec
SetTimer checkApps.Bind(App1, App2), 1000 

SetTitleMatchMode 2

isAppRunning := false

; Rerun script with administrator rights if required.
if (!A_IsAdmin) {
    try {
        ; Run *RunAs "%A_ScriptFullPath%"
        Run '*RunAs "' A_ScriptFullPath '"'
    } catch Error as e {
        MsgBox Format("Error {1} ,Failed to run script with administrator rights", e.Message)
        ExitApp
    }
}

checkApps(App1, App2){
    global isAppRunning

    ; If ((WinExist(App1) and WinActive(App1)) 
    ;     or (WinExist(App2) and WinActivate(App2))){

    If (WinWaitActive(App1,,2) or WinWaitActive(App2,,2)){
        ; MsgBox Format("App1 or App2 exists")
        isAppRunning := true
    }
    else{
        ; MsgBox Format("App1 or App2 does not exists")
        isAppRunning := false
    }
}

strongAttack() {
    ; WinWaitActive(App1,,2) or WinWaitActive(App2,, 2)

    Click "Down"
    ; KeyWait "RButton", "D"
    TimeSinceKeyPressed := A_TimeSinceThisHotkey
    if (TimeSinceKeyPressed < 350) {
        ; hold LMB minimum for 350ms
        Sleep (350 - TimeSinceKeyPressed)
    }
    Click "Up"
}

spamAttacks(){
    ; WinWaitActive(App1,,2) or WinWaitActive(App2,, 2)

    while(GetKeyState("Left" ,"P")) {
        MouseClick "left"
        Sleep 20
    }
}

dodgeOrToggleRun(){
    while (GetKeyState("Right" ,"P")){
        MouseClick "Right"
        Sleep 20
    }
}

; dodgeOrToggleRun(){
;     ; WinWaitActive(App1,,2) or WinWaitActive(App2,, 2)
;     isDown := false
;     TimeSinceKeyPressed := A_TimeSinceThisHotkey

;     while(GetKeyState("Right" ,"P")) {
;         Click "Down right"
;         isDown := true
        
;         if (TimeSinceKeyPressed < 350) {
;             while (GetKeyState("Right" ,"P")){
;                 ; hold LMB minimum for 350ms
;                 ; Click "Down right"
;                 Sleep (350 - TimeSinceKeyPressed)
;                 ; Click "Up right"
;             }
;         }

;         Sleep 20

;         Click "Up right"
;         isDown := false
;     }

;     if isDown{
;         Click "Up right"
;     }
; }

; mapping Middle Mouse button to V button for elemental view in Genshin
elementalView(){
    if WinActive(App2,,2) {
        while (GetKeyState('v', "P")){
            Click "Down Middle"
            Sleep 1000
        }
        Click "Up Middle" 
    }
}

#HotIf isAppRunning
    Left::{
        spamAttacks()
        return
    }
    Down::{
        strongAttack()
        return
    }
    Right::{
        dodgeOrToggleRun()
        return
    }
    v::{
        elementalView()
        return
    }
#HotIf 
