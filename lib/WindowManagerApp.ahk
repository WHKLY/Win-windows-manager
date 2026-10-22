class WindowManagerApp {
    __New(baseDirectory) {
        this.BaseDirectory := RTrim(baseDirectory, "\/")
        this.ConfigPath := this.BaseDirectory "\config.ini"
        this.Config := 0
        this.Logger := 0
        this.Registry := 0
        this.History := 0
        this.Events := 0
        this.Busy := false
        this.Paused := false
        this.Pending := Map()
        this.ProcessScheduled := false
        this.MaxPendingCandidates := 256
        this.RegisteredHotkeys := []
        this.LastLayoutTick := 0
        this.CleanedUp := false
        this.SmokeTestMode := false
    }

    Start() {
        this.LoadConfig()
        if (this.SmokeTestMode) {
            this.Config.Enabled := false
            this.Config.DryRun := true
            this.Config.ReflowOnNewWindow := false
        }
        this.Logger := Logger(this.BaseDirectory "\logs", this.Config.DebugLogging)
        this.Registry := WindowRegistry(this.Config, this.Logger)
        this.History := LayoutHistory(this.Config.HistoryDepth)
        this.Events := WindowEvents(this)

        OnExit(ObjBindMethod(this, "HandleExit"))
        this.BuildTrayMenu()
        this.RegisterHotkeys()
        this.Registry.CaptureStartupWindows()
        this.Events.Start()

        this.Logger.Info("application_started", Map(
            "version", "0.1.0",
            "compiled", A_IsCompiled,
            "dry_run", this.Config.DryRun,
            "smooth_movement", this.Config.SmoothMovement,
            "smoke_test", this.SmokeTestMode
        ))
        TrayTip(
            "WindowswindowsManager 已启动",
            this.Config.DryRun ? "当前为 DryRun 模式" : "自动模式已启用",
            1
        )
    }

    LoadConfig() {
        this.Config := Config(this.ConfigPath)
        if (this.Registry) {
            this.Registry.Config := this.Config
        }
        if (this.Logger) {
            this.Logger.DebugEnabled := this.Config.DebugLogging
        }
    }

    OnWindowEvent(eventNumber, hwnd) {
        switch eventNumber {
            case WindowEvents.EVENT_SYSTEM_MOVESIZESTART:
                this.Registry.OnMoveSizeStart(hwnd)
            case WindowEvents.EVENT_SYSTEM_MOVESIZEEND:
                this.Registry.OnMoveSizeEnd(hwnd)
            case WindowEvents.EVENT_OBJECT_DESTROY:
                if (this.Pending.Has(hwnd)) {
                    this.Pending.Delete(hwnd)
                }
                this.Registry.ForgetWindow(hwnd)
            case WindowEvents.EVENT_OBJECT_SHOW:
                this.QueueNewWindow(hwnd)
        }
    }

    QueueNewWindow(hwnd) {
        if (!hwnd || this.Registry.IsSeen(hwnd)) {
            return
        }
        if (!this.Config.Enabled || !this.Config.ReflowOnNewWindow || this.Paused) {
            this.Registry.MarkSeen(hwnd)
            return
        }
        if (this.Pending.Has(hwnd)) {
            this.Pending[hwnd].lastSeen := A_TickCount
            return
        }
        if (this.Pending.Count >= this.MaxPendingCandidates) {
            this.Logger.Warn("new_window_queue_full", Map("hwnd", hwnd))
            return
        }
        this.Pending[hwnd] := {
            firstSeen: A_TickCount,
            lastSeen: A_TickCount
        }
        this.ScheduleCandidateProcessing(this.Config.NewWindowDebounceMs)
    }

    ProcessNewCandidates(*) {
        this.ProcessScheduled := false
        if (this.CleanedUp) {
            return
        }
        if (this.Busy || this.Registry.Applying) {
            this.ScheduleCandidateProcessing(100)
            return
        }
        if (!this.Config.Enabled || !this.Config.ReflowOnNewWindow || this.Paused) {
            this.MarkAllPendingSeen()
            return
        }

        remainingCooldown := this.Config.ReflowCooldownMs - (A_TickCount - this.LastLayoutTick)
        if (this.LastLayoutTick && remainingCooldown > 0) {
            this.ScheduleCandidateProcessing(remainingCooldown)
            return
        }

        candidates := []
        for hwnd, state in this.Pending {
            candidates.Push({hwnd: hwnd, firstSeen: state.firstSeen, lastSeen: state.lastSeen})
        }
        Loop candidates.Length - 1 {
            position := A_Index + 1
            current := candidates[position]
            scan := position - 1
            while (scan >= 1 && this.IsEarlierCandidate(current, candidates[scan])) {
                candidates[scan + 1] := candidates[scan]
                scan -= 1
            }
            candidates[scan + 1] := current
        }

        for candidate in candidates {
            hwnd := candidate.hwnd
            info := this.Registry.GetWindowInfo(hwnd)
            elapsed := A_TickCount - candidate.firstSeen
            if (!info.eligible) {
                if (info.reason = "not_visible") {
                    if (elapsed < this.Config.MaxPlacementDelayMs) {
                        continue
                    }
                    this.Pending.Delete(hwnd)
                    continue
                }
                this.Pending.Delete(hwnd)
                this.Registry.MarkSeen(hwnd)
                continue
            }
            if (info.isMinimized) {
                if (elapsed < this.Config.MaxPlacementDelayMs) {
                    continue
                }
                this.Pending.Delete(hwnd)
                this.Registry.MarkSeen(hwnd)
                continue
            }
            if (info.isInteracting) {
                continue
            }
            if (info.isMaximized) {
                if (!this.Config.AutoRestoreEligibleNewMaximized) {
                    this.Pending.Delete(hwnd)
                    this.Registry.MarkSeen(hwnd)
                    continue
                }
                DllCall("ShowWindowAsync", "Ptr", hwnd, "Int", 9)
                Sleep(60)
                info := this.Registry.GetWindowInfo(hwnd)
                if (!info.eligible || info.isMaximized) {
                    this.Pending.Delete(hwnd)
                    this.Registry.MarkSeen(hwnd)
                    continue
                }
            }

            this.Pending.Delete(hwnd)
            this.Registry.MarkSeen(hwnd)
            this.HandleNewWindow(info)
            if (this.Pending.Count) {
                this.ScheduleCandidateProcessing(Max(100, this.Config.ReflowCooldownMs))
            }
            return
        }

        if (this.Pending.Count) {
            this.ScheduleCandidateProcessing(100)
        }
    }

    ScheduleCandidateProcessing(delayMs) {
        if (this.ProcessScheduled || this.CleanedUp) {
            return
        }
        this.ProcessScheduled := true
        SetTimer(ObjBindMethod(this, "ProcessNewCandidates"), -Max(1, delayMs))
    }

    MarkAllPendingSeen() {
        for hwnd, state in this.Pending {
            this.Registry.MarkSeen(hwnd)
        }
        this.Pending := Map()
    }

    HandleNewWindow(newWindow) {
        workInfo := this.Registry.GetMonitorInfo(newWindow.monitor)
        if (!workInfo) {
            this.Logger.Warn("new_window_monitor_missing", Map("id", newWindow.id))
            return
        }
        windows := this.Registry.GetEligibleWindows(newWindow.monitor, false, newWindow.hwnd)
        if (!this.ContainsWindow(windows, newWindow.id)) {
            this.Logger.Warn("new_window_not_eligible_after_debounce", Map("id", newWindow.id))
            return
        }

        plan := LayoutPlanner.PlanAuto(windows, workInfo.workArea, this.Config, newWindow.id)
        this.ExecutePlan(windows, plan, "auto_new", "new_window_detected")
    }

    ReflowCurrentMonitor(*) {
        if (!this.Config.EnableManualReflow) {
            this.ShowTip("手动重排已禁用")
            return
        }
        monitor := this.GetScopeMonitor()
        active := this.Registry.GetForegroundWindow()
        planInfo := this.BuildManualPlanForMonitor(monitor, active, "manual_reflow")
        if (!planInfo) {
            this.ShowTip("当前显示器没有可排布的窗口")
            return
        }
        this.ExecutePlan(planInfo.windows, planInfo.plan, "manual_reflow", "manual_current_monitor")
    }

    ReflowAllMonitors(*) {
        if (!this.Config.EnableManualReflow) {
            this.ShowTip("手动重排已禁用")
            return
        }
        monitors := this.Registry.GetMonitorList()
        active := this.Registry.GetForegroundWindow()
        combinedWindows := []
        combinedTargets := Map()
        combinedChanged := []
        totalBefore := 0.0
        totalAfter := 0.0
        valid := false

        for monitor in monitors {
            planInfo := this.BuildManualPlanForMonitor(monitor, active, "manual_reflow")
            if (!planInfo || !planInfo.plan.Valid) {
                continue
            }
            valid := true
            for window in planInfo.windows {
                combinedWindows.Push(window)
            }
            for id, rect in planInfo.plan.Targets {
                combinedTargets[id] := Geometry.CopyRect(rect)
            }
            for id in planInfo.plan.ChangedIds {
                combinedChanged.Push(id)
            }
            totalBefore += planInfo.plan.ScoreBefore.Total
            totalAfter += planInfo.plan.ScoreAfter.Total
        }

        if (!valid || combinedWindows.Length = 0) {
            this.ShowTip("没有可排布的窗口")
            return
        }
        plan := {
            Valid: true,
            Targets: combinedTargets,
            ChangedIds: combinedChanged,
            Strategy: "manual_all_monitors",
            Reason: "all_monitors_each_kept_on_own_display",
            ScoreBefore: {Valid: true, Total: totalBefore},
            ScoreAfter: {Valid: true, Total: totalAfter},
            QualityImprovementRatio: LayoutPlanner.ImprovementRatio(totalBefore, totalAfter)
        }
        this.ExecutePlan(combinedWindows, plan, "manual_reflow", "manual_all_monitors")
    }

    BuildManualPlanForMonitor(monitor, activeId, mode) {
        monitorInfo := this.Registry.GetMonitorInfo(monitor)
        if (!monitorInfo) {
            return 0
        }
        windows := this.Registry.GetEligibleWindows(
            monitor,
            this.Config.ManualIncludeMaximized,
            0
        )
        if (windows.Length = 0) {
            return 0
        }
        if (!this.ContainsWindow(windows, activeId)) {
            activeId := ""
        }
        plan := LayoutPlanner.PlanManual(windows, monitorInfo.workArea, this.Config, activeId)
        return {
            monitor: monitor,
            workArea: monitorInfo.workArea,
            windows: windows,
            plan: plan
        }
    }

    PlaceActiveWindow(*) {
        active := this.Registry.GetForegroundWindow()
        if (!active) {
            this.ShowTip("没有活动窗口")
            return
        }
        info := this.Registry.GetWindowInfo(active)
        if (!info.eligible || info.isMinimized || info.isMaximized) {
            this.ShowTip("当前窗口不参与布局")
            return
        }
        workInfo := this.Registry.GetMonitorInfo(info.monitor)
        if (!workInfo) {
            return
        }
        windows := this.Registry.GetEligibleWindows(info.monitor, false, 0)
        if (!this.ContainsWindow(windows, info.id)) {
            this.ShowTip("当前窗口不参与布局")
            return
        }
        plan := LayoutPlanner.PlanSingle(
            windows,
            info.id,
            workInfo.workArea,
            this.Config,
            "manual_one"
        )
        this.ExecutePlan(windows, plan, "manual_one", "manual_active_window")
    }

    UndoLastLayout(*) {
        if (!this.Config.UndoEnabled) {
            this.ShowTip("撤销已禁用")
            return
        }
        snapshot := this.History.GetLatest()
        if (!snapshot) {
            this.ShowTip("没有可撤销的布局")
            return
        }

        windows := []
        targets := Map()
        for entry in snapshot.entries {
            currentInfo := this.Registry.GetWindowInfo(entry.hwnd)
            if (!currentInfo.eligible || currentInfo.isLocked || currentInfo.isInteracting) {
                continue
            }
            if (currentInfo.pid != entry.pid || currentInfo.monitor != entry.monitor) {
                continue
            }
            if (!Geometry.IsWithin(entry.rect, currentInfo.workArea, 2)) {
                continue
            }
            windows.Push(currentInfo)
            targets[currentInfo.id] := Geometry.CopyRect(entry.rect)
        }

        if (windows.Length = 0) {
            this.ShowTip("上次布局涉及的窗口已不可恢复")
            this.History.Clear()
            return
        }

        plan := {
            Valid: true,
            Targets: targets,
            ChangedIds: LayoutPlanner.ChangedIds(windows, targets),
            Strategy: "undo_last_layout",
            Reason: "restore_snapshot",
            ScoreBefore: {Valid: true, Total: 0.0},
            ScoreAfter: {Valid: true, Total: 0.0},
            QualityImprovementRatio: 0.0
        }
        result := this.ExecutePlan(windows, plan, "undo", "undo_last_layout", false)
        if (result && result.Success && result.AppliedCount > 0) {
            this.History.Clear()
        }
    }

    ExecutePlan(windows, plan, mode, reason, saveHistory := true) {
        if (!plan || !plan.Valid) {
            this.Logger.Warn("layout_plan_invalid", Map(
                "mode", mode,
                "reason", plan ? plan.Reason : "missing_plan"
            ))
            this.ShowTip("布局计划不可行")
            return {Success: false, AppliedCount: 0, Cancelled: false}
        }
        if (plan.ChangedIds.Length = 0) {
            this.LastLayoutTick := A_TickCount
            this.Logger.Info("layout_no_change", Map(
                "mode", mode,
                "strategy", plan.Strategy
            ))
            this.ShowTip("当前布局已较优")
            return {Success: true, NoChange: true, AppliedCount: 0, Cancelled: false}
        }

        if (this.Config.DryRun) {
            this.LastLayoutTick := A_TickCount
            this.Logger.Info("layout_dry_run", this.PlanFields(plan, mode, reason))
            this.ShowTip("DryRun：已生成布局计划，未移动窗口")
            return {Success: true, DryRun: true, AppliedCount: 0, Cancelled: false}
        }

        if (this.Busy) {
            this.Logger.Debug("layout_skipped_busy", Map("mode", mode))
            return {Success: false, Busy: true, AppliedCount: 0, Cancelled: false}
        }

        this.Busy := true
        this.Registry.BeginApply()
        result := 0
        try {
            options := {
                Smooth: this.Config.SmoothMovement,
                DurationMs: this.Config.SmoothDurationMs,
                FrameIntervalMs: this.Config.SmoothFrameIntervalMs,
                MaxDurationMs: this.Config.SmoothMaxDurationMs,
                Precheck: ObjBindMethod(this.Registry, "VerifyWindow"),
                CancelCheck: ObjBindMethod(this.Registry, "ShouldCancelMotion")
            }
            try {
                result := LayoutExecutor.Apply(windows, plan, options)
            } catch Error as err {
                this.Logger.Error("layout_executor_exception", Map(
                    "mode", mode,
                    "error", err.Message,
                    "line", err.Line
                ))
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
                    Errors: [err.Message]
                }
            }
        } finally {
            this.Registry.EndApply()
            this.Busy := false
            this.LastLayoutTick := A_TickCount
        }

        if (!result) {
            result := {Success: false, AppliedCount: 0, Cancelled: false}
        }
        if (saveHistory && result.AppliedCount > 0) {
            this.History.Save(result.Before, mode, reason)
        }

        fields := this.PlanFields(plan, mode, reason)
        fields["elapsed_ms"] := result.ElapsedMs
        fields["applied"] := result.AppliedCount
        fields["failed"] := result.FailedCount
        fields["cancelled"] := result.Cancelled
        if (result.Success) {
            this.Logger.Info("layout_applied", fields)
            this.ShowTip(Format("已排布 {1} 个窗口，耗时 {2} ms", result.AppliedCount, result.ElapsedMs))
        } else if (result.Cancelled) {
            this.Logger.Warn("layout_cancelled", fields)
            this.ShowTip("平滑移动已安全中止")
        } else {
            this.Logger.Warn("layout_failed", fields)
            this.ShowTip("部分窗口未能按计划移动")
        }
        return result
    }

    PlanFields(plan, mode, reason) {
        return Map(
            "mode", mode,
            "reason", reason,
            "strategy", plan.Strategy,
            "quality_gain", Round(plan.QualityImprovementRatio, 4),
            "score_before", Round(plan.ScoreBefore.Total, 4),
            "score_after", Round(plan.ScoreAfter.Total, 4),
            "changed", plan.ChangedIds.Length,
            "smooth", this.Config.SmoothMovement,
            "duration_ms", this.Config.SmoothDurationMs
        )
    }

    TogglePause(*) {
        this.Paused := !this.Paused
        if (this.Paused) {
            this.MarkAllPendingSeen()
        }
        this.BuildTrayMenu()
        this.Logger.Info("auto_mode_toggled", Map("paused", this.Paused))
        this.ShowTip(this.Paused ? "自动模式已暂停，手动命令仍可用" : "自动模式已恢复")
    }

    ToggleLockActive(*) {
        hwnd := this.Registry.GetForegroundWindow()
        if (!hwnd) {
            this.ShowTip("没有活动窗口")
            return
        }
        state := this.Registry.ToggleLock(hwnd)
        if (state = -1) {
            this.ShowTip("当前窗口不支持锁定")
        } else {
            this.ShowTip(state ? "当前窗口已锁定" : "当前窗口已解锁")
            this.Logger.Info("window_lock_toggled", Map("hwnd", hwnd, "locked", state))
        }
        this.BuildTrayMenu()
    }

    ReloadConfiguration(*) {
        try {
            this.LoadConfig()
            this.History.MaximumDepth := this.Config.HistoryDepth
            this.UnregisterHotkeys()
            this.RegisterHotkeys()
            this.BuildTrayMenu()
            this.Logger.Info("configuration_reloaded")
            this.ShowTip("配置已重新加载")
        } catch Error as err {
            this.Logger.Error("configuration_reload_failed", Map("error", err.Message))
            this.ShowTip("配置重载失败，请查看日志")
        }
    }

    RegisterHotkeys() {
        bindings := [
            {name: this.Config.HotkeyPause, method: "TogglePause"},
            {name: this.Config.HotkeyReflowCurrent, method: "ReflowCurrentMonitor"},
            {name: this.Config.HotkeyUndo, method: "UndoLastLayout"},
            {name: this.Config.HotkeyToggleLock, method: "ToggleLockActive"},
            {name: this.Config.HotkeyPlaceActive, method: "PlaceActiveWindow"},
            {name: this.Config.HotkeyReload, method: "ReloadConfiguration"}
        ]
        for binding in bindings {
            if (binding.name = "") {
                continue
            }
            try {
                Hotkey(binding.name, ObjBindMethod(this, binding.method))
                this.RegisteredHotkeys.Push(binding.name)
            } catch Error as err {
                this.Logger.Warn("hotkey_registration_failed", Map(
                    "hotkey", binding.name,
                    "error", err.Message
                ))
            }
        }
    }

    UnregisterHotkeys() {
        for hotkeyName in this.RegisteredHotkeys {
            try {
                Hotkey(hotkeyName, "Off")
            }
        }
        this.RegisteredHotkeys := []
    }

    BuildTrayMenu() {
        A_IconTip := "WindowswindowsManager"
        A_TrayMenu.Delete()
        A_TrayMenu.Add(
            this.Paused ? "恢复自动管理" : "暂停自动管理",
            ObjBindMethod(this, "TogglePause")
        )
        A_TrayMenu.Add()
        A_TrayMenu.Add("重新排布当前显示器", ObjBindMethod(this, "ReflowCurrentMonitor"))
        A_TrayMenu.Add("重新排布所有显示器", ObjBindMethod(this, "ReflowAllMonitors"))
        A_TrayMenu.Add("撤销上次布局", ObjBindMethod(this, "UndoLastLayout"))
        A_TrayMenu.Add("锁定/解锁当前窗口", ObjBindMethod(this, "ToggleLockActive"))
        A_TrayMenu.Add("重新放置当前窗口", ObjBindMethod(this, "PlaceActiveWindow"))
        A_TrayMenu.Add()
        A_TrayMenu.Add("重新加载配置", ObjBindMethod(this, "ReloadConfiguration"))
        A_TrayMenu.Add("打开日志", ObjBindMethod(this, "OpenLog"))
        A_TrayMenu.Add(
            this.IsStartupEnabled() ? "禁用开机启动" : "启用开机启动",
            ObjBindMethod(this, "ToggleStartup")
        )
        A_TrayMenu.Add()
        A_TrayMenu.Add("退出", ObjBindMethod(this, "RequestExit"))
    }

    IsStartupEnabled() {
        try {
            value := RegRead(
                "HKCU\Software\Microsoft\Windows\CurrentVersion\Run",
                "WindowswindowsManager"
            )
            return value != ""
        } catch {
            return false
        }
    }

    ToggleStartup(*) {
        key := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
        if (this.IsStartupEnabled()) {
            try {
                RegDelete(key, "WindowswindowsManager")
                this.ShowTip("开机启动已关闭")
            } catch Error as err {
                this.Logger.Error("startup_disable_failed", Map("error", err.Message))
            }
        } else {
            command := A_IsCompiled
                ? '"' A_ScriptFullPath '"'
                : '"' A_AhkPath '" "' A_ScriptFullPath '"'
            try {
                RegWrite(command, "REG_SZ", key, "WindowswindowsManager")
                this.ShowTip("开机启动已启用")
            } catch Error as err {
                this.Logger.Error("startup_enable_failed", Map("error", err.Message))
            }
        }
        this.BuildTrayMenu()
    }

    OpenLog(*) {
        try {
            Run(this.Logger.Directory)
        } catch Error as err {
            this.Logger.Error("open_log_failed", Map("error", err.Message))
        }
    }

    GetScopeMonitor() {
        active := this.Registry.GetForegroundWindow()
        monitor := this.Registry.GetWindowMonitor(active)
        if (monitor) {
            return monitor
        }
        return this.Registry.GetCursorMonitor()
    }

    ContainsWindow(windows, id) {
        if (id = "") {
            return false
        }
        for window in windows {
            if (window.id = id) {
                return true
            }
        }
        return false
    }

    IsEarlierCandidate(first, second) {
        if (first.firstSeen != second.firstSeen) {
            return first.firstSeen < second.firstSeen
        }
        return first.hwnd < second.hwnd
    }

    ShowTip(message) {
        TrayTip(message, "WindowswindowsManager", 1)
    }

    RequestExit(*) {
        ExitApp()
    }

    HandleExit(reason, code) {
        if (this.CleanedUp) {
            return 0
        }
        this.CleanedUp := true
        if (this.ProcessScheduled) {
            SetTimer(ObjBindMethod(this, "ProcessNewCandidates"), 0)
            this.ProcessScheduled := false
        }
        try {
            this.UnregisterHotkeys()
        }
        try {
            if (this.Events) {
                this.Events.Stop()
            }
        }
        try {
            if (this.Logger) {
                this.Logger.Info("application_exit", Map("reason", reason, "code", code))
            }
        }
        return 0
    }
}
