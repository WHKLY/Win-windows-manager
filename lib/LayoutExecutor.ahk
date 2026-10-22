class LayoutExecutor {
    static Apply(windows, plan, options) {
        result := {
            Success: false,
            Cancelled: false,
            NoChange: false,
            ChangedCount: 0,
            AppliedCount: 0,
            FailedCount: 0,
            ElapsedMs: 0,
            Before: [],
            After: [],
            Changes: [],
            Errors: []
        }
        if (!plan || !plan.Valid || !plan.Targets) {
            result.Errors.Push("invalid_plan")
            return result
        }

        changes := []
        for window in windows {
            if (!plan.Targets.Has(window.id)) {
                continue
            }
            target := plan.Targets[window.id]
            if (Geometry.Equal(window.rect, target)) {
                continue
            }
            if (!this.IdentityMatches(window) || this.IsInteracting(options, window)) {
                continue
            }
            changes.Push({
                window: window,
                id: window.id,
                hwnd: window.hwnd,
                pid: window.pid,
                from: Geometry.CopyRect(window.rect),
                target: Geometry.CopyRect(target)
            })
        }

        if (changes.Length = 0) {
            result.NoChange := true
            result.Success := true
            return result
        }

        result.ChangedCount := changes.Length
        for change in changes {
            result.Before.Push({
                hwnd: change.hwnd,
                pid: change.pid,
                id: change.id,
                rect: Geometry.CopyRect(change.from),
                monitor: change.window.monitor,
                workArea: Geometry.CopyRect(change.window.workArea)
            })
        }

        smooth := options.Smooth == true
        duration := Max(0, Round(options.DurationMs))
        interval := Max(8, Round(options.FrameIntervalMs))
        maximumDuration := Max(duration, Round(options.MaxDurationMs))
        if (!smooth || duration <= 0) {
            duration := 0
        }

        startTick := A_TickCount
        cancelled := false
        failed := false
        if (this.CancelRequested(options)) {
            cancelled := true
        }

        if (!cancelled && duration > 0) {
            while true {
                elapsed := A_TickCount - startTick
                if (this.CancelRequested(options)) {
                    cancelled := true
                    break
                }
                if (elapsed >= duration || elapsed > maximumDuration) {
                    break
                }
                progress := elapsed / duration
                for change in changes {
                    if (!DllCall("IsWindow", "Ptr", change.hwnd, "Int")) {
                        failed := true
                        result.Errors.Push("window_destroyed_during_animation")
                        cancelled := true
                        break 2
                    }
                    frameRect := Geometry.InterpolateRect(change.from, change.target, progress)
                    if (!this.SetWindowPosition(change.hwnd, frameRect)) {
                        failed := true
                        result.Errors.Push("set_window_pos_failed")
                    }
                }
                remaining := duration - (A_TickCount - startTick)
                if (remaining <= 0) {
                    break
                }
                Sleep(Max(1, Min(interval, remaining)))
            }
        }

        if (!cancelled && !failed) {
            for change in changes {
                if (this.CancelRequested(options)) {
                    cancelled := true
                    break
                }
                if (this.IsInteracting(options, change.window)) {
                    cancelled := true
                    result.Errors.Push("window_interaction_started_before_commit")
                    break
                }
                if (!this.IdentityMatches(change.window)) {
                    failed := true
                    result.Errors.Push("identity_changed_before_commit")
                    continue
                }
                if (!this.SetWindowPosition(change.hwnd, change.target)) {
                    failed := true
                    result.Errors.Push("final_set_window_pos_failed")
                }
            }
        }

        result.ElapsedMs := A_TickCount - startTick
        result.Cancelled := cancelled

        applied := 0
        failedCount := 0
        for change in changes {
            if (!DllCall("IsWindow", "Ptr", change.hwnd, "Int")) {
                failedCount += 1
                continue
            }
            actual := this.GetWindowRect(change.hwnd)
            result.After.Push({
                hwnd: change.hwnd,
                pid: change.pid,
                id: change.id,
                rect: Geometry.CopyRect(actual)
            })
            if (!Geometry.Equal(actual, change.from)) {
                applied += 1
            }
            if (!Geometry.Equal(actual, change.target, 2)) {
                failedCount += 1
            }
            result.Changes.Push({
                id: change.id,
                hwnd: change.hwnd,
                from: Geometry.CopyRect(change.from),
                target: Geometry.CopyRect(change.target),
                actual: Geometry.CopyRect(actual)
            })
        }

        result.AppliedCount := applied
        result.FailedCount := failedCount
        result.Success := !cancelled && !failed && failedCount = 0
        return result
    }

    static SetWindowPosition(hwnd, rect) {
        flags := 0x0004 | 0x0010 | 0x0200
        return DllCall(
            "SetWindowPos",
            "Ptr", hwnd,
            "Ptr", 0,
            "Int", rect.x,
            "Int", rect.y,
            "Int", rect.w,
            "Int", rect.h,
            "UInt", flags,
            "Int"
        )
    }

    static GetWindowRect(hwnd) {
        rectBuffer := Buffer(16, 0)
        if (!DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rectBuffer.Ptr, "Int")) {
            return Geometry.Rect(0, 0, 0, 0)
        }
        return Geometry.Rect(
            NumGet(rectBuffer, 0, "Int"),
            NumGet(rectBuffer, 4, "Int"),
            NumGet(rectBuffer, 8, "Int") - NumGet(rectBuffer, 0, "Int"),
            NumGet(rectBuffer, 12, "Int") - NumGet(rectBuffer, 4, "Int")
        )
    }

    static IdentityMatches(window) {
        if (!DllCall("IsWindow", "Ptr", window.hwnd, "Int")) {
            return false
        }
        pid := 0
        DllCall("GetWindowThreadProcessId", "Ptr", window.hwnd, "UInt*", &pid)
        return pid = window.pid
    }

    static IsInteracting(options, window) {
        if (!options || !options.HasProp("Precheck")) {
            return false
        }
        precheck := options.Precheck
        return IsObject(precheck) ? !precheck(window) : false
    }

    static CancelRequested(options) {
        if (!options || !options.HasProp("CancelCheck")) {
            return false
        }
        cancelCheck := options.CancelCheck
        return IsObject(cancelCheck) ? cancelCheck() : false
    }
}
