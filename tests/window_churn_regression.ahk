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

global windowChurnErrorLog := ""

runtimeDirectory := A_ScriptDir "\runtime\window-churn"
DirCreate(runtimeDirectory)
testConfigPath := runtimeDirectory "\config.ini"
testLogPath := runtimeDirectory "\logs\windowswindowsmanager.log"
windowChurnErrorLog := runtimeDirectory "\uncaught-errors.log"
if (FileExist(testLogPath)) {
    FileDelete(testLogPath)
}
if (FileExist(windowChurnErrorLog)) {
    FileDelete(windowChurnErrorLog)
}

FileCopy(A_ScriptDir "\..\config.ini", testConfigPath, true)
IniWrite("1", testConfigPath, "General", "Enabled")
IniWrite("1", testConfigPath, "General", "DryRun")
IniWrite("1", testConfigPath, "General", "ReflowOnNewWindow")
IniWrite("1", testConfigPath, "General", "DebugLogging")
IniWrite("50", testConfigPath, "AutoReflow", "ReflowCooldownMs")
IniWrite("100", testConfigPath, "Placement", "SolverBudgetMs")
IniWrite("", testConfigPath, "Hotkeys", "Pause")
IniWrite("", testConfigPath, "Hotkeys", "ReflowCurrentMonitor")
IniWrite("", testConfigPath, "Hotkeys", "UndoLastLayout")
IniWrite("", testConfigPath, "Hotkeys", "ToggleLockActive")
IniWrite("", testConfigPath, "Hotkeys", "PlaceActive")
IniWrite("", testConfigPath, "Hotkeys", "ReloadConfig")

OnError(WindowChurnUncaughtError)

app := WindowManagerApp(runtimeDirectory)
app.Start()
churnPid := Run(Format('"{1}" "{2}"', A_AhkPath, A_ScriptDir "\helpers\window_churn.ahk"))
ProcessWaitClose(churnPid, 15000)
Sleep(1500)

logText := FileExist(testLogPath) ? FileRead(testLogPath, "UTF-8") : ""
uncaughtText := FileExist(windowChurnErrorLog) ? FileRead(windowChurnErrorLog, "UTF-8") : ""
queueFailures := CountOccurrences(logText, "new_window_queue_full")
windowNotFound := CountOccurrences(uncaughtText, "Target window not found")
otherUncaught := CountOccurrences(uncaughtText, "[uncaught]") - windowNotFound

FileAppend("INFO: queue_full=" queueFailures " window_not_found=" windowNotFound " other_uncaught=" otherUncaught "`n", "*", "UTF-8")

passed := queueFailures = 0 && windowNotFound = 0 && otherUncaught = 0
if (queueFailures = 0 && windowNotFound = 0 && otherUncaught = 0) {
    FileAppend("PASS: window churn has no queue overflow or window-destruction exceptions`n", "*", "UTF-8")
} else {
    FileAppend(
        "FAIL: window churn reproduced queue overflow or window-destruction exceptions`n",
        "*",
        "UTF-8"
    )
}

app.HandleExit("window-churn-test", passed ? 0 : 1)
ExitApp(passed ? 0 : 1)

WindowChurnUncaughtError(err, mode) {
    global windowChurnErrorLog
    FileAppend(
        "[uncaught] mode=" mode " what=" err.What " message=" err.Message
            " extra=" err.Extra " line=" err.Line "`n",
        windowChurnErrorLog,
        "UTF-8"
    )
    return true
}

CountOccurrences(text, needle) {
    if (text = "" || needle = "") {
        return 0
    }
    return (StrLen(text) - StrLen(StrReplace(text, needle, ""))) / StrLen(needle)
}
