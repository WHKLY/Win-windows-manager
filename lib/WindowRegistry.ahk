class WindowRegistry {
    static SystemClasses := [
        "#32770",
        "Progman",
        "WorkerW",
        "Shell_TrayWnd",
        "Shell_SecondaryTrayWnd",
        "NotifyIconOverflowWindow",
        "TopLevelWindowForOverflowXamlIsland",
        "Windows.UI.Core.CoreWindow",
        "ApplicationManager_DesktopShellWindow"
    ]

    __New(config, logger) {
        this.Config := config
        this.Logger := logger
        this.Seen := Map()
        this.Locks := Map()
        this.Interacting := Map()
        this.RecentUserChanges := Map()
        this.Applying := false
        this.MotionCancelRequested := false
        this.enumeratedMonitors := []
    }

    CaptureStartupWindows() {
        count := 0
        for hwnd in WinGetList() {
            key := this.IdentityFromHandle(hwnd)
            if (key != "") {
                this.Seen[key] := true
                count += 1
            }
        }
        this.Logger.Info("startup_windows_registered", Map("count", count))
        return count
    }

    IdentityFromHandle(hwnd) {
        if (!this.IsValidWindow(hwnd)) {
            return ""
        }
        pid := 0
        DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "UInt*", &pid)
        if (!pid) {
            return ""
        }
        return hwnd ":" pid
    }

    IsSeen(hwnd) {
        key := this.IdentityFromHandle(hwnd)
        return key != "" && this.Seen.Has(key)
    }

    MarkSeen(hwnd) {
        key := this.IdentityFromHandle(hwnd)
        if (key != "") {
            this.Seen[key] := true
        }
    }

    ForgetWindow(hwnd) {
        prefix := hwnd ":"
        keys := []
        for key in this.Seen {
            if (InStr(key, prefix) = 1) {
                keys.Push(key)
            }
        }
        for key in keys {
            if (this.Seen.Has(key)) {
                this.Seen.Delete(key)
            }
            if (this.Locks.Has(key)) {
                this.Locks.Delete(key)
            }
            if (this.Interacting.Has(key)) {
                this.Interacting.Delete(key)
            }
            if (this.RecentUserChanges.Has(key)) {
                this.RecentUserChanges.Delete(key)
            }
        }
    }

    IsValidWindow(hwnd) {
        return hwnd && DllCall("IsWindow", "Ptr", hwnd, "Int")
    }

    GetWindowInfo(hwnd) {
        if (!this.IsValidWindow(hwnd)) {
            return {eligible: false, reason: "invalid_window"}
        }

        root := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
        if (!root || root != hwnd) {
            return {eligible: false, reason: "not_root_window"}
        }

        if (!DllCall("IsWindowVisible", "Ptr", hwnd, "Int")) {
            return {eligible: false, reason: "not_visible"}
        }

        try {
            className := WinGetClass("ahk_id " hwnd)
        } catch Error {
            return {eligible: false, reason: "window_disappeared"}
        }
        if (className = "") {
            return {eligible: false, reason: "missing_class"}
        }
        if (this.IsBuiltInExcludedClass(className)) {
            return {eligible: false, reason: "system_class"}
        }
        for excludedClass in this.Config.WindowClassExclusions {
            if (StrLower(className) = excludedClass) {
                return {eligible: false, reason: "excluded_class"}
            }
        }

        pid := 0
        DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "UInt*", &pid)
        if (!pid || pid = ProcessExist()) {
            return {eligible: false, reason: "own_or_invalid_process"}
        }

        try {
            processName := WinGetProcessName("ahk_id " hwnd)
        } catch Error {
            return {eligible: false, reason: "window_disappeared"}
        }
        if (processName = "") {
            return {eligible: false, reason: "missing_process"}
        }
        for excludedProcess in this.Config.ProcessExclusions {
            if (StrLower(processName) = excludedProcess) {
                return {eligible: false, reason: "excluded_process"}
            }
        }

        style := this.GetWindowLong(hwnd, -16)
        extendedStyle := this.GetWindowLong(hwnd, -20)
        if (style & 0x40000000) {
            return {eligible: false, reason: "child_window"}
        }
        if (extendedStyle & 0x00000080) {
            return {eligible: false, reason: "tool_window"}
        }
        if (extendedStyle & 0x08000000) {
            return {eligible: false, reason: "no_activate_window"}
        }

        owner := DllCall("GetWindow", "Ptr", hwnd, "UInt", 4, "Ptr")
        if (owner) {
            return {eligible: false, reason: "owned_dialog"}
        }

        if (this.IsCloaked(hwnd)) {
            return {eligible: false, reason: "cloaked"}
        }

        hasCaption := (style & 0x00C00000) != 0
        hasThickFrame := (style & 0x00040000) != 0
        if (!hasCaption && !hasThickFrame) {
            return {eligible: false, reason: "no_manageable_frame"}
        }

        isMinimized := DllCall("IsIconic", "Ptr", hwnd, "Int") != 0
        isMaximized := DllCall("IsZoomed", "Ptr", hwnd, "Int") != 0
        rect := this.GetWindowRect(hwnd)
        if (!rect) {
            return {eligible: false, reason: "missing_rect"}
        }

        monitor := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr")
        monitorInfo := this.GetMonitorInfo(monitor)
        if (!monitorInfo) {
            return {eligible: false, reason: "missing_monitor"}
        }

        if (!isMinimized && !isMaximized && this.CoversMonitor(rect, monitorInfo.rect)) {
            return {eligible: false, reason: "exclusive_fullscreen"}
        }

        identity := hwnd ":" pid
        canMove := hasCaption && !isMaximized
        canResize := hasThickFrame && !isMaximized
        recentAt := this.RecentUserChanges.Has(identity) ? this.RecentUserChanges[identity] : 0
        recent := recentAt > 0 && (A_TickCount - recentAt) <= this.Config.RecentlyUserMovedGraceMs
        isLocked := this.Locks.Has(identity)
        interacting := this.Interacting.Has(identity)
        foreground := DllCall("GetForegroundWindow", "Ptr")

        return {
            eligible: true,
            reason: "",
            hwnd: hwnd,
            pid: pid,
            id: identity,
            processName: processName,
            className: className,
            rect: rect,
            x: rect.x,
            y: rect.y,
            w: rect.w,
            h: rect.h,
            monitor: monitor,
            monitorInfo: monitorInfo,
            workArea: monitorInfo.workArea,
            isMinimized: isMinimized,
            isMaximized: isMaximized,
            isLocked: isLocked,
            isInteracting: interacting,
            recentlyUserChanged: recent,
            isForeground: hwnd = foreground,
            isTopmost: (extendedStyle & 0x00000008) != 0,
            canMove: canMove,
            canResize: canResize,
            minW: canResize ? Min(rect.w, 320) : rect.w,
            minH: canResize ? Min(rect.h, 200) : rect.h,
            maxW: monitorInfo.workArea.w,
            maxH: monitorInfo.workArea.h,
            isNew: false,
            priority: hwnd = foreground ? 1.2 : 0.6
        }
    }

    IsBuiltInExcludedClass(className) {
        normalized := StrLower(className)
        for excluded in WindowRegistry.SystemClasses {
            if (normalized = StrLower(excluded)) {
                return true
            }
        }
        return false
    }

    IsCloaked(hwnd) {
        cloaked := 0
        result := DllCall(
            "Dwmapi\DwmGetWindowAttribute",
            "Ptr", hwnd,
            "UInt", 14,
            "UInt*", &cloaked,
            "UInt", 4,
            "Int"
        )
        return result = 0 && cloaked != 0
    }

    CoversMonitor(rect, monitorRect) {
        return Abs(rect.x - monitorRect.x) <= 2
            && Abs(rect.y - monitorRect.y) <= 2
            && Abs(rect.w - monitorRect.w) <= 2
            && Abs(rect.h - monitorRect.h) <= 2
    }

    GetWindowLong(hwnd, index) {
        if (A_PtrSize = 8) {
            return DllCall("GetWindowLongPtrW", "Ptr", hwnd, "Int", index, "Ptr")
        }
        return DllCall("GetWindowLongW", "Ptr", hwnd, "Int", index, "Int")
    }

    GetWindowRect(hwnd) {
        rectBuffer := Buffer(16, 0)
        if (!DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rectBuffer.Ptr, "Int")) {
            return 0
        }
        return Geometry.Rect(
            NumGet(rectBuffer, 0, "Int"),
            NumGet(rectBuffer, 4, "Int"),
            NumGet(rectBuffer, 8, "Int") - NumGet(rectBuffer, 0, "Int"),
            NumGet(rectBuffer, 12, "Int") - NumGet(rectBuffer, 4, "Int")
        )
    }

    GetMonitorInfo(monitor) {
        if (!monitor) {
            return 0
        }
        monitorBuffer := Buffer(40, 0)
        NumPut("UInt", 40, monitorBuffer, 0)
        if (!DllCall("GetMonitorInfoW", "Ptr", monitor, "Ptr", monitorBuffer.Ptr, "Int")) {
            return 0
        }
        return {
            monitor: monitor,
            rect: Geometry.Rect(
                NumGet(monitorBuffer, 4, "Int"),
                NumGet(monitorBuffer, 8, "Int"),
                NumGet(monitorBuffer, 12, "Int") - NumGet(monitorBuffer, 4, "Int"),
                NumGet(monitorBuffer, 16, "Int") - NumGet(monitorBuffer, 8, "Int")
            ),
            workArea: Geometry.Rect(
                NumGet(monitorBuffer, 20, "Int"),
                NumGet(monitorBuffer, 24, "Int"),
                NumGet(monitorBuffer, 28, "Int") - NumGet(monitorBuffer, 20, "Int"),
                NumGet(monitorBuffer, 32, "Int") - NumGet(monitorBuffer, 24, "Int")
            ),
            primary: (NumGet(monitorBuffer, 36, "UInt") & 1) != 0
        }
    }

    GetMonitorList() {
        this.enumeratedMonitors := []
        callback := CallbackCreate(ObjBindMethod(this, "EnumerateMonitor"), "Fast", 4)
        try {
            DllCall("EnumDisplayMonitors", "Ptr", 0, "Ptr", 0, "Ptr", callback, "Ptr", 0)
        } finally {
            CallbackFree(callback)
        }
        return this.enumeratedMonitors
    }

    EnumerateMonitor(monitor, hdc, rectPointer, data) {
        this.enumeratedMonitors.Push(monitor)
        return true
    }

    GetWindowMonitor(hwnd) {
        if (!this.IsValidWindow(hwnd)) {
            return 0
        }
        return DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr")
    }

    GetForegroundWindow() {
        return DllCall("GetForegroundWindow", "Ptr")
    }

    GetCursorMonitor() {
        pointBuffer := Buffer(8, 0)
        if (!DllCall("GetCursorPos", "Ptr", pointBuffer.Ptr, "Int")) {
            return 0
        }
        x := NumGet(pointBuffer, 0, "Int")
        y := NumGet(pointBuffer, 4, "Int")
        packed := (y << 32) | (x & 0xFFFFFFFF)
        return DllCall("MonitorFromPoint", "Int64", packed, "UInt", 2, "Ptr")
    }

    GetPreferredMonitorForNew(hwnd) {
        monitor := this.GetWindowMonitor(hwnd)
        if (monitor) {
            return monitor
        }
        foreground := this.GetForegroundWindow()
        monitor := this.GetWindowMonitor(foreground)
        if (monitor) {
            return monitor
        }
        monitor := this.GetCursorMonitor()
        if (monitor) {
            return monitor
        }
        primary := this.GetEnumeratorPrimaryMonitor()
        return primary
    }

    GetEnumeratorPrimaryMonitor() {
        for monitor in this.GetMonitorList() {
            info := this.GetMonitorInfo(monitor)
            if (info && info.primary) {
                return monitor
            }
        }
        return 0
    }

    GetEligibleWindows(monitor, includeMaximized := false, newHwnd := 0) {
        result := []
        for hwnd in WinGetList() {
            info := this.GetWindowInfo(hwnd)
            if (!info.eligible) {
                continue
            }
            if (monitor && info.monitor != monitor) {
                continue
            }
            if (info.isMinimized) {
                continue
            }
            if (info.isMaximized && !includeMaximized && hwnd != newHwnd) {
                continue
            }
            if (hwnd = newHwnd) {
                info.isNew := true
                info.priority := 1.0
            }
            result.Push(info)
        }
        return this.SortWindows(result)
    }

    SortWindows(windows) {
        result := windows.Clone()
        Loop result.Length - 1 {
            position := A_Index + 1
            current := result[position]
            scan := position - 1
            while (scan >= 1 && this.CompareWindows(current, result[scan]) < 0) {
                result[scan + 1] := result[scan]
                scan -= 1
            }
            result[scan + 1] := current
        }
        return result
    }

    CompareWindows(first, second) {
        if (first.isLocked != second.isLocked) {
            return first.isLocked ? -1 : 1
        }
        if (first.isNew != second.isNew) {
            return first.isNew ? -1 : 1
        }
        if (first.isForeground != second.isForeground) {
            return first.isForeground ? -1 : 1
        }
        if (first.rect.w * first.rect.h != second.rect.w * second.rect.h) {
            return first.rect.w * first.rect.h > second.rect.w * second.rect.h ? -1 : 1
        }
        return StrCompare(first.id, second.id)
    }

    ToggleLock(hwnd) {
        info := this.GetWindowInfo(hwnd)
        if (!info.eligible || info.isMinimized || info.isMaximized) {
            return -1
        }
        if (this.Locks.Has(info.id)) {
            this.Locks.Delete(info.id)
            return 0
        }
        this.Locks[info.id] := true
        return 1
    }

    IsLocked(hwnd) {
        info := this.GetWindowInfo(hwnd)
        return info.eligible && info.isLocked
    }

    OnMoveSizeStart(hwnd) {
        key := this.IdentityFromHandle(hwnd)
        if (key = "") {
            return
        }
        this.Interacting[key] := true
        if (this.Applying) {
            this.MotionCancelRequested := true
        }
    }

    OnMoveSizeEnd(hwnd) {
        key := this.IdentityFromHandle(hwnd)
        if (key = "") {
            return
        }
        if (this.Interacting.Has(key)) {
            this.Interacting.Delete(key)
        }
        this.RecentUserChanges[key] := A_TickCount
    }

    BeginApply() {
        this.Applying := true
        this.MotionCancelRequested := false
    }

    EndApply() {
        this.Applying := false
        this.MotionCancelRequested := false
    }

    ShouldCancelMotion() {
        return this.Applying && this.MotionCancelRequested
    }

    VerifyWindow(window) {
        if (!this.IsValidWindow(window.hwnd)) {
            return false
        }
        pid := 0
        DllCall("GetWindowThreadProcessId", "Ptr", window.hwnd, "UInt*", &pid)
        if (pid != window.pid) {
            return false
        }
        info := this.GetWindowInfo(window.hwnd)
        if (!info.eligible || info.isMinimized || info.isMaximized || info.isInteracting) {
            return false
        }
        if (window.HasProp("workArea") && !Geometry.Equal(info.workArea, window.workArea, 2)) {
            return false
        }
        return true
    }
}
