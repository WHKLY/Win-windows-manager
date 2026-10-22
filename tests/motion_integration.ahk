#Requires AutoHotkey v2.0
#SingleInstance Force

#Include ..\lib\Geometry.ahk
#Include ..\lib\LayoutExecutor.ahk

global MotionFailures := 0
global MotionTests := 0

MonitorGetWorkArea(1, &workLeft, &workTop, &workRight, &workBottom)
work := Geometry.Rect(workLeft, workTop, workRight - workLeft, workBottom - workTop)
start := Geometry.Rect(work.x + 80, work.y + 80, 320, 220)
target := Geometry.Rect(work.x + 520, work.y + 300, 440, 300)

testGui := Gui("+Resize", "WWM Motion Integration Test")
testGui.AddText("w250 h80", "Temporary integration test window")
testGui.Show(Format("x{1} y{2} w{3} h{4}", start.x, start.y, start.w, start.h))
Sleep(100)
WinActivate("ahk_id " testGui.Hwnd)
Sleep(80)

sampler := PositionSampler(testGui.Hwnd)
foregroundBefore := DllCall("GetForegroundWindow", "Ptr")
zPreviousBefore := DllCall("GetWindow", "Ptr", testGui.Hwnd, "UInt", 3, "Ptr")
zNextBefore := DllCall("GetWindow", "Ptr", testGui.Hwnd, "UInt", 2, "Ptr")

sampler.Start()
result := RunMotion(testGui, start, target, true, 160, 0)
sampler.Stop()
Sleep(60)

foregroundAfter := DllCall("GetForegroundWindow", "Ptr")
zPreviousAfter := DllCall("GetWindow", "Ptr", testGui.Hwnd, "UInt", 3, "Ptr")
zNextAfter := DllCall("GetWindow", "Ptr", testGui.Hwnd, "UInt", 2, "Ptr")
actual := LayoutExecutor.GetWindowRect(testGui.Hwnd)

AssertIntegration(result.Success, "smooth motion succeeds")
AssertIntegration(Geometry.Equal(actual, target, 2), "smooth motion reaches exact target")
AssertIntegration(sampler.DistinctPositions() >= 3, "smooth motion renders intermediate frames")
AssertIntegration(result.ElapsedMs >= 100, "smooth motion lasts configured duration")
AssertIntegration(foregroundBefore = foregroundAfter, "smooth motion preserves foreground")
AssertIntegration(zPreviousBefore = zPreviousAfter && zNextBefore = zNextAfter, "smooth motion preserves Z-order")

LayoutExecutor.SetWindowPosition(testGui.Hwnd, start)
Sleep(80)
instant := RunMotion(testGui, start, target, false, 160, 0)
AssertIntegration(instant.Success, "instant motion succeeds")
AssertIntegration(Geometry.Equal(LayoutExecutor.GetWindowRect(testGui.Hwnd), target, 2), "instant mode reaches same target")
AssertIntegration(instant.ElapsedMs < 100, "instant mode avoids animation delay")

LayoutExecutor.SetWindowPosition(testGui.Hwnd, start)
Sleep(80)
cancelState := {cutoff: A_TickCount + 50}
cancelled := RunMotion(testGui, start, target, true, 160, () => A_TickCount >= cancelState.cutoff)
AssertIntegration(cancelled.Cancelled, "motion reports cancellation")
AssertIntegration(!Geometry.Equal(LayoutExecutor.GetWindowRect(testGui.Hwnd), target, 2), "cancelled motion does not force final target")

testGui.Destroy()

if (MotionFailures = 0) {
    FileAppend(Format("PASS: {1} motion integration tests`n", MotionTests), "*", "UTF-8")
    ExitApp(0)
}

FileAppend(Format("FAIL: {1} of {2} motion integration tests failed`n", MotionFailures, MotionTests), "*", "UTF-8")
ExitApp(1)

RunMotion(testGui, from, target, smooth, duration, cancelCheck) {
    window := {
        id: "motion-test",
        hwnd: testGui.Hwnd,
        pid: ProcessExist(),
        rect: Geometry.CopyRect(from),
        monitor: 1,
        workArea: Geometry.Rect(0, 0, 1920, 1080)
    }
    plan := {
        Valid: true,
        Targets: Map("motion-test", Geometry.CopyRect(target))
    }
    options := {
        Smooth: smooth,
        DurationMs: duration,
        FrameIntervalMs: 16,
        MaxDurationMs: 260,
        Precheck: (*) => true,
        CancelCheck: IsObject(cancelCheck) ? cancelCheck : NoCancel
    }
    return LayoutExecutor.Apply([window], plan, options)
}

NoCancel(*) {
    return false
}

AssertIntegration(condition, name) {
    global MotionTests
    global MotionFailures
    MotionTests += 1
    if (condition) {
        FileAppend("PASS: " name "`n", "*", "UTF-8")
    } else {
        MotionFailures += 1
        FileAppend("FAIL: " name "`n", "*", "UTF-8")
    }
}

class PositionSampler {
    __New(hwnd) {
        this.Hwnd := hwnd
        this.Samples := []
        this.Callback := ObjBindMethod(this, "Sample")
    }

    Start() {
        this.Samples := []
        this.Sample()
        SetTimer(this.Callback, 10)
    }

    Stop() {
        SetTimer(this.Callback, 0)
        this.Sample()
    }

    Sample(*) {
        if (!DllCall("IsWindow", "Ptr", this.Hwnd, "Int")) {
            return
        }
        rect := LayoutExecutor.GetWindowRect(this.Hwnd)
        if (this.Samples.Length = 0 || !Geometry.Equal(this.Samples[this.Samples.Length], rect)) {
            this.Samples.Push(rect)
        }
    }

    DistinctPositions() {
        return this.Samples.Length
    }
}
