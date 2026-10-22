#Requires AutoHotkey v2.0
#SingleInstance Force

#Include ..\lib\Geometry.ahk
#Include ..\lib\Config.ahk
#Include ..\lib\Logger.ahk
#Include ..\lib\WindowRegistry.ahk
#Include ..\lib\LayoutPlanner.ahk
#Include ..\lib\LayoutExecutor.ahk
#Include ..\lib\LayoutHistory.ahk
#Include ..\lib\DoubleTapGesture.ahk
#Include ..\lib\WindowEvents.ahk
#Include ..\lib\WindowManagerApp.ahk

global FullscreenTestFailures := 0
global FullscreenTestCount := 0

runtimeDirectory := A_ScriptDir "\runtime\double-escape-fullscreen"
DirCreate(runtimeDirectory)
testConfigPath := runtimeDirectory "\config.ini"
testLogPath := runtimeDirectory "\logs\win-windows-manager.log"
if (FileExist(testLogPath)) {
    FileDelete(testLogPath)
}
FileCopy(A_ScriptDir "\..\config.ini", testConfigPath, true)
IniWrite("0", testConfigPath, "General", "Enabled")
IniWrite("0", testConfigPath, "General", "DryRun")
IniWrite("0", testConfigPath, "General", "ReflowOnNewWindow")
IniWrite("100", testConfigPath, "Motion", "SmoothDurationMs")
IniWrite("8", testConfigPath, "Motion", "SmoothFrameIntervalMs")
IniWrite("", testConfigPath, "Hotkeys", "Pause")
IniWrite("", testConfigPath, "Hotkeys", "ReflowCurrentMonitor")
IniWrite("", testConfigPath, "Hotkeys", "UndoLastLayout")
IniWrite("", testConfigPath, "Hotkeys", "ToggleLockActive")
IniWrite("", testConfigPath, "Hotkeys", "PlaceActive")
IniWrite("", testConfigPath, "Hotkeys", "ReloadConfig")

app := WindowManagerApp(runtimeDirectory)
helperPid := 0
app.Start()
try {
    outputPath := runtimeDirectory "\window-handles.txt"
    if (FileExist(outputPath)) {
        FileDelete(outputPath)
    }
    helperPid := Run(Format(
        '"{1}" "{2}" "{3}"',
        A_AhkPath,
        A_ScriptDir "\helpers\fullscreen_dual_host.ahk",
        outputPath
    ))

    Loop 50 {
        Sleep(100)
        if (FileExist(outputPath)) {
            break
        }
    }
    if (!FileExist(outputPath)) {
        throw Error("fullscreen helper did not produce window handles")
    }
    handles := StrSplit(Trim(FileRead(outputPath, "UTF-8")), "`n", "`r")
    fullHwnd := Trim(handles[1]) + 0
    normalHwnd := Trim(handles[2]) + 0
    Sleep(150)

    fullInfo := app.Registry.GetWindowInfo(fullHwnd, true)
    normalInfo := app.Registry.GetWindowInfo(normalHwnd, true)
    AssertFullscreen(fullInfo.eligible, "topmost fullscreen window is discoverable")
    AssertFullscreen(fullInfo.isFullscreen, "topmost window is classified as fullscreen")
    AssertFullscreen(fullInfo.isTopmost, "topmost style remains visible to classifier")
    AssertFullscreen(normalInfo.eligible, "normal companion window is discoverable")

    restoredCount := app.RestoreMaximizedWindowsForDoubleCaps(fullInfo.monitor)
    AssertFullscreen(restoredCount >= 1, "double CapsLock restores maximized window")
    Sleep(120)

    planInfo := app.BuildManualPlanForMonitor(
        fullInfo.monitor,
        fullHwnd,
        "manual_reflow",
        true
    )
    AssertFullscreen(planInfo && planInfo.plan.Valid, "fullscreen reflow plan is valid")
    AssertFullscreen(planInfo.plan.Targets.Has(fullInfo.id), "fullscreen window participates in plan")
    AssertFullscreen(planInfo.plan.Targets.Has(normalInfo.id), "normal windows participate in plan")

    result := app.ReflowMonitorForScope(
        true,
        "double_caps_fullscreen_test",
        fullInfo.monitor
    )
    Sleep(350)
    finalFullInfo := app.Registry.GetWindowInfo(fullHwnd, true)
    finalNormalInfo := app.Registry.GetWindowInfo(normalHwnd, true)
    AssertFullscreen(result && result.Success, "fullscreen reflow executes successfully")
    AssertFullscreen(!finalFullInfo.isMaximized, "fullscreen window is no longer maximized")
    AssertFullscreen(!finalFullInfo.isFullscreen, "fullscreen window is reduced")
    AssertFullscreen(finalFullInfo.isTopmost, "reflow preserves topmost style")
    AssertFullscreen(
        Geometry.IsWithin(finalFullInfo.rect, finalFullInfo.workArea, 2),
        "reduced fullscreen window remains on its monitor"
    )
    AssertFullscreen(finalNormalInfo.eligible, "normal window remains managed")
} catch Error as err {
    FileAppend("FAIL: integration error: " err.Message " at " err.File ":" err.Line "`n", "*", "UTF-8")
    FullscreenTestFailures += 1
}

if (helperPid) {
    try {
        ProcessClose(helperPid)
    }
}
app.HandleExit("double-caps-fullscreen-test", FullscreenTestFailures = 0 ? 0 : 1)

if (FullscreenTestFailures = 0) {
    FileAppend(Format("PASS: {1} fullscreen reflow tests`n", FullscreenTestCount), "*", "UTF-8")
    ExitApp(0)
}
FileAppend(Format("FAIL: {1} of {2} fullscreen reflow tests failed`n", FullscreenTestFailures, FullscreenTestCount), "*", "UTF-8")
ExitApp(1)

AssertFullscreen(condition, name) {
    global FullscreenTestCount
    global FullscreenTestFailures
    FullscreenTestCount += 1
    if (condition) {
        FileAppend("PASS: " name "`n", "*", "UTF-8")
    } else {
        FullscreenTestFailures += 1
        FileAppend("FAIL: " name "`n", "*", "UTF-8")
    }
}
