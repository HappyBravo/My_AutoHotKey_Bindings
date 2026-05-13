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

; Enable Regular Expressions for highly flexible process matching in the array
SetTitleMatchMode("RegEx")

; ==============================================================================
; USER CONFIGURATION
; Put your native resolutions here <<< -------- [ ‼️ IMPORTANT ‼️]
; Define your target resolutions here. 
; ==============================================================================

; Primary / Native Resolution (e.g., 2560x1600 for 16:10 displays)
PrimaryW := 2560 
PrimaryH := 1600

; Secondary / Target Resolution (e.g., 1920x1080 for 16:9, or 1920x1200 for 16:10)
SecondaryW := 1920
SecondaryH := 1080

; --- Process Automation Settings ---
; Target executables to monitor. Backslash escapes literal dots for RegEx safety.
; List of processes (RegEx enabled). 
TargetProcesses := ["TargetGame\.exe", "AppEngine"] 

; --- Timing & Debounce Parameters ---
CheckInterval := 3000   ; Scanner frequency: Evaluates process list every 3 seconds
RevertDelay   := 15000  ; Hysteresis buffer: Delays recovery by 15 seconds to prevent flicker

; ==============================================================================
; STATE MACHINE GLOBALS
; ==============================================================================

global isSecondary          := false ; Active resolution status
global autoTriggered        := false ; True if the script initiated the switch automatically
global manualOverride       := false ; True if the user engaged manual control
global lastSeenTime         := 0     ; Timestamp tracking when a process was last visible
global lastTriggeredProcess := ""    ; Caches the exact executable string for dynamic tooltips

; Initialize persistent background monitoring loop
SetTimer(MonitorProcesses, CheckInterval)

; ==============================================================================
; HOTKEYS
; ==============================================================================

; Win + Alt + S: The main toggle switch
#!s:: {
    global isSecondary, manualOverride, autoTriggered, lastTriggeredProcess
    
    SoundBeep(750, 200) ; Auditory confirmation
    
    if !isSecondary {
        if ApplyResolution(SecondaryW, SecondaryH) {
            isSecondary          := true
            manualOverride       := true  ; Engage manual lock to pause automation scans
            autoTriggered        := false 
            lastTriggeredProcess := "Manual Override"
            TrayTip("Display Scaled", "Manually switched to " SecondaryW "x" SecondaryH)
        } else {
            MsgBox("Failed to set " SecondaryW "x" SecondaryH ".")
        }
    } else {
        if ApplyResolution(PrimaryW, PrimaryH) {
            isSecondary          := false
            manualOverride       := true  ; Retain manual lock to prevent immediate auto-triggering
            autoTriggered        := false
            lastTriggeredProcess := ""
            TrayTip("Display Restored", "Manually reverted to native " PrimaryW "x" PrimaryH)
        } else {
            MsgBox("Failed to revert to " PrimaryW "x" PrimaryH ".")
        }
    }
}

; Win + Alt + 0: The "Panic Button" Emergency Reset
; Bypasses the script's logic and tells Windows to reload its default hardware state.
#!0:: {
    global isSecondary, manualOverride, autoTriggered, lastTriggeredProcess
    
    ; Explicitly force native targets to bypass broken registry defaults
    if ApplyResolution(PrimaryW, PrimaryH) {
        isSecondary          := false
        manualOverride       := true  ; Lock logic engine to stabilize recovery
        autoTriggered        := false
        lastTriggeredProcess := ""
        SoundBeep(400, 500)
        TrayTip("Panic Button Activated", "Display forced to native parameters. Automation paused.")
    } else {
        MsgBox("Panic Button failed to force " PrimaryW "x" PrimaryH ".")
    }
}


; ==============================================================================
; AUTOMATION ENGINE (PROCESS MONITORING & HYSTERESIS)
; ==============================================================================

MonitorProcesses() {
    global isSecondary, autoTriggered, manualOverride, lastSeenTime, lastTriggeredProcess
    
    ; Immediately halt monitoring execution if explicit manual control is active
    if manualOverride 
        return

    processFound := false
    currentProcessName := ""
    
    ; Scan active window contexts against the configured RegEx array
    for processPattern in TargetProcesses {
        if WinExist("ahk_exe i)" . processPattern) {
            processFound := true
            ; Capture exact literal executable string from OS memory matrices
            currentProcessName := WinGetProcessName() 
            break
        }
    }

    ; --- Smart Re-Arming Logic ---
    ; If the user forced an override while an app ran, keep automation asleep 
    ; until the app fully closes. Once clear, gracefully lift the block.
    if (manualOverride) {
        if (!processFound) {
            manualOverride := false 
            TrayTip("Automation Re-Armed", "Monitoring initialized for subsequent execution.")
        }
        return
    }

    ; --- Primary Automation Handling ---
    if (processFound) {
        lastSeenTime := A_TickCount ; Continuously update active validation tick
        
        if (!isSecondary) {
            lastTriggeredProcess := currentProcessName
            
            if ApplyResolution(SecondaryW, SecondaryH) {
                isSecondary   := true
                autoTriggered := true
                TrayTip("Process Launched: " . lastTriggeredProcess, "Scaled to " SecondaryW "x" SecondaryH " for optimal output.")
            }
        }
    } 
    ; --- Automated Recovery (Debouncing Phase) ---
    else if (!processFound && isSecondary && autoTriggered) {
        
        ; Verify elapsed continuous absence exceeds configured hysteresis limits
        if ((A_TickCount - lastSeenTime) >= RevertDelay) {
            
            closedProcess := lastTriggeredProcess != "" ? lastTriggeredProcess : "Target application"
            
            if ApplyResolution(PrimaryW, PrimaryH) {
                isSecondary          := false
                autoTriggered        := false
                lastTriggeredProcess := ""
                TrayTip("Session Ended: " . closedProcess, "Restored native resolution (" PrimaryW "x" PrimaryH ").")
            }
        }
    }
}



; ==============================================================================
; CORE FUNCTIONS & WIN32 API LOGIC
; ==============================================================================

ApplyResolution(w, h) {
    ; Windows requires display data to be passed in a specific C-style struct 
    ; called DEVMODE (Device Mode). For modern Windows, its size is 220 bytes.
    ; AHK's 'Buffer' creates this chunk of memory.
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
        
        ; NumGet extracts data from the buffer populated by the graphics driver.
        curW  := NumGet(devMode, 172, "UInt") ; dmPelsWidth  (Pixels wide)
        curH  := NumGet(devMode, 176, "UInt") ; dmPelsHeight (Pixels high)
        curHz := NumGet(devMode, 120, "UInt") ; dmDisplayFrequency (Refresh rate)
        
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
    
    ; --- STEP 2: Apply the Resolution ---
    if (bestModeBuffer) {
        ; ChangeDisplaySettingsW sends our chosen DEVMODE buffer back to the driver.
        ; 
        ; FLAGS USED:
        ; 0x1 (CDS_UPDATEREGISTRY): Saves the change to the Windows registry. This forces
        ;                           Windows to remember scaling settings and prevents the 
        ;                           change from reverting dynamically.
        ; 0x4 (CDS_FULLSCREEN):     Instructs the driver to scale the image to fill the 
        ;                           entire screen, overriding "Centered" iGPU behaviors 
        ;                           that cause thick black borders.
        
        result := DllCall("ChangeDisplaySettingsW", "Ptr", bestModeBuffer, "UInt", 0x1 | 0x4)
        
        ; Return true if the API call was successful (result = 0 is DISP_CHANGE_SUCCESSFUL)
        return (result = 0)
    }
    
    ; Return false if the requested resolution was not found in the driver's list at all.
    return false
}

; FOR FURTHER READING 
; DllCall()                      : https://www.autohotkey.com/docs/v2/lib/DllCall.htm
; EnumDisplaySettingsW           : https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-enumdisplaysettingsw
; EnumDisplaySettingsW functions : https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-enumdisplaysettingsw
; DEVMODEW Structure             : https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-devmodew

; MADE WITH GEMINI 🤖
