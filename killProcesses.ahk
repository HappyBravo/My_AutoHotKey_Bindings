#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================================
; AUTO ADMIN ELEVATION
; =========================================================

if !A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    ExitApp()
}

; =========================================================
; TOGGLE HOTKEY (Ctrl + Alt + K)
; =========================================================

global ScriptEnabled := true ; ON by default
global baseWaitTime  := 3    ; Base check interval in minutes

^!k:: {
    global ScriptEnabled := !ScriptEnabled

    if ScriptEnabled {
        TrayTip("Background checking is now ON", "System Optimizer Resumed")
        SetTimer(() => TrayTip(), -3000)
        
        ; Kickstart the engine immediately upon unpausing
        SetTimer(CheckRules, -1) 
    } else {
        TrayTip("Optimizer OFF. Restoring Windows Update...", "System Optimizer Paused")
        SetTimer(() => TrayTip(), -3000)
        
        ; Turn off the timer completely
        SetTimer(CheckRules, 0)
        
        try {
            RunWait('sc config "UsoSvc" start= demand', , "Hide")
            RunWait('sc config "wuauserv" start= demand', , "Hide")
        }
    }
}

; =========================================================
; CONFIG RULES
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
    ; 2. WINDOWS UPDATE (Always disable)
    {
        name: "Windows Update Services",
        services: ["UsoSvc", "wuauserv"],
        conditions: {} 
    }
]

; =========================================================
; STARTUP
; =========================================================

; Run the first check instantly, then the timer self-manages
SetTimer(CheckRules, -1) 
Persistent()

; =========================================================
; MAIN LOOP & LOGIC ENGINE
; =========================================================

CheckRules() {
    global Rules, ScriptEnabled, baseWaitTime

    if (!ScriptEnabled) {
        return
    }

    ; -------------------------------------------------------------
    ; OPTIMIZATION 1: IDLE & BATTERY SMART SCALING
    ; -------------------------------------------------------------
    baseMs := baseWaitTime * 60 * 1000
    isPluggedIn := IsCharging()

    ; If no physical input for 5 minutes, enter Deep Sleep (Check every 10 mins)
    if (A_TimeIdlePhysical > 300000) {
        SetTimer(, baseMs * 3.33) 
        return ; Skip all heavy WMI and Process logic while away
    }

    ; Scale timer based on power state
    if (isPluggedIn) {
        SetTimer(, baseMs)       ; 3 Minutes on AC Power
    } else {
        SetTimer(, baseMs * 2)   ; 6 Minutes on Battery
    }

    ; -------------------------------------------------------------
    ; OPTIMIZATION 2: CACHE SYSTEM STATE ONCE PER CYCLE
    ; -------------------------------------------------------------
    ; Instead of querying the screen for every rule, check it once.
    isGaming := IsFullscreenWindowPresent()

    ; -------------------------------------------------------------
    ; RULE EVALUATION
    ; -------------------------------------------------------------
    for rule in Rules {

        ; --- PROCESS HANDLING ---
        if rule.HasProp("processes") {
            
            ; 1. Are any of the target processes even running?
            anyRunning := false
            for proc in rule.processes {
                if ProcessExist(proc) {
                    anyRunning := true
                    break
                }
            }

            ; If not running, skip condition checks entirely
            if (!anyRunning) {
                continue 
            }

            ; 2. Evaluate Conditions against our cached states
            shouldKill := true

            if rule.HasProp("conditions") {
                conds := rule.conditions
                
                if conds.HasProp("batteryOnly") && conds.batteryOnly && isPluggedIn
                    shouldKill := false
                
                if conds.HasProp("whileGaming") && conds.whileGaming && !isGaming
                    shouldKill := false
                
                if conds.HasProp("notWhileGaming") && conds.notWhileGaming && isGaming
                    shouldKill := false
            }

            ; 3. Execute
            if shouldKill {
                for proc in rule.processes {
                    KillProcess(proc)
                }
            }
        }

        ; --- SERVICE HANDLING ---
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
        return (acLineStatus == 1) ; 1 = AC, 0 = Battery
    }
    return true ; Default to true if call fails to prevent accidental kills
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
            if !(style & 0x00C00000) { ; 0x00C00000 is WS_CAPTION
                return true
            }
        }
    } catch {
        return false
    }
    return false
}