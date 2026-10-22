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

runtimeDirectory := A_ScriptDir "\runtime"
DirCreate(runtimeDirectory)
testConfigPath := runtimeDirectory "\config.ini"
testLogPath := runtimeDirectory "\logs\windowswindowsmanager.log"
if (FileExist(testLogPath)) {
    FileDelete(testLogPath)
}

FileCopy(A_ScriptDir "\..\config.ini", testConfigPath, true)
IniWrite("0", testConfigPath, "General", "Enabled")
IniWrite("1", testConfigPath, "General", "DryRun")
IniWrite("0", testConfigPath, "General", "ReflowOnNewWindow")
IniWrite("0", testConfigPath, "AutoReflow", "AutoMoveExistingWindows")

testGui := Gui("+Resize", "WWM Startup Smoke Window")
testGui.AddText("w240 h60", "Startup should not move this window")
testGui.Show("x120 y120 w360 h240")
Sleep(80)
positionBeforeStartup := LayoutExecutor.GetWindowRect(testGui.Hwnd)

app := WindowManagerApp(runtimeDirectory)
try {
    app.Start()
} catch Error as err {
    testGui.Destroy()
    FileAppend("FAIL: startup error: " err.Message " at " err.File ":" err.Line "`n", "*", "UTF-8")
    ExitApp(2)
}

SetTimer(FinishSmokeTest.Bind(app, testGui, positionBeforeStartup), -700)

FinishSmokeTest(app, testGui, positionBeforeStartup) {
    try {
        if (!app.Config.DryRun) {
            throw Error("DryRun config was not loaded")
        }
        if (!FileExist(app.Logger.Path)) {
            throw Error("log file was not created")
        }
        if (app.RegisteredHotkeys.Length < 5) {
            throw Error("default hotkey registration was incomplete")
        }
        if (app.Registry.Seen.Count = 0) {
            throw Error("startup window registry is empty")
        }
        if (!Geometry.Equal(LayoutExecutor.GetWindowRect(testGui.Hwnd), positionBeforeStartup, 1)) {
            throw Error("startup changed an existing window")
        }
        testGui.Destroy()
        FileAppend("PASS: application startup smoke test`n", "*", "UTF-8")
        ExitApp(0)
    } catch Error as err {
        testGui.Destroy()
        FileAppend("FAIL: " err.Message "`n", "*", "UTF-8")
        ExitApp(1)
    }
}
