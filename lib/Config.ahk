class Config {
    __New(path) {
        this.Path := path
        this.Reload()
    }

    Reload() {
        this.Enabled := this.ReadBool("General", "Enabled", true)
        this.DebugLogging := this.ReadBool("General", "DebugLogging", false)
        this.DryRun := this.ReadBool("General", "DryRun", false)
        this.ReflowOnNewWindow := this.ReadBool("General", "ReflowOnNewWindow", true)
        this.AutoRestoreEligibleNewMaximized := this.ReadBool("General", "AutoRestoreEligibleNewMaximized", true)

        this.NewWidthRatio := this.ReadNumber("WindowSize", "NewWidthRatio", 0.65, 0.25, 1.0)
        this.NewHeightRatio := this.ReadNumber("WindowSize", "NewHeightRatio", 0.70, 0.25, 1.0)
        this.MarginPx := this.ReadInteger("WindowSize", "MarginPx", 16, 0, 128)
        this.MinNewWindowShrinkRatio := this.ReadNumber("WindowSize", "MinNewWindowShrinkRatio", 0.75, 0.25, 1.0)

        this.AutoMoveExistingWindows := this.ReadBool("AutoReflow", "AutoMoveExistingWindows", true)
        this.AutoResizeExistingWindows := this.ReadBool("AutoReflow", "AutoResizeExistingWindows", false)
        this.MaxMovedExistingWindows := this.ReadInteger("AutoReflow", "MaxMovedExistingWindows", 3, 0, 20)
        this.RecentlyUserMovedGraceMs := this.ReadInteger("AutoReflow", "RecentlyUserMovedGraceMs", 5000, 0, 60000)
        this.MinimumQualityImprovementRatio := this.ReadNumber("AutoReflow", "MinimumQualityImprovementRatio", 0.08, 0.0, 1.0)
        this.NewWindowDebounceMs := this.ReadInteger("AutoReflow", "NewWindowDebounceMs", 250, 50, 1000)
        this.MaxPlacementDelayMs := this.ReadInteger("AutoReflow", "MaxPlacementDelayMs", 1000, 200, 5000)
        this.ReflowCooldownMs := this.ReadInteger("AutoReflow", "ReflowCooldownMs", 750, 0, 10000)

        this.EnableManualReflow := this.ReadBool("ManualReflow", "EnableManualReflow", true)
        this.ManualAllowResizeExistingWindows := this.ReadBool("ManualReflow", "ManualAllowResizeExistingWindows", true)
        this.ManualIncludeMaximized := this.ReadBool("ManualReflow", "ManualIncludeMaximized", false)
        this.MinimumExistingSizeRatio := this.ReadNumber("ManualReflow", "MinimumExistingSizeRatio", 0.70, 0.25, 1.0)
        this.ReflowMaxIterations := this.ReadInteger("ManualReflow", "ReflowMaxIterations", 8, 1, 20)

        this.PreferAvoidFocusedWindow := this.ReadBool("Placement", "PreferAvoidFocusedWindow", true)
        this.CandidateGridSize := this.ReadInteger("Placement", "CandidateGridSize", 5, 2, 9)
        this.SolverBudgetMs := this.ReadInteger("Placement", "SolverBudgetMs", 350, 50, 2000)
        this.AllowCrossMonitorMove := this.ReadBool("Placement", "AllowCrossMonitorMove", false)
        this.PreserveZOrder := this.ReadBool("Placement", "PreserveZOrder", true)
        this.PreserveForeground := this.ReadBool("Placement", "PreserveForeground", true)

        this.SmoothMovement := this.ReadBool("Motion", "SmoothMovement", true)
        this.SmoothDurationMs := this.ReadInteger("Motion", "SmoothDurationMs", 160, 0, 400)
        this.SmoothFrameIntervalMs := this.ReadInteger("Motion", "SmoothFrameIntervalMs", 16, 8, 50)
        this.SmoothMaxDurationMs := this.ReadInteger("Motion", "SmoothMaxDurationMs", 260, 0, 600)
        if (this.SmoothDurationMs > this.SmoothMaxDurationMs) {
            this.SmoothDurationMs := this.SmoothMaxDurationMs
        }

        this.OverlapWeight := this.ReadNumber("Scoring", "OverlapWeight", 8.0, 0.0, 100.0)
        this.FocusWeight := this.ReadNumber("Scoring", "FocusWeight", 5.0, 0.0, 100.0)
        this.SizeWeight := this.ReadNumber("Scoring", "SizeWeight", 2.0, 0.0, 100.0)
        this.AutoMovementWeight := this.ReadNumber("Scoring", "AutoMovementWeight", 1.2, 0.0, 100.0)
        this.ManualMovementWeight := this.ReadNumber("Scoring", "ManualMovementWeight", 0.45, 0.0, 100.0)
        this.SpacingWeight := this.ReadNumber("Scoring", "SpacingWeight", 0.35, 0.0, 100.0)
        this.CenterWeight := this.ReadNumber("Scoring", "CenterWeight", 0.25, 0.0, 100.0)

        this.UndoEnabled := this.ReadBool("Undo", "Enabled", true)
        this.HistoryDepth := this.ReadInteger("Undo", "HistoryDepth", 1, 1, 10)
        this.ProcessExclusions := this.ReadList("Exclusions", "ProcessNames", "")
        this.WindowClassExclusions := this.ReadList("Exclusions", "WindowClasses", "")

        this.HotkeyPause := this.ReadHotkey("Hotkeys", "Pause", "^!+p")
        this.HotkeyReflowCurrent := this.ReadHotkey("Hotkeys", "ReflowCurrentMonitor", "^!+l")
        this.HotkeyUndo := this.ReadHotkey("Hotkeys", "UndoLastLayout", "^!+z")
        this.HotkeyToggleLock := this.ReadHotkey("Hotkeys", "ToggleLockActive", "^!+k")
        this.HotkeyPlaceActive := this.ReadHotkey("Hotkeys", "PlaceActive", "^!+o")
        this.HotkeyReload := this.ReadHotkey("Hotkeys", "ReloadConfig", "^!+r")
    }

    ReadBool(section, key, defaultValue) {
        value := Trim(IniRead(this.Path, section, key, defaultValue ? "1" : "0"))
        return value = "1" || StrLower(value) = "true" || StrLower(value) = "yes"
    }

    ReadInteger(section, key, defaultValue, minimum, maximum) {
        return Round(this.ReadNumber(section, key, defaultValue, minimum, maximum))
    }

    ReadNumber(section, key, defaultValue, minimum, maximum) {
        raw := Trim(IniRead(this.Path, section, key, String(defaultValue)))
        if (!IsNumber(raw)) {
            return defaultValue
        }
        return Geometry.Clamp(raw + 0.0, minimum, maximum)
    }

    ReadHotkey(section, key, defaultValue) {
        value := Trim(IniRead(this.Path, section, key, defaultValue))
        return value = "" ? defaultValue : value
    }

    ReadList(section, key, defaultValue) {
        raw := IniRead(this.Path, section, key, defaultValue)
        result := []
        for item in StrSplit(raw, ",") {
            cleaned := Trim(item)
            if (cleaned != "") {
                result.Push(StrLower(cleaned))
            }
        }
        return result
    }
}
