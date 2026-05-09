#Requires AutoHotkey v2.0

; ==============================================================================
; WINDOWS DISPLAY RESOLUTION TOGGLE SCRIPT (AHK v2)
; Description: Toggles between two specific display resolutions, automatically 
;              finding and applying the highest available refresh rate for each.
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

; ==============================================================================
; HOTKEYS
; ==============================================================================

; Win + Alt + S: The main toggle switch
#!s:: {
    static isSecondary := false
    SoundBeep(750, 200) ; Auditory feedback that the keypress registered
    
    if !isSecondary {
        ; Attempt to apply the secondary resolution
        if ApplyResolution(SecondaryW, SecondaryH) {
            isSecondary := true
        } else {
            MsgBox("Failed to set " SecondaryW "x" SecondaryH ".")
        }
    } else {
        ; Revert to the primary/native resolution
        if ApplyResolution(PrimaryW, PrimaryH) {
            isSecondary := false
        } else {
            MsgBox("Failed to revert to " PrimaryW "x" PrimaryH ".")
        }
    }
}

; Win + Alt + 0: The "Panic Button" Emergency Reset
; Bypasses the script's logic and tells Windows to reload its default hardware state.
#!0:: {
    global isSecondary
    ; Explicitly force the native resolution instead of relying on the registry
    if ApplyResolution(PrimaryW, PrimaryH) {
        isSecondary := false ; Reset the toggle state
        SoundBeep(400, 500)
    } else {
        MsgBox("Panic Button failed to force " PrimaryW "x" PrimaryH ".")
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
