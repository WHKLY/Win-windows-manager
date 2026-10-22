#Requires AutoHotkey v2.0
#SingleInstance Force

#Include ..\lib\Geometry.ahk
#Include ..\lib\Config.ahk
#Include ..\lib\LayoutPlanner.ahk

global TestFailures := 0
global TestCount := 0

TestGeometry()
TestPlanner()

if (TestFailures = 0) {
    FileAppend(Format("PASS: {1} tests`n", TestCount), "*", "UTF-8")
    ExitApp(0)
}

FileAppend(Format("FAIL: {1} of {2} tests failed`n", TestFailures, TestCount), "*", "UTF-8")
ExitApp(1)

TestGeometry() {
    first := Geometry.Rect(0, 0, 100, 100)
    second := Geometry.Rect(50, 50, 100, 100)
    Assert(Geometry.IntersectionArea(first, second) = 2500, "rectangle intersection")

    clamped := Geometry.ClampRect(Geometry.Rect(-50, -20, 200, 100), Geometry.Rect(0, 0, 1920, 1080), 16)
    Assert(clamped.x = 16 && clamped.y = 16, "negative coordinates clamped")
    Assert(Geometry.SmoothStep(0.0) = 0.0 && Geometry.SmoothStep(1.0) = 1.0, "smoothstep endpoints")
    Assert(Geometry.SmoothStep(0.5) > 0.49 && Geometry.SmoothStep(0.5) < 0.51, "smoothstep midpoint")

    interpolated := Geometry.InterpolateRect(
        Geometry.Rect(0, 0, 100, 100),
        Geometry.Rect(100, 200, 300, 400),
        0.5
    )
    Assert(interpolated.x = 50 && interpolated.y = 100, "smooth interpolation position")
    Assert(interpolated.w = 200 && interpolated.h = 250, "smooth interpolation size")
}

TestPlanner() {
    FileAppend("START: planner tests`n", "*", "UTF-8")
    try {
        cfg := Config(A_ScriptDir "\..\config.ini")
        FileAppend("INFO: configuration loaded`n", "*", "UTF-8")
    } catch Error as err {
        FileAppend(
            "FAIL: configuration error: " err.Message
                " at " err.File ":" err.Line " (" err.What ")`n",
            "*",
            "UTF-8"
        )
        ExitApp(2)
    }
    workArea := Geometry.Rect(0, 0, 1920, 1080)

    windows := [
        MakeWindow("5", 600, 300, 800, 600),
        MakeWindow("2", 100, 100, 800, 600),
        MakeWindow("9", 900, 250, 800, 600),
        MakeWindow("1", 450, 500, 700, 500, false, true, true),
        MakeWindow("3", 200, 300, 800, 600)
    ]
    baseline := LayoutPlanner.OriginalTargets(windows)
    FileAppend("INFO: baseline targets ready`n", "*", "UTF-8")
    baselineScore := LayoutPlanner.ScoreLayout(windows, baseline, workArea, "manual", cfg)
    FileAppend("INFO: baseline score=" baselineScore.Total "`n", "*", "UTF-8")
    gridTargets := LayoutPlanner.BuildGridPlan(windows, workArea, cfg)
    FileAppend("INFO: grid targets ready`n", "*", "UTF-8")
    sortedIndices := LayoutPlanner.SortByPriority(windows, [1, 2, 3, 5], "5")
    FileAppend("INFO: priority sort ready`n", "*", "UTF-8")
    plan := LayoutPlanner.PlanManual(windows, workArea, cfg, "5")
    FileAppend("INFO: first manual plan completed`n", "*", "UTF-8")
    Assert(plan.Valid, "manual plan valid")
    Assert(plan.ChangedIds.Length >= 2, "manual plan changes multiple windows")
    Assert(Geometry.Equal(plan.Targets["1"], windows[4].rect), "locked window remains fixed")
    Assert(AllTargetsWithin(plan.Targets, workArea), "manual targets remain on display")

    secondPlan := LayoutPlanner.PlanManual(windows, workArea, cfg, "5")
    FileAppend("INFO: second manual plan completed`n", "*", "UTF-8")
    Assert(PlanSignature(plan) = PlanSignature(secondPlan), "manual plan deterministic")

    autoWindows := [
        MakeWindow("new", 1000, 300, 2080, 1260, true),
        MakeWindow("old-a", 700, 50, 500, 1700),
        MakeWindow("old-b", 1500, 50, 500, 1700)
    ]
    autoPlan := LayoutPlanner.PlanAuto(autoWindows, Geometry.Rect(0, 0, 3200, 1800), cfg, "new")
    autoExistingChanged := LayoutPlanner.CountChangedExisting(autoWindows, autoPlan.Targets, "new")
    FileAppend(
        "INFO: automatic plan completed strategy=" autoPlan.Strategy
            " changed=" autoPlan.ChangedIds.Length
            " gain=" Round(autoPlan.QualityImprovementRatio, 4)
            " existing_changed=" autoExistingChanged
            " final_score=" Round(autoPlan.ScoreAfter.Total, 4) "`n",
        "*",
        "UTF-8"
    )
    FileAppend(
        "INFO: auto targets new=" RectText(autoPlan.Targets["new"])
            " old-a=" RectText(autoPlan.Targets["old-a"])
            " old-b=" RectText(autoPlan.Targets["old-b"]) "`n",
        "*",
        "UTF-8"
    )
    if (autoPlan.HasProp("CooperativeTargets")) {
        FileAppend(
            "INFO: coop targets new=" RectText(autoPlan.CooperativeTargets["new"])
                " old-a=" RectText(autoPlan.CooperativeTargets["old-a"])
                " old-b=" RectText(autoPlan.CooperativeTargets["old-b"]) "`n",
            "*",
            "UTF-8"
        )
    }
    Assert(autoPlan.Valid, "automatic plan valid")
    Assert(autoPlan.ChangedIds.Length >= 1, "automatic plan changes at least the new window")
    Assert(autoPlan.Strategy = "cooperative_reflow", "automatic plan uses cooperative reflow")
    Assert(autoExistingChanged > 0, "cooperative plan moves existing windows")

    singleWindows := [
        MakeWindow("active", 40, 40, 1700, 950, false, true, false, false, true),
        MakeWindow("other", 1200, 500, 500, 400)
    ]
    singlePlan := LayoutPlanner.PlanSingle(singleWindows, "active", workArea, cfg)
    FileAppend("INFO: single plan completed`n", "*", "UTF-8")
    Assert(singlePlan.Valid, "single-window plan valid")
    target := singlePlan.Targets["active"]
    Assert(target.w < 1700 && target.h < 950, "single active window resized to manageable size")

    fixedWindows := [
        MakeWindow("fixed-a", 100, 100, 700, 500, true, false),
        MakeWindow("fixed-b", 900, 100, 700, 500)
    ]
    fixedPlan := LayoutPlanner.PlanManual(fixedWindows, workArea, cfg)
    fixedTarget := fixedPlan.Targets["fixed-a"]
    Assert(
        fixedTarget.w = fixedWindows[1].w && fixedTarget.h = fixedWindows[1].h,
        "non-resizable window keeps size"
    )
}

MakeWindow(id, x, y, w, h, isNew := false, canResize := true, isLocked := false, recentlyChanged := false, foreground := false) {
    return {
        id: id,
        hwnd: 1,
        pid: 1,
        x: x,
        y: y,
        w: w,
        h: h,
        rect: Geometry.Rect(x, y, w, h),
        minW: canResize ? Min(w, 320) : w,
        minH: canResize ? Min(h, 200) : h,
        maxW: 1920,
        maxH: 1080,
        canMove: true,
        canResize: canResize,
        isNew: isNew,
        isLocked: isLocked,
        isInteracting: false,
        recentlyUserChanged: recentlyChanged,
        isForeground: foreground,
        priority: foreground ? 1.2 : 0.6
    }
}

AllTargetsWithin(targets, workArea) {
    for id, rect in targets {
        if (!Geometry.IsWithin(rect, workArea, 1)) {
            return false
        }
    }
    return true
}

PlanSignature(plan) {
    ids := []
    for id, rect in plan.Targets {
        ids.Push(id)
    }
    Loop ids.Length - 1 {
        position := A_Index + 1
        current := ids[position]
        scan := position - 1
        while (scan >= 1 && StrCompare(current, ids[scan]) < 0) {
            ids[scan + 1] := ids[scan]
            scan -= 1
        }
        ids[scan + 1] := current
    }
    result := ""
    for id in ids {
        rect := plan.Targets[id]
        result .= id ":" rect.x "," rect.y "," rect.w "," rect.h ";"
    }
    return result
}

RectText(rect) {
    return Format("({1},{2},{3},{4})", rect.x, rect.y, rect.w, rect.h)
}

Assert(condition, name) {
    global TestCount
    global TestFailures
    TestCount += 1
    if (condition) {
        FileAppend("PASS: " name "`n", "*", "UTF-8")
    } else {
        TestFailures += 1
        FileAppend("FAIL: " name "`n", "*", "UTF-8")
    }
}
