#Requires AutoHotkey v2.0
#SingleInstance Force

#Include ..\lib\Geometry.ahk
#Include ..\lib\LayoutExecutor.ahk

MonitorGetWorkArea(1, &workLeft, &workTop, &workRight, &workBottom)
work := Geometry.Rect(workLeft, workTop, workRight - workLeft, workBottom - workTop)

testWindows := []
windows := []
targets := Map()

Loop 5 {
    index := A_Index
    testGui := Gui("+Resize", "WWM Performance " index)
    testGui.AddText("w180 h50", "Animation performance test")
    startX := work.x + 30 + (index - 1) * 120
    startY := work.y + 80 + (index - 1) * 70
    testGui.Show(Format("NoActivate w260 h160 x{1} y{2}", startX, startY))
    testWindows.Push(testGui)
    windows.Push({
        id: "perf-" index,
        hwnd: testGui.Hwnd,
        pid: ProcessExist(),
        rect: LayoutExecutor.GetWindowRect(testGui.Hwnd),
        monitor: 1,
        workArea: work
    })
}
Sleep(150)

for index, window in windows {
    startRect := LayoutExecutor.GetWindowRect(window.hwnd)
    window.rect := startRect
    targets[window.id] := Geometry.ClampRect(
        Geometry.Rect(startRect.x + 420, startRect.y + 180, startRect.w, startRect.h),
        work,
        8
    )
}

frames := []
startCounter := QueryPerformanceCounter()
result := LayoutExecutor.Apply(windows, {
    Valid: true,
    Targets: targets
}, {
    Smooth: true,
    DurationMs: 300,
    FrameIntervalMs: 8,
    MaxDurationMs: 400,
    Precheck: (*) => true,
    CancelCheck: (*) => false,
    FrameObserver: elapsedTicks => frames.Push({microseconds: QueryPerformanceCounter(), loopMs: elapsedTicks})
})
endCounter := QueryPerformanceCounter()

for testGui in testWindows {
    testGui.Destroy()
}

if (frames.Length < 2) {
    FileAppend("FAIL: insufficient animation frames`n", "*", "UTF-8")
    ExitApp(1)
}

intervals := []
for index, frame in frames {
    if (index > 1) {
        intervals.Push((frame.microseconds - frames[index - 1].microseconds) / 1000)
    }
}

totalFrameTimeMs := 0
maximumIntervalMs := 0
for interval in intervals {
    totalFrameTimeMs += interval
    maximumIntervalMs := Max(maximumIntervalMs, interval)
}
averageIntervalMs := totalFrameTimeMs / intervals.Length
averageFps := 1000 / averageIntervalMs
elapsedMs := (endCounter - startCounter) / 1000

FileAppend(Format(
    "INFO: frames={1} elapsed_ms={2:.2f} avg_interval_ms={3:.2f} max_interval_ms={4:.2f} avg_fps={5:.2f}`n",
    frames.Length,
    elapsedMs,
    averageIntervalMs,
    maximumIntervalMs,
    averageFps
), "*", "UTF-8")

if (result.Success && averageFps >= 100 && maximumIntervalMs <= 20) {
    FileAppend("PASS: smooth animation sustains interactive frame rate`n", "*", "UTF-8")
    ExitApp(0)
}

FileAppend("FAIL: smooth animation has low or jittery frame pacing`n", "*", "UTF-8")
ExitApp(1)

QueryPerformanceCounter() {
    static frequency := 0
    if (!frequency) {
        DllCall("QueryPerformanceFrequency", "Int64*", &frequency)
    }
    counter := 0
    DllCall("QueryPerformanceCounter", "Int64*", &counter)
    return counter * 1000000 / frequency
}
