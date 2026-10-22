#Requires AutoHotkey v2.0
#SingleInstance Force

#Include ..\lib\Geometry.ahk
#Include ..\lib\Config.ahk
#Include ..\lib\Logger.ahk
#Include ..\lib\WindowRegistry.ahk
#Include ..\lib\LayoutPlanner.ahk
#Include ..\lib\LayoutExecutor.ahk

global RegistryTestFailures := 0
global RegistryTestCount := 0

runtimeDirectory := A_ScriptDir "\runtime"
DirCreate(runtimeDirectory)
cfg := Config(A_ScriptDir "\..\config.ini")
runtimeLogger := Logger(runtimeDirectory "\logs", false)
registry := WindowRegistry(cfg, runtimeLogger)

helperPath := A_ScriptDir "\helpers\window_host.ahk"
helperOutput := runtimeDirectory "\registry-window-hwnd.txt"
if (FileExist(helperOutput)) {
    FileDelete(helperOutput)
}
helperPid := Run(Format('"{1}" "{2}" "{3}"', A_AhkPath, helperPath, helperOutput))
newHwnd := 0
Loop 40 {
    Sleep(100)
    if (FileExist(helperOutput)) {
        try {
            newHwnd := Trim(FileRead(helperOutput, "UTF-8")) + 0
        }
        if (newHwnd && WinExist("ahk_id " newHwnd)) {
            break
        }
    }
}

if (!newHwnd) {
    if (helperPid) {
        ProcessClose(helperPid)
    }
    FileAppend("FAIL: unable to launch isolated AutoHotkey test window`n", "*", "UTF-8")
    ExitApp(2)
}

Sleep(350)
info := registry.GetWindowInfo(newHwnd)
AssertRegistry(info.eligible, "registry accepts normal external window")
AssertRegistry(info.hwnd = newHwnd, "registry preserves window handle")
AssertRegistry(Geometry.IsWithin(info.rect, info.monitorInfo.rect, 2), "window geometry belongs to its monitor")

lockState := registry.ToggleLock(newHwnd)
lockedInfo := registry.GetWindowInfo(newHwnd)
AssertRegistry(lockState = 1 && lockedInfo.isLocked, "registry locks explicit window")
unlockState := registry.ToggleLock(newHwnd)
unlockedInfo := registry.GetWindowInfo(newHwnd)
AssertRegistry(unlockState = 0 && !unlockedInfo.isLocked, "registry unlocks explicit window")

windows := [unlockedInfo]
plan := LayoutPlanner.PlanSingle(
    windows,
    unlockedInfo.id,
    unlockedInfo.monitorInfo.workArea,
    cfg,
    "manual_one"
)
AssertRegistry(plan.Valid, "real window produces a valid single-window plan")
if (plan.Valid) {
    result := LayoutExecutor.Apply(windows, plan, {
        Smooth: true,
        DurationMs: 120,
        FrameIntervalMs: 16,
        MaxDurationMs: 260,
        Precheck: (*) => true,
        CancelCheck: (*) => false
    })
    AssertRegistry(result.Success, "real window can be moved through executor")
}

if (registry.IsValidWindow(newHwnd)) {
    restorePlan := {
        Valid: true,
        Targets: Map(unlockedInfo.id, unlockedInfo.rect)
    }
    currentInfo := registry.GetWindowInfo(newHwnd)
    if (currentInfo.eligible) {
        currentInfo.isLocked := false
        LayoutExecutor.Apply([currentInfo], restorePlan, {
            Smooth: true,
            DurationMs: 100,
            FrameIntervalMs: 16,
            MaxDurationMs: 260,
            Precheck: (*) => true,
            CancelCheck: (*) => false
        })
    }
}

if (helperPid) {
    try {
        ProcessClose(helperPid)
        ProcessWaitClose(helperPid, 3000)
    }
}

if (RegistryTestFailures = 0) {
    FileAppend(Format("PASS: {1} registry integration tests`n", RegistryTestCount), "*", "UTF-8")
    ExitApp(0)
}

FileAppend(
    Format("FAIL: {1} of {2} registry integration tests failed`n", RegistryTestFailures, RegistryTestCount),
    "*",
    "UTF-8"
)
ExitApp(1)

AssertRegistry(condition, name) {
    global RegistryTestCount
    global RegistryTestFailures
    RegistryTestCount += 1
    if (condition) {
        FileAppend("PASS: " name "`n", "*", "UTF-8")
    } else {
        RegistryTestFailures += 1
        FileAppend("FAIL: " name "`n", "*", "UTF-8")
    }
}
