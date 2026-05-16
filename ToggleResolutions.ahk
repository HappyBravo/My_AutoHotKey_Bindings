#Requires AutoHotkey v2.0

; ==============================================================================
; WINDOWS DISPLAY RESOLUTION & PROCESS AUTOMATION SCRIPT (AHK v2)
; Description: Toggles between two specific display resolutions, automatically 
;              finding and applying the highest available refresh rate for each.
;              Features background process monitoring to automatically scale 
;              resolution when specific apps launch, and restores native parameters
;              with a smart debounce delay when they close.
;              Specifically handles iGPU scaling issues (like "Center" scaling)
;              by forcing fullscreen stretching and registry updates.
; My usecase: I can toggle betwween the resolutions with one button. Reducing the 
;             display resolution for some games, so that i can play at high
;             game settings 😅
; ==============================================================================

; --- Auto-Execute: Request Admin Rights ---
; Modifying registry-level display settings often requires elevated privileges.
if !A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    ExitApp()
}

SetTitleMatchMode("RegEx")

; ==============================================================================
; USER CONFIGURATION
; Put your native resolutions here <<< -------- [ ‼️ IMPORTANT ‼️]
; Define your target resolutions here. 
; ==============================================================================
PrimaryW := 2560 
PrimaryH := 1600

; Secondary / Target Resolution (e.g., 1920x1080 for 16:9, or 1920x1200 for 16:10)
SecondaryW := 1920
SecondaryH := 1080

; Array of executables (RegEx enabled). 
; TargetProcesses := ["TargetGame\.exe", "AppEngine"] 
TargetProcesses := ["HTGame\.exe", "NTEGlobal"]

CheckInterval := 3000   ; 3 seconds
RevertDelay   := 15000  ; 15 seconds

; ==============================================================================
; PRE-COMPUTATION & CACHING (THE MAJOR OPTIMIZATION)
; ==============================================================================
; Combine array into a single fast RegEx string: e.g., "(TargetGame\.exe|AppEngine)"
global CombinedRegex := "(" 
for idx, proc in TargetProcesses {
    CombinedRegex .= proc . (idx = TargetProcesses.Length ? ")" : "|")
}

; Pre-calculate and cache the DEVMODE memory buffers for instant switching
global PrimaryModeBuffer   := CacheDisplayMode(PrimaryW, PrimaryH)
global SecondaryModeBuffer := CacheDisplayMode(SecondaryW, SecondaryH)

if (!PrimaryModeBuffer || !SecondaryModeBuffer) {
    MsgBox("CRITICAL ERROR: Could not find valid display modes for your specified resolutions.`nCheck your width/height settings.")
    ExitApp()
}

; ==============================================================================
; STATE GLOBALS & STARTUP
; ==============================================================================
global isSecondary          := false 
global autoTriggered        := false 
global manualOverride       := false 
global lastSeenTime         := 0     
global lastTriggeredProcess := ""    

SetTimer(MonitorProcesses, CheckInterval)

; ==============================================================================
; HOTKEYS
; ==============================================================================

; Win + Alt + S: The main toggle switch
#!s:: {
    global isSecondary, manualOverride, autoTriggered, lastTriggeredProcess
    SoundBeep(750, 200) 
    
    if !isSecondary {
        if ApplyCachedResolution(SecondaryModeBuffer) {
            isSecondary          := true
            manualOverride       := true  
            autoTriggered        := false 
            lastTriggeredProcess := "Manual Override"
            TrayTip("Display Scaled", "Manually switched to " SecondaryW "x" SecondaryH)
        }
    } else {
        if ApplyCachedResolution(PrimaryModeBuffer) {
            isSecondary          := false
            manualOverride       := true  
            autoTriggered        := false
            lastTriggeredProcess := ""
            TrayTip("Display Restored", "Manually reverted to native " PrimaryW "x" PrimaryH)
        }
    }
}

; Win + Alt + 0: The "Panic Button" Emergency Reset
; Bypasses the script's logic and tells Windows to reload its default hardware state.
#!0:: {
    global isSecondary, manualOverride, autoTriggered, lastTriggeredProcess
    if ApplyCachedResolution(PrimaryModeBuffer) {
        isSecondary          := false
        manualOverride       := true  
        autoTriggered        := false
        lastTriggeredProcess := ""
        SoundBeep(400, 500)
        TrayTip("Panic Button Activated", "Display forced to native parameters.")
    }
}

; ==============================================================================
; AUTOMATION ENGINE
; ==============================================================================

MonitorProcesses() {
    global isSecondary, autoTriggered, manualOverride, lastSeenTime, lastTriggeredProcess
    
    ; Immediately halt monitoring execution if explicit manual control is active
    if manualOverride 
        return

    ; --- Smart Idle Check ---
    ; If AFK for 3 minutes, slow polling to 10 seconds to save CPU
    if (A_TimeIdlePhysical > 180000) {
        SetTimer(, 10000)
        return
    } else {
        SetTimer(, CheckInterval) ; Restore normal speed when active
    }

    ; --- Fast Regex Window Check ---
    ; Evaluates all target games simultaneously in a single Win32 API call
    targetHwnd := WinExist("ahk_exe i)" . CombinedRegex)
    processFound := (targetHwnd != 0)
    
    if (manualOverride) {
        if (!processFound) {
            manualOverride := false 
            TrayTip("Automation Re-Armed", "Monitoring initialized.")
        }
        return
    }

    ; --- Primary Automation Handling ---
    if (processFound) {
        lastSeenTime := A_TickCount 
        
        if (!isSecondary) {
            lastTriggeredProcess := WinGetProcessName("ahk_id " targetHwnd)
            
            if ApplyCachedResolution(SecondaryModeBuffer) {
                isSecondary   := true
                autoTriggered := true
                TrayTip("Process Launched: " . lastTriggeredProcess, "Scaled to " SecondaryW "x" SecondaryH)
            }
        }
    } 
    else if (!processFound && isSecondary && autoTriggered) {
        if ((A_TickCount - lastSeenTime) >= RevertDelay) {
            closedProcess := lastTriggeredProcess != "" ? lastTriggeredProcess : "Target application"
            
            if ApplyCachedResolution(PrimaryModeBuffer) {
                isSecondary          := false
                autoTriggered        := false
                lastTriggeredProcess := ""
                TrayTip("Session Ended: " . closedProcess, "Restored native resolution.")
            }
        }
    }
}

; ==============================================================================
; CORE FUNCTIONS & WIN32 API LOGIC
; ==============================================================================

; Runs ONLY on script startup. Finds the highest Hz for a resolution and saves the memory block.
CacheDisplayMode(w, h) {
    devMode := Buffer(220, 0)
    
    ; NumPut writes data to specific byte offsets within our buffer.
    ; Offset 68 (dmSize) tells the API how large our structure is.
    NumPut("UShort", 220, devMode, 68) 
    
    bestHz := 0
    bestModeBuffer := ""
    modeNum := 0
    
    ; --- STEP 1: Scan for the Best Refresh Rate ---
    ; EnumDisplaySettingsW queries the graphics driver for every supported display mode.
    ; We loop through all of them (modeNum 0, 1, 2, etc.) until the API returns 0 (false).
    while DllCall("EnumDisplaySettingsW", "Ptr", 0, "UInt", modeNum, "Ptr", devMode) {
        curW  := NumGet(devMode, 172, "UInt") 
        curH  := NumGet(devMode, 176, "UInt") 
        curHz := NumGet(devMode, 120, "UInt") 
        
        ; If the mode matches our target width and height...
        if (curW = w && curH = h) {
            ; ...and the refresh rate is higher than or equal to our previous best...
            if (curHz >= bestHz) {
                bestHz := curHz
                
                ; Clone the entire 220-byte buffer into 'bestModeBuffer'.
                ; We must do this because the next loop iteration will overwrite 'devMode'.
                bestModeBuffer := Buffer(220)
                DllCall("RtlMoveMemory", "Ptr", bestModeBuffer, "Ptr", devMode, "UInt", 220)
            }
        }
        modeNum++
    }
    return bestModeBuffer
}

; Instantly applies a pre-cached memory block. Zero calculations needed.
ApplyCachedResolution(cachedBuffer) {
    if (!cachedBuffer)
        return false
    ;
    ; FLAGS USED:
    ; 0x1 (CDS_UPDATEREGISTRY): Saves the change to the Windows registry. This forces
    ;                           Windows to remember scaling settings and prevents the
    ;                           change from reverting dynamically.
    ; 0x4 (CDS_FULLSCREEN):     Instructs the driver to scale the image to fill the
    ;                           entire screen, overriding "Centered" iGPU behaviors
    ;                           that cause thick black borders.
        
    result := DllCall("ChangeDisplaySettingsW", "Ptr", cachedBuffer, "UInt", 0x1 | 0x4)
    return (result = 0)
    } 

; FOR FURTHER READING 
; DllCall()                      : https://www.autohotkey.com/docs/v2/lib/DllCall.htm
; EnumDisplaySettingsW           : https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-enumdisplaysettingsw
; EnumDisplaySettingsW functions : https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-enumdisplaysettingsw
; DEVMODEW Structure             : https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-devmodew

; MADE WITH GEMINI 🤖
