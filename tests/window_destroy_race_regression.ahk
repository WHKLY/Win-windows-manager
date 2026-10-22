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

global destroyRaceErrorLog := ""

runtimeDirectory := A_ScriptDir "\runtime\window-destroy-race"
DirCreate(runtimeDirectory)
testConfigPath := runtimeDirectory "\config.ini"
testLogPath := runtimeDirectory "\logs\win-windows-manager.log"
destroyRaceErrorLog := runtimeDirectory "\uncaught-errors.log"
if (FileExist(testLogPath)) {
    FileDelete(testLogPath)
}
if (FileExist(destroyRaceErrorLog)) {
    FileDelete(destroyRaceErrorLog)
}

FileCopy(A_ScriptDir "\..\config.ini", testConfigPath, true)
IniWrite("1", testConfigPath, "General", "Enabled")
IniWrite("1", testConfigPath, "General", "DryRun")
IniWrite("1", testConfigPath, "General", "ReflowOnNewWindow")
IniWrite("1", testConfigPath, "General", "DebugLogging")
IniWrite("50", testConfigPath, "AutoReflow", "NewWindowDebounceMs")
IniWrite("0", testConfigPath, "AutoReflow", "ReflowCooldownMs")
IniWrite("80", testConfigPath, "Placement", "SolverBudgetMs")
IniWrite("", testConfigPath, "Hotkeys", "Pause")
IniWrite("", testConfigPath, "Hotkeys", "ReflowCurrentMonitor")
IniWrite("", testConfigPath, "Hotkeys", "UndoLastLayout")
IniWrite("", testConfigPath, "Hotkeys", "ToggleLockActive")
IniWrite("", testConfigPath, "Hotkeys", "PlaceActive")
IniWrite("", testConfigPath, "Hotkeys", "ReloadConfig")

OnError(DestroyRaceUncaughtError)

app := WindowManagerApp(runtimeDirectory)
app.Start()
racePid := Run(Format('"{1}" "{2}"', A_AhkPath, A_ScriptDir "\helpers\window_destroy_race.ahk"))
ProcessWaitClose(racePid, 20000)
Sleep(1500)

logText := FileExist(testLogPath) ? FileRead(testLogPath, "UTF-8") : ""
uncaughtText := FileExist(destroyRaceErrorLog) ? FileRead(destroyRaceErrorLog, "UTF-8") : ""
queueFailures := CountDestroyRaceOccurrences(logText, "new_window_queue_full")
windowNotFound := CountDestroyRaceOccurrences(uncaughtText, "Target window not found")
otherUncaught := CountDestroyRaceOccurrences(uncaughtText, "[uncaught]") - windowNotFound

FileAppend(
    "INFO: queue_full=" queueFailures " window_not_found=" windowNotFound
        " other_uncaught=" otherUncaught "`n",
    "*",
    "UTF-8"
)

passed := queueFailures = 0 && windowNotFound = 0 && otherUncaught = 0
if (passed) {
    FileAppend("PASS: window destruction race remains safe`n", "*", "UTF-8")
} else {
    FileAppend("FAIL: window destruction race leaked an exception or queue overflow`n", "*", "UTF-8")
}

app.HandleExit("window-destroy-race-test", passed ? 0 : 1)
ExitApp(passed ? 0 : 1)

DestroyRaceUncaughtError(err, mode) {
    global destroyRaceErrorLog
    FileAppend(
        "[uncaught] mode=" mode " what=" err.What " message=" err.Message
            " extra=" err.Extra " file=" err.File " line=" err.Line "`n",
        destroyRaceErrorLog,
        "UTF-8"
    )
    return true
}

CountDestroyRaceOccurrences(text, needle) {
    if (text = "" || needle = "") {
        return 0
    }
    return (StrLen(text) - StrLen(StrReplace(text, needle, ""))) / StrLen(needle)
}
