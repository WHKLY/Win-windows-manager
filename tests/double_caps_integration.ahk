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

runtimeDirectory := A_ScriptDir "\runtime\double-escape"
DirCreate(runtimeDirectory)
testConfigPath := runtimeDirectory "\config.ini"
testLogPath := runtimeDirectory "\logs\win-windows-manager.log"
if (FileExist(testLogPath)) {
    FileDelete(testLogPath)
}

FileCopy(A_ScriptDir "\..\config.ini", testConfigPath, true)
IniWrite("0", testConfigPath, "General", "Enabled")
IniWrite("1", testConfigPath, "General", "DryRun")
IniWrite("0", testConfigPath, "General", "ReflowOnNewWindow")
IniWrite("250", testConfigPath, "Hotkeys", "DoubleCapsIntervalMs")
IniWrite("", testConfigPath, "Hotkeys", "Pause")
IniWrite("", testConfigPath, "Hotkeys", "ReflowCurrentMonitor")
IniWrite("", testConfigPath, "Hotkeys", "UndoLastLayout")
IniWrite("", testConfigPath, "Hotkeys", "ToggleLockActive")
IniWrite("", testConfigPath, "Hotkeys", "PlaceActive")
IniWrite("", testConfigPath, "Hotkeys", "ReloadConfig")

app := WindowManagerApp(runtimeDirectory)
failures := 0
try {
    app.Start()
    if (!HasRegisteredHotkey(app, "~CapsLock")) {
        throw Error("double CapsLock hotkey was not registered")
    }

    app.OnCapsLockDown()
    app.CompleteCapsPress()
    Sleep(350)
    app.OnCapsLockDown()
    app.CompleteCapsPress()
    Sleep(100)
    logText := FileRead(testLogPath, "UTF-8")
    if (InStr(logText, "double_caps_reflow_triggered")) {
        throw Error("slow CapsLock presses triggered reflow")
    }
    FileAppend("PASS: slow CapsLock presses do not trigger reflow`n", "*", "UTF-8")

    app.DoubleCapsGesture.Reset()
    app.OnCapsLockDown()
    app.CompleteCapsPress()
    Sleep(100)
    app.OnCapsLockDown()
    app.CompleteCapsPress()
    Sleep(100)
    logText := FileRead(testLogPath, "UTF-8")
    triggerCount := (StrLen(logText) - StrLen(StrReplace(logText, "double_caps_reflow_triggered", ""))) / StrLen("double_caps_reflow_triggered")
    if (triggerCount != 1) {
        throw Error("expected exactly one double CapsLock trigger, got " triggerCount)
    }
    FileAppend("PASS: double CapsLock triggers reflow once`n", "*", "UTF-8")
    FileAppend("PASS: double CapsLock integration test`n", "*", "UTF-8")
} catch Error as err {
    failures += 1
    FileAppend("FAIL: " err.Message " at " err.File ":" err.Line "`n", "*", "UTF-8")
}

app.HandleExit("double-caps-test", failures = 0 ? 0 : 1)
ExitApp(failures = 0 ? 0 : 1)

HasRegisteredHotkey(app, hotkeyName) {
    for registered in app.RegisteredHotkeys {
        if (registered = hotkeyName) {
            return true
        }
    }
    return false
}
