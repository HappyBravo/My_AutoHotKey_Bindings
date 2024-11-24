#Persistent  ; Keep the script running

timeWindow := 200  ; Time window for detecting double scroll (in milliseconds)
lastScrollTime := 0  ; Timestamp of the last scroll
scrollDirection := ""  ; Keeps track of the direction (up or down)
isSwitching := false  ; Prevents immediate double switches

; Set the hotkey for Win + Scroll Up to detect the scroll and change to next virtual desktop if two scrolls are detected within 0.2 seconds
#WheelUp::
    if GetKeyState("LWin", "P") ; Check if the Win key is pressed
    {
        ; Check if we're not in the middle of a switch
        if (isSwitching)
            return
        
        ; Get the current time
        currentTime := A_TickCount
        if (currentTime - lastScrollTime <= timeWindow) ; Check if the last scroll was within the time window
        {
            ; If it's the same direction (scroll up), move to the next desktop
            if (scrollDirection = "Up")
            {
                Send, #^{Left}  ; Switch to the left virtual desktop
                isSwitching := true  ; Prevent another switch immediately
                Sleep, %timeWindow%  ; Wait for the time window to avoid rapid scrolling
                isSwitching := false  ; Allow switching again after the pause
            }
        }
        ; Update last scroll time and direction
        lastScrollTime := currentTime
        scrollDirection := "Up"
    }
    return

; Set the hotkey for Win + Scroll Down to detect the scroll and change to next virtual desktop if two scrolls are detected within 0.2 seconds
#WheelDown::
    if GetKeyState("LWin", "P") ; Check if the Win key is pressed
    {
        ; Check if we're not in the middle of a switch
        if (isSwitching)
            return
        
        ; Get the current time
        currentTime := A_TickCount
        if (currentTime - lastScrollTime <= timeWindow) ; Check if the last scroll was within the time window
        {
            ; If it's the same direction (scroll down), move to the next desktop
            if (scrollDirection = "Down")
            {
                Send, #^{Right}  ; Switch to the right virtual desktop
                isSwitching := true  ; Prevent another switch immediately
                Sleep, %timeWindow%  ; Wait for the time window to avoid rapid scrolling
                isSwitching := false  ; Allow switching again after the pause
            }
        }
        ; Update last scroll time and direction
        lastScrollTime := currentTime
        scrollDirection := "Down"
    }
    return
