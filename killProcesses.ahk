#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================================
; AUTO ADMIN ELEVATION
; =========================================================

if !A_IsAdmin {
    Run '*RunAs "' A_ScriptFullPath '"'
    ExitApp
}

; =========================================================
; TOGGLE HOTKEY (Ctrl + Alt + K)
; =========================================================

global ScriptEnabled := true ; ON by default
global waitTime := 3 ; Minutes

^!k:: {
    global ScriptEnabled := !ScriptEnabled

    if ScriptEnabled {
        TrayTip("Background checking is now ON", "System Optimizer Resumed")
        SetTimer(() => TrayTip(), -3000)
        CheckRules() 
    } else {
        TrayTip("Optimizer OFF. Restoring Windows Update...", "System Optimizer Paused")
        SetTimer(() => TrayTip(), -3000)
        
        try {
            RunWait('sc config "UsoSvc" start= demand', , "Hide")
            RunWait('sc config "wuauserv" start= demand', , "Hide")
        }
    }
}

; =========================================================
; CONFIG RULES (ADD YOUR APPS HERE)
; =========================================================
; Available Conditions:
; - batteryOnly: true      (Only kill if unplugged)
; - whileGaming: true      (Only kill IF a game is running)
; - notWhileGaming: true   (Only kill IF no games are running)
;
; If 'conditions' is completely empty {}, the script will 
; ALWAYS kill those processes/services when it runs.
; =========================================================

; global RulesExamples := [

;     ; 1. HARDWARE MONITORS
;     {
;         name: "MSI Afterburner",
;         processes: ["MSIAfterburner.exe", "RTSS.exe"],
;         conditions: {
;             batteryOnly: true,
;             notWhileGaming: true
;         }
;     },

;     ; 2. BACKGROUND LAUNCHERS (Example: Free up RAM while gaming)
;     {
;         name: "Game Launchers",
;         processes: ["EpicGamesLauncher.exe", "GoGGalaxy.exe"],
;         conditions: {
;             whileGaming: true  ; Only kills these when a game starts
;         }
;     },

;     ; 3. HEAVY APPS ON BATTERY (Example: Kill Chrome if unplugged to save battery)
;     {
;         name: "Heavy Browsers",
;         processes: ["chrome.exe"],
;         conditions: {
;             batteryOnly: true
;             ; Since gaming conditions aren't mentioned, it ignores gaming status
;         }
;     },

;     ; 4. WINDOWS UPDATE (Always disable)
;     {
;         name: "Windows Update Services",
;         services: ["UsoSvc", "wuauserv"],
;         conditions: {} ; Empty means always apply
;     }
; ]

global Rules := [

    ; 1. HARDWARE MONITORS
    {
        name: "MSI Afterburner",
        processes: ["MSIAfterburner.exe", "RTSS.exe"],
        conditions: {
            batteryOnly: true,
            notWhileGaming: true
        }
    },

    ; 4. WINDOWS UPDATE (Always disable)
    {
        name: "Windows Update Services",
        services: ["UsoSvc", "wuauserv"],
        conditions: {} ; Empty means always apply
    }
]

; =========================================================
; START
; =========================================================

CheckRules()

; Run every 3 minutes (180,000 milliseconds)
SetTimer(CheckRules, waitTime * 60*1000)

Persistent

; =========================================================
; MAIN LOOP & LOGIC ENGINE
; =========================================================

CheckRules() {
    global Rules, ScriptEnabled

    if (!ScriptEnabled) {
        return
    }

    for rule in Rules {

        ; -------------------------------------------------
        ; PROCESS HANDLING
        ; -------------------------------------------------
        if rule.HasProp("processes") {

            ; Optimization: Only check logic if the apps are actually running
            anyRunning := false
            for proc in rule.processes {
                if ProcessExist(proc) {
                    anyRunning := true
                    break
                }
            }

            if (!anyRunning) {
                continue 
            }

            ; Default to true, try to find a reason NOT to kill it
            shouldKill := true

            if rule.HasProp("conditions") {
                
                ; Condition: Must be on battery
                if rule.conditions.HasProp("batteryOnly") && rule.conditions.batteryOnly {
                    if IsCharging()
                        shouldKill := false
                }

                ; Condition: Must be gaming
                if rule.conditions.HasProp("whileGaming") && rule.conditions.whileGaming {
                    if !IsFullscreenWindowPresent()
                        shouldKill := false
                }

                ; Condition: Must NOT be gaming
                if rule.conditions.HasProp("notWhileGaming") && rule.conditions.notWhileGaming {
                    if IsFullscreenWindowPresent()
                        shouldKill := false
                }
            }

            if shouldKill {
                for proc in rule.processes {
                    KillProcess(proc)
                }
            }
        }

        ; -------------------------------------------------
        ; SERVICE HANDLING
        ; -------------------------------------------------
        if rule.HasProp("services") {
            for svc in rule.services {
                DisableService(svc)
            }
        }
    }
}

; =========================================================
; CORE FUNCTIONS
; =========================================================

KillProcess(processName) {
    if ProcessExist(processName) {
        try {
            ProcessClose(processName)
            TrayTip("Closed background process: " processName, "System Optimizer")
        }
    }
}

DisableService(serviceName) {
    static wmi := ""
    try {
        if (!wmi) {
            wmi := ComObject("WbemScripting.SWbemLocator").ConnectServer(".", "root\cimv2")
        }
        
        for svc in wmi.ExecQuery("SELECT State, StartMode FROM Win32_Service WHERE Name='" serviceName "'") {
            actionTaken := false
            
            if (svc.StartMode != "Disabled") {
                RunWait('sc config "' serviceName '" start= disabled', , "Hide")
                actionTaken := true
            }
            if (svc.State = "Running") {
                RunWait('sc stop "' serviceName '"', , "Hide")
                actionTaken := true
            }
            if (actionTaken) {
                TrayTip("Disabled & Stopped: " serviceName, "System Optimizer")
            }
        }
    }
}

IsCharging() {
    PowerStatus := Buffer(12, 0)
    if DllCall("kernel32\GetSystemPowerStatus", "Ptr", PowerStatus) {
        acLineStatus := NumGet(PowerStatus, 0, "UChar")
        return (acLineStatus == 1)
    }
    return true 
}

IsFullscreenWindowPresent() {
    try {
        activeHwnd := WinExist("A")
        if !activeHwnd
            return false

        class := WinGetClass("ahk_id " activeHwnd)
        if (class = "Progman" || class = "WorkerW" || class = "Shell_TrayWnd")
            return false

        style := WinGetStyle("ahk_id " activeHwnd)
        WinGetPos(&x, &y, &w, &h, "ahk_id " activeHwnd)

        if (x <= 0 && y <= 0 && w >= A_ScreenWidth && h >= A_ScreenHeight) {
            if !(style & 0x00C00000) {
                return true
            }
        }
    } catch {
        return false
    }
    return false
}