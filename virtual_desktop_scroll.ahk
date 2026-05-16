#Requires AutoHotkey v2
#SingleInstance Force

timeWindow := 200

lastTime := 0
lastDirection := ""
cooldown := false

#WheelUp::HandleDesktopScroll("Up")
#WheelDown::HandleDesktopScroll("Down")

HandleDesktopScroll(direction)
{
    global timeWindow
    global lastTime
    global lastDirection
    global cooldown

    ; Prevent rapid repeated switching
    if cooldown
        return

    currentTime := A_TickCount

    ; Detect double-scroll
    if (
        direction = lastDirection
        && currentTime - lastTime <= timeWindow
    )
    {
        ; Inverted direction:
        ; Wheel Up   -> Next desktop
        ; Wheel Down -> Previous desktop

        if direction = "Up"
        {
            Send("^#{Right}")
            ShowDesktopOSD("→ Next Desktop")
        }
        else
        {
            Send("^#{Left}")
            ShowDesktopOSD("← Previous Desktop")
        }

        ; Cooldown
        cooldown := true

        SetTimer(
            () => cooldown := false,
            -timeWindow
        )
    }

    ; Save scroll state
    lastTime := currentTime
    lastDirection := direction
}

ShowDesktopOSD(text)
{
    ToolTip(text)

    ; Hide tooltip after 700ms
    SetTimer(
        () => ToolTip(),
        -1000
    )
}