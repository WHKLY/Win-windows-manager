#Requires AutoHotkey v2.0
;@Ahk2Exe-SetName WindowswindowsManager
;@Ahk2Exe-SetDescription Windows smart floating window manager
;@Ahk2Exe-SetVersion 0.1.0.0
#SingleInstance Force
Persistent

SetWorkingDir(A_ScriptDir)
CoordMode("Mouse", "Screen")
try {
    DllCall("SetProcessDpiAwarenessContext", "Ptr", -4, "Int")
}

#Include lib\Geometry.ahk
#Include lib\Config.ahk
#Include lib\Logger.ahk
#Include lib\WindowRegistry.ahk
#Include lib\LayoutPlanner.ahk
#Include lib\LayoutExecutor.ahk
#Include lib\LayoutHistory.ahk
#Include lib\WindowEvents.ahk
#Include lib\WindowManagerApp.ahk

global AppInstance := 0

OnError(HandleUncaughtError)

try {
    AppInstance := WindowManagerApp(A_ScriptDir)
    AppInstance.SmokeTestMode := A_Args.Length > 0 && A_Args[1] = "--smoke-test"
    AppInstance.Start()
    if (AppInstance.SmokeTestMode) {
        SetTimer((*) => ExitApp(0), -900)
    }
} catch Error as err {
    HandleUncaughtError(err, "startup")
    ExitApp(1)
}

HandleUncaughtError(err, mode) {
    global AppInstance
    try {
        if (IsObject(AppInstance) && AppInstance.Logger) {
            AppInstance.Logger.Error("uncaught_error", Map(
                "mode", mode,
                "error", err.Message,
                "what", err.What,
                "extra", err.Extra,
                "file", err.File,
                "line", err.Line
            ))
        } else {
            OutputDebug("WWM uncaught_error mode=" mode " error=" err.Message)
        }
    }
    return 0
}
