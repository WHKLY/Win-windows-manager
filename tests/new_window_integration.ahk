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

runtimeDirectory := A_ScriptDir "\runtime\new-window"
DirCreate(runtimeDirectory)
testConfigPath := runtimeDirectory "\config.ini"
FileCopy(A_ScriptDir "\..\config.ini", testConfigPath, true)
IniWrite("1", testConfigPath, "General", "Enabled")
IniWrite("1", testConfigPath, "General", "DryRun")
IniWrite("1", testConfigPath, "General", "ReflowOnNewWindow")
IniWrite("100", testConfigPath, "AutoReflow", "NewWindowDebounceMs")
IniWrite("100", testConfigPath, "AutoReflow", "ReflowCooldownMs")
IniWrite("150", testConfigPath, "Placement", "SolverBudgetMs")
IniWrite("0", testConfigPath, "AutoReflow", "AutoMoveExistingWindows")
IniWrite("", testConfigPath, "Hotkeys", "Pause")
IniWrite("", testConfigPath, "Hotkeys", "ReflowCurrentMonitor")
IniWrite("", testConfigPath, "Hotkeys", "UndoLastLayout")
IniWrite("", testConfigPath, "Hotkeys", "ToggleLockActive")
IniWrite("", testConfigPath, "Hotkeys", "PlaceActive")
IniWrite("", testConfigPath, "Hotkeys", "ReloadConfig")

logPath := runtimeDirectory "\logs\win-windows-manager.log"
if (FileExist(logPath)) {
    FileDelete(logPath)
}

app := WindowManagerApp(runtimeDirectory)
helperPid := 0
try {
    app.Start()
    helperPath := A_ScriptDir "\helpers\window_host.ahk"
    helperOutput := runtimeDirectory "\helper-hwnd.txt"
    if (FileExist(helperOutput)) {
        FileDelete(helperOutput)
    }
    helperPid := Run(Format('"{1}" "{2}" "{3}"', A_AhkPath, helperPath, helperOutput))

    found := false
    Loop 60 {
        Sleep(100)
        if (FileExist(logPath) && InStr(FileRead(logPath, "UTF-8"), "layout_dry_run")) {
            found := true
            break
        }
    }
    if (!found) {
        throw Error("new-window DryRun event did not reach layout planning")
    }
    FileAppend("PASS: new-window event triggers DryRun planning`n", "*", "UTF-8")
    FileAppend("PASS: 1 new-window integration test`n", "*", "UTF-8")
    exitCode := 0
} catch Error as err {
    FileAppend("FAIL: " err.Message " at " err.File ":" err.Line "`n", "*", "UTF-8")
    exitCode := 1
}

if (helperPid) {
    try {
        ProcessClose(helperPid)
    }
}
app.HandleExit("integration-test", exitCode)
ExitApp(exitCode)
