#Requires AutoHotkey v2.0
#SingleInstance Force

#Include ..\lib\Geometry.ahk
#Include ..\lib\Config.ahk
#Include ..\lib\Logger.ahk
#Include ..\lib\WindowRegistry.ahk
#Include ..\lib\LayoutPlanner.ahk
#Include ..\lib\LayoutExecutor.ahk
#Include ..\lib\LayoutHistory.ahk
#Include ..\lib\WindowEvents.ahk
#Include ..\lib\WindowManagerApp.ahk

global ManualTestFailures := 0
global ManualTestCount := 0

runtimeDirectory := A_ScriptDir "\runtime\manual-undo"
DirCreate(runtimeDirectory)
testConfigPath := runtimeDirectory "\config.ini"
testLogPath := runtimeDirectory "\logs\windowswindowsmanager.log"
if (FileExist(testLogPath)) {
    FileDelete(testLogPath)
}
FileCopy(A_ScriptDir "\..\config.ini", testConfigPath, true)
IniWrite("0", testConfigPath, "General", "Enabled")
IniWrite("0", testConfigPath, "General", "DryRun")
IniWrite("0", testConfigPath, "General", "ReflowOnNewWindow")
IniWrite("80", testConfigPath, "Motion", "SmoothDurationMs")
IniWrite("16", testConfigPath, "Motion", "SmoothFrameIntervalMs")
IniWrite("160", testConfigPath, "Motion", "SmoothMaxDurationMs")
IniWrite("", testConfigPath, "Hotkeys", "Pause")
IniWrite("", testConfigPath, "Hotkeys", "ReflowCurrentMonitor")
IniWrite("", testConfigPath, "Hotkeys", "UndoLastLayout")
IniWrite("", testConfigPath, "Hotkeys", "ToggleLockActive")
IniWrite("", testConfigPath, "Hotkeys", "PlaceActive")
IniWrite("", testConfigPath, "Hotkeys", "ReloadConfig")

originalForeground := DllCall("GetForegroundWindow", "Ptr")
app := WindowManagerApp(runtimeDirectory)
helperPid := 0
helperHwnd := 0

try {
    app.Start()
    helperPath := A_ScriptDir "\helpers\window_host.ahk"
    helperOutput := runtimeDirectory "\helper-hwnd.txt"
    if (FileExist(helperOutput)) {
        FileDelete(helperOutput)
    }
    helperPid := Run(Format('"{1}" "{2}" "{3}"', A_AhkPath, helperPath, helperOutput))

    Loop 40 {
        Sleep(100)
        if (FileExist(helperOutput)) {
            helperHwnd := Trim(FileRead(helperOutput, "UTF-8")) + 0
        }
        if (helperHwnd && app.Registry.IsValidWindow(helperHwnd)) {
            break
        }
    }
    if (!helperHwnd) {
        throw Error("helper window did not appear")
    }

    WinActivate("ahk_id " helperHwnd)
    Sleep(120)
    originalRect := app.Registry.GetWindowRect(helperHwnd)

    lockState := app.Registry.ToggleLock(helperHwnd)
    lockedPlanInfo := app.BuildManualPlanForMonitor(
        app.Registry.GetWindowInfo(helperHwnd).monitor,
        helperHwnd,
        "manual_reflow"
    )
    app.ExecutePlan(
        lockedPlanInfo.windows,
        lockedPlanInfo.plan,
        "manual_reflow",
        "manual_locked_test"
    )
    Sleep(260)
    lockedRect := app.Registry.GetWindowRect(helperHwnd)
    AssertManual(lockState = 1, "manual lock toggles on")
    AssertManual(Geometry.Equal(lockedRect, originalRect, 1), "manual reflow preserves locked window")

    unlockState := app.Registry.ToggleLock(helperHwnd)
    AssertManual(unlockState = 0, "manual lock toggles off")

    reflowInfo := app.Registry.GetWindowInfo(helperHwnd)
    reflowPlanInfo := app.BuildManualPlanForMonitor(
        reflowInfo.monitor,
        reflowInfo.id,
        "manual_reflow"
    )
    app.ExecutePlan(
        reflowPlanInfo.windows,
        reflowPlanInfo.plan,
        "manual_reflow",
        "manual_reflow_test"
    )
    Sleep(260)
    reflowedRect := app.Registry.GetWindowRect(helperHwnd)
    AssertManual(!Geometry.Equal(reflowedRect, originalRect, 1), "manual reflow changes an eligible window")

    app.UndoLastLayout()
    Sleep(260)
    restoredRect := app.Registry.GetWindowRect(helperHwnd)
    AssertManual(Geometry.Equal(restoredRect, originalRect, 2), "undo restores pre-layout geometry")
} catch Error as err {
    FileAppend("FAIL: integration error: " err.Message " at " err.File ":" err.Line "`n", "*", "UTF-8")
    ManualTestFailures += 1
}

if (helperPid) {
    try {
        ProcessClose(helperPid)
    }
}
if (originalForeground && app.Registry.IsValidWindow(originalForeground)) {
    try {
        WinActivate("ahk_id " originalForeground)
    }
}
app.HandleExit("integration-test", ManualTestFailures = 0 ? 0 : 1)

if (ManualTestFailures = 0) {
    FileAppend(Format("PASS: {1} manual/undo integration tests`n", ManualTestCount), "*", "UTF-8")
    ExitApp(0)
}

FileAppend(
    Format("FAIL: {1} of {2} manual/undo integration tests failed`n", ManualTestFailures, ManualTestCount),
    "*",
    "UTF-8"
)
ExitApp(1)

AssertManual(condition, name) {
    global ManualTestCount
    global ManualTestFailures
    ManualTestCount += 1
    if (condition) {
        FileAppend("PASS: " name "`n", "*", "UTF-8")
    } else {
        ManualTestFailures += 1
        FileAppend("FAIL: " name "`n", "*", "UTF-8")
    }
}
