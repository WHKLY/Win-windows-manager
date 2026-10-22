#Requires AutoHotkey v2.0
#SingleInstance Force

outputPath := A_Args.Length ? A_Args[1] : ""
MonitorGet(1, &monitorLeft, &monitorTop, &monitorRight, &monitorBottom)

normalGui := Gui("+Resize", "WWM Fullscreen Test Normal")
normalGui.AddText("w220 h70", "Normal test window")
normalGui.Show(Format(
    "NoActivate w360 h240 x{1} y{2}",
    monitorLeft + 120,
    monitorTop + 120
))

fullscreenGui := Gui("+Resize +AlwaysOnTop", "WWM Fullscreen Test Topmost")
fullscreenGui.AddText("w260 h80", "Topmost maximized test window")
fullscreenGui.Show(Format(
    "NoActivate w{1} h{2} x{3} y{4}",
    monitorRight - monitorLeft,
    monitorBottom - monitorTop,
    monitorLeft,
    monitorTop
))
DllCall("ShowWindowAsync", "Ptr", fullscreenGui.Hwnd, "Int", 3)
Sleep(80)

if (outputPath != "") {
    FileAppend(fullscreenGui.Hwnd "`n" normalGui.Hwnd, outputPath, "UTF-8")
}

SetTimer((*) => ExitApp(0), -3000)
