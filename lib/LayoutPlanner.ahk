class LayoutPlanner {
    static PlanAuto(windows, workArea, config, newId) {
        if (windows.Length = 0) {
            return this.InvalidPlan("no_windows")
        }
        if (newId = "" || this.FindWindowIndex(windows, newId) = 0) {
            return this.InvalidPlan("missing_new_window")
        }

        baseline := this.OriginalTargets(windows)
        scoreBefore := this.ScoreLayout(windows, baseline, workArea, "auto", config)
        deadlineA := A_TickCount + config.SolverBudgetMs
        planA := this.PlanNewOnly(windows, workArea, config, newId, baseline, scoreBefore, deadlineA)
        if (!config.AutoMoveExistingWindows || windows.Length <= 1) {
            planA.Strategy := planA.Strategy = "" ? "new_window_only" : planA.Strategy
            return planA
        }

        deadlineB := A_TickCount + config.SolverBudgetMs
        planB := this.PlanCooperative(
            windows,
            workArea,
            config,
            newId,
            baseline,
            scoreBefore,
            deadlineB
        )
        if (!planB.Valid || !planA.Valid) {
            return planA
        }

        denominator := Max(Abs(planA.ScoreAfter.Total), 0.0001)
        improvement := (planA.ScoreAfter.Total - planB.ScoreAfter.Total) / denominator
        planB.QualityImprovementRatio := improvement
        changedExisting := this.CountChangedExisting(windows, planB.Targets, newId)
        if (improvement >= config.MinimumQualityImprovementRatio
            && changedExisting <= config.MaxMovedExistingWindows) {
            planB.Strategy := "cooperative_reflow"
            planB.Reason := "quality_gain_threshold_met"
            return planB
        }

        planA.Strategy := "new_window_only"
        planA.Reason := improvement < config.MinimumQualityImprovementRatio
            ? "cooperative_gain_below_threshold"
            : "cooperative_disturbance_too_high"
        planA.QualityImprovementRatio := Max(0.0, improvement)
        planA.CooperativeChangedExisting := changedExisting
        planA.CooperativeScoreAfter := planB.ScoreAfter.Total
        planA.CooperativeTargets := planB.Targets
        return planA
    }

    static PlanNewOnly(windows, workArea, config, newId, baseline, scoreBefore, deadline := 0) {
        targets := this.CloneTargets(baseline)
        index := this.FindWindowIndex(windows, newId)
        newWindow := windows[index]
        result := this.OptimizeWindow(
            windows,
            targets,
            index,
            workArea,
            config,
            "auto_new",
            true,
            true,
            deadline
        )
        result.ScoreAfter := this.ScoreLayout(windows, targets, workArea, "auto", config)
        result.ScoreBefore := scoreBefore
        result.Valid := result.ScoreAfter.Valid
        result.Strategy := "new_window_only"
        result.Reason := "baseline_new_window_plan"
        result.ChangedIds := this.ChangedIds(windows, targets)
        result.QualityImprovementRatio := this.ImprovementRatio(scoreBefore.Total, result.ScoreAfter.Total)
        return result
    }

    static PlanCooperative(windows, workArea, config, newId, baseline, scoreBefore, deadline := 0) {
        targets := this.CloneTargets(baseline)
        newIndex := this.FindWindowIndex(windows, newId)
        selected := this.SelectCooperativeWindows(windows, newIndex, baseline, workArea, config)
        if (selected.Length = 0 && !config.AutoResizeExistingWindows) {
            plan := {
                Valid: false,
                Targets: targets,
                ScoreBefore: scoreBefore,
                Reason: "no_cooperative_windows"
            }
            return plan
        }

        rounds := Max(2, Min(4, config.ReflowMaxIterations))
        for roundNumber in [1, 2, 3, 4] {
            if (roundNumber > rounds) {
                break
            }
            this.OptimizeWindow(
                windows,
                targets,
                newIndex,
                workArea,
                config,
                "auto_new",
                true,
                true,
                deadline
            )
            for index in selected {
                if (this.DeadlineReached(deadline)) {
                    break
                }
                this.OptimizeWindow(
                    windows,
                    targets,
                    index,
                    workArea,
                    config,
                    "auto_existing",
                    true,
                    config.AutoResizeExistingWindows,
                    deadline
                )
            }
            if (this.DeadlineReached(deadline)) {
                break
            }
        }

        scoreAfter := this.ScoreLayout(windows, targets, workArea, "auto", config)
        return {
            Valid: scoreAfter.Valid,
            Targets: targets,
            ScoreBefore: scoreBefore,
            ScoreAfter: scoreAfter,
            ChangedIds: this.ChangedIds(windows, targets),
            Strategy: "cooperative_candidate",
            Reason: scoreAfter.Valid ? "cooperative_candidate_ready" : "invalid_cooperative_layout"
        }
    }

    static PlanManual(windows, workArea, config, activeId := "") {
        if (windows.Length = 0) {
            return this.InvalidPlan("no_windows")
        }

        baseline := this.OriginalTargets(windows)
        scoreBefore := this.ScoreLayout(windows, baseline, workArea, "manual", config)
        if (windows.Length = 1) {
            return this.PlanSingle(windows, windows[1].id, workArea, config, "manual_reflow")
        }

        gridTargets := this.BuildGridPlan(windows, workArea, config)
        gridScore := this.ScoreLayout(windows, gridTargets, workArea, "manual", config)
        targets := this.CloneTargets(baseline)
        if (gridScore.Valid && (!scoreBefore.Valid || gridScore.Total < scoreBefore.Total)) {
            targets := gridTargets
        }

        allowed := []
        for index, window in windows {
            if (window.isLocked || !window.canMove || window.isInteracting) {
                continue
            }
            allowed.Push(index)
        }
        allowed := this.SortByPriority(windows, allowed, activeId)
        deadline := A_TickCount + config.SolverBudgetMs

        iterations := config.ReflowMaxIterations
        Loop iterations {
            if (this.DeadlineReached(deadline)) {
                break
            }
            iteration := A_Index
            changedInRound := false
            beforeTotal := this.ScoreLayout(windows, targets, workArea, "manual", config).Total
            for index in allowed {
                if (this.DeadlineReached(deadline)) {
                    break
                }
                unchanged := this.CloneTargets(targets)
                this.OptimizeWindow(
                    windows,
                    targets,
                    index,
                    workArea,
                    config,
                    "manual_existing",
                    true,
                    config.ManualAllowResizeExistingWindows,
                    deadline
                )
                afterTotal := this.ScoreLayout(windows, targets, workArea, "manual", config).Total
                if (afterTotal + 0.0001 >= beforeTotal) {
                    targets := unchanged
                } else {
                    changedInRound := true
                    beforeTotal := afterTotal
                }
            }
            if (!changedInRound) {
                break
            }
        }

        scoreAfter := this.ScoreLayout(windows, targets, workArea, "manual", config)
        if (!scoreAfter.Valid || scoreAfter.Total + 0.001 >= scoreBefore.Total) {
            targets := baseline
            scoreAfter := scoreBefore
        }

        changedIds := this.ChangedIds(windows, targets)
        return {
            Valid: scoreAfter.Valid,
            Targets: targets,
            ScoreBefore: scoreBefore,
            ScoreAfter: scoreAfter,
            ChangedIds: changedIds,
            Strategy: changedIds.Length = 0 ? "already_optimal" : "manual_joint_reflow",
            Reason: changedIds.Length = 0 ? "no_significant_improvement" : "joint_layout_selected",
            QualityImprovementRatio: this.ImprovementRatio(scoreBefore.Total, scoreAfter.Total)
        }
    }

    static PlanSingle(windows, targetId, workArea, config, mode := "manual_one") {
        index := this.FindWindowIndex(windows, targetId)
        if (!index) {
            return this.InvalidPlan("missing_target_window")
        }
        baseline := this.OriginalTargets(windows)
        scoreBefore := this.ScoreLayout(windows, baseline, workArea, "manual", config)
        targets := this.CloneTargets(baseline)
        window := windows[index]
        if (windows.Length = 1 && !window.isLocked && !window.isInteracting && window.canMove) {
            desired := window.canResize
                ? this.DefaultNewRect(window, workArea, config)
                : this.CenteredRect(window.w, window.h, workArea, config.MarginPx)
            targets[window.id] := desired
            scoreAfter := this.ScoreLayout(windows, targets, workArea, "manual", config)
            return {
                Valid: scoreAfter.Valid,
                Targets: targets,
                ScoreBefore: scoreBefore,
                ScoreAfter: scoreAfter,
                ChangedIds: this.ChangedIds(windows, targets),
                Strategy: "single_window_reflow",
                Reason: "single_window_centered",
                QualityImprovementRatio: this.ImprovementRatio(scoreBefore.Total, scoreAfter.Total)
            }
        }
        this.OptimizeWindow(
            windows,
            targets,
            index,
            workArea,
            config,
            mode,
            true,
            true,
            A_TickCount + config.SolverBudgetMs
        )
        scoreAfter := this.ScoreLayout(windows, targets, workArea, "manual", config)
        return {
            Valid: scoreAfter.Valid,
            Targets: targets,
            ScoreBefore: scoreBefore,
            ScoreAfter: scoreAfter,
            ChangedIds: this.ChangedIds(windows, targets),
            Strategy: "single_window_reflow",
            Reason: "active_window_reposition",
            QualityImprovementRatio: this.ImprovementRatio(scoreBefore.Total, scoreAfter.Total)
        }
    }

    static CenteredRect(width, height, workArea, margin) {
        width := Min(width, Max(1, workArea.w - margin * 2))
        height := Min(height, Max(1, workArea.h - margin * 2))
        x := workArea.x + Round((workArea.w - width) / 2)
        y := workArea.y + Round((workArea.h - height) / 2)
        return Geometry.ClampRect(Geometry.Rect(x, y, width, height), workArea, margin)
    }

    static OptimizeWindow(windows, targets, index, workArea, config, mode, allowMove, allowResize, deadline := 0) {
        window := windows[index]
        if (!allowMove || window.isLocked || window.isInteracting || !window.canMove) {
            return {
                Targets: targets,
                Valid: true,
                Reason: "window_protected"
            }
        }

        current := targets[window.id]
        best := Geometry.CopyRect(current)
        bestScore := this.ScoreLayout(windows, targets, workArea, this.ModeFamily(mode), config)
        sizes := this.SizeCandidates(window, current, workArea, config, mode, allowResize)

        for size in sizes {
            for candidate in this.PositionCandidates(window, current, size, windows, targets, workArea, config) {
                if (this.DeadlineReached(deadline)) {
                    break 2
                }
                trial := this.CloneTargets(targets)
                trial[window.id] := candidate
                score := this.ScoreLayout(windows, trial, workArea, this.ModeFamily(mode), config)
                if (score.Valid && score.Total + 0.0001 < bestScore.Total) {
                    best := candidate
                    bestScore := score
                }
            }
        }

        targets[window.id] := best
        return {
            Targets: targets,
            Valid: bestScore.Valid,
            Score: bestScore,
            Reason: "best_candidate_selected"
        }
    }

    static SizeCandidates(window, current, workArea, config, mode, allowResize) {
        sizes := []
        if (!allowResize || !window.canResize) {
            this.AddSize(sizes, current.w, current.h)
            return sizes
        }
        this.AddWindowSize(sizes, window, workArea, config, current.w, current.h)

        desired := this.DefaultNewRect(window, workArea, config)
        if (mode = "auto_new" || mode = "manual_one") {
            this.AddWindowSize(sizes, window, workArea, config, desired.w, desired.h)
        }

        if (mode = "manual_existing" || mode = "auto_existing") {
            minimumRatio := mode = "manual_existing" ? config.MinimumExistingSizeRatio : 1.0
            for ratio in [0.95, 0.90, 0.85, 0.80] {
                if (ratio < minimumRatio) {
                    continue
                }
                this.AddWindowSize(
                    sizes,
                    window,
                    workArea,
                    config,
                    current.w * ratio,
                    current.h * ratio
                )
            }
            if (mode = "manual_existing") {
                minimumWidth := current.w * minimumRatio
                minimumHeight := current.h * minimumRatio
                this.AddWindowSize(
                    sizes,
                    window,
                    workArea,
                    config,
                    Max(desired.w, minimumWidth),
                    Max(desired.h, minimumHeight)
                )
            }
        }
        return sizes
    }

    static AddWindowSize(sizes, window, workArea, config, width, height) {
        width := this.ClampDimension(width, window.minW, window.maxW, workArea.w - 2 * config.MarginPx)
        height := this.ClampDimension(height, window.minH, window.maxH, workArea.h - 2 * config.MarginPx)
        this.AddSize(sizes, width, height)
    }

    static AddSize(sizes, width, height) {
        width := Round(width)
        height := Round(height)
        if (width < 1 || height < 1) {
            return
        }
        for size in sizes {
            if (Abs(size.w - width) <= 1 && Abs(size.h - height) <= 1) {
                return
            }
        }
        sizes.Push({w: width, h: height})
    }

    static PositionCandidates(window, current, size, windows, targets, workArea, config) {
        margin := config.MarginPx
        width := Min(size.w, Max(1, workArea.w - 2 * margin))
        height := Min(size.h, Max(1, workArea.h - 2 * margin))
        left := workArea.x + margin
        top := workArea.y + margin
        right := workArea.x + workArea.w - margin - width
        bottom := workArea.y + workArea.h - margin - height
        centerX := workArea.x + Round((workArea.w - width) / 2)
        centerY := workArea.y + Round((workArea.h - height) / 2)
        candidates := []

        this.AddPosition(candidates, current.x, current.y, width, height, workArea, margin)
        this.AddPosition(candidates, centerX, centerY, width, height, workArea, margin)
        this.AddPosition(candidates, left, top, width, height, workArea, margin)
        this.AddPosition(candidates, right, top, width, height, workArea, margin)
        this.AddPosition(candidates, left, bottom, width, height, workArea, margin)
        this.AddPosition(candidates, right, bottom, width, height, workArea, margin)
        this.AddPosition(candidates, left, centerY, width, height, workArea, margin)
        this.AddPosition(candidates, right, centerY, width, height, workArea, margin)
        this.AddPosition(candidates, centerX, top, width, height, workArea, margin)
        this.AddPosition(candidates, centerX, bottom, width, height, workArea, margin)

        gridSize := config.CandidateGridSize
        Loop gridSize {
            row := A_Index - 1
            Loop gridSize {
                column := A_Index - 1
                x := workArea.x + margin + Round((workArea.w - 2 * margin - width) * column / Max(1, gridSize - 1))
                y := workArea.y + margin + Round((workArea.h - 2 * margin - height) * row / Max(1, gridSize - 1))
                this.AddPosition(candidates, x, y, width, height, workArea, margin)
            }
        }

        for other in windows {
            if (other.id = window.id) {
                continue
            }
            otherRect := targets[other.id]
            this.AddPosition(candidates, otherRect.x - width - margin, otherRect.y, width, height, workArea, margin)
            this.AddPosition(candidates, otherRect.x + otherRect.w + margin, otherRect.y, width, height, workArea, margin)
            this.AddPosition(candidates, otherRect.x, otherRect.y - height - margin, width, height, workArea, margin)
            this.AddPosition(candidates, otherRect.x, otherRect.y + otherRect.h + margin, width, height, workArea, margin)
            this.AddPosition(candidates, otherRect.x, otherRect.y, width, height, workArea, margin)
        }

        return candidates
    }

    static AddPosition(candidates, x, y, width, height, workArea, margin) {
        rect := Geometry.ClampRect(Geometry.Rect(x, y, width, height), workArea, margin)
        for candidate in candidates {
            if (Geometry.Equal(candidate, rect)) {
                return
            }
        }
        candidates.Push(rect)
    }

    static DefaultNewRect(window, workArea, config) {
        if (!window.canResize) {
            return Geometry.Rect(window.x, window.y, window.w, window.h)
        }
        width := Round(workArea.w * config.NewWidthRatio)
        height := Round(workArea.h * config.NewHeightRatio)
        width := this.ClampDimension(width, window.minW, window.maxW, workArea.w - 2 * config.MarginPx)
        height := this.ClampDimension(height, window.minH, window.maxH, workArea.h - 2 * config.MarginPx)
        x := workArea.x + Round((workArea.w - width) / 2)
        y := workArea.y + Round((workArea.h - height) / 2)
        return Geometry.ClampRect(Geometry.Rect(x, y, width, height), workArea, config.MarginPx)
    }

    static ClampDimension(value, minimum, maximum, workLimit) {
        upper := Min(Max(1, maximum), Max(1, workLimit))
        lower := Min(Max(1, minimum), upper)
        return Geometry.Clamp(Round(value), lower, upper)
    }

    static BuildGridPlan(windows, workArea, config) {
        baseline := this.OriginalTargets(windows)
        movable := []
        for index, window in windows {
            if (!window.isLocked && window.canMove && !window.isInteracting) {
                movable.Push(index)
            }
        }
        if (movable.Length = 0) {
            return baseline
        }

        count := movable.Length
        aspect := workArea.w / Max(1, workArea.h)
        columns := Geometry.Clamp(Ceil(Sqrt(count * aspect)), 1, count)
        rows := Ceil(count / columns)
        cellWidth := Max(1, (workArea.w - (columns + 1) * config.MarginPx) / columns)
        cellHeight := Max(1, (workArea.h - (rows + 1) * config.MarginPx) / rows)
        targets := this.CloneTargets(baseline)

        for position, index in movable {
            window := windows[index]
            column := Mod(position - 1, columns)
            row := Floor((position - 1) / columns)
            cellX := workArea.x + config.MarginPx + column * (cellWidth + config.MarginPx)
            cellY := workArea.y + config.MarginPx + row * (cellHeight + config.MarginPx)
            width := targets[window.id].w
            height := targets[window.id].h
            if (window.canResize) {
                width := this.ClampDimension(Min(width, cellWidth), window.minW, window.maxW, cellWidth)
                height := this.ClampDimension(Min(height, cellHeight), window.minH, window.maxH, cellHeight)
            }
            x := Round(cellX + (cellWidth - width) / 2)
            y := Round(cellY + (cellHeight - height) / 2)
            targets[window.id] := Geometry.ClampRect(Geometry.Rect(x, y, width, height), workArea, config.MarginPx)
        }
        return targets
    }

    static SelectCooperativeWindows(windows, newIndex, baseline, workArea, config) {
        candidates := []
        newRect := baseline[windows[newIndex].id]
        for index, window in windows {
            if (index = newIndex || window.isLocked || window.isInteracting
                || !window.canMove || window.recentlyUserChanged) {
                continue
            }
            overlap := Geometry.IntersectionArea(window.rect, newRect)
            distance := Geometry.Distance(Geometry.Center(window.rect), Geometry.Center(newRect))
            candidates.Push({index: index, overlap: overlap, distance: distance, id: window.id})
        }
        selected := []
        pool := candidates.Clone()
        while (pool.Length > 0) {
            if (selected.Length >= config.MaxMovedExistingWindows) {
                break
            }
            bestPosition := 1
            Loop pool.Length - 1 {
                position := A_Index + 1
                if (this.IsBetterCooperativeCandidate(pool[position], pool[bestPosition])) {
                    bestPosition := position
                }
            }
            selected.Push(pool[bestPosition].index)
            pool.RemoveAt(bestPosition)
        }
        return selected
    }

    static SortByPriority(windows, indices, activeId := "") {
        result := indices.Clone()
        Loop result.Length - 1 {
            position := A_Index + 1
            current := result[position]
            scan := position - 1
            while (scan >= 1 && this.ComparePriority(windows, current, result[scan], activeId) < 0) {
                result[scan + 1] := result[scan]
                scan -= 1
            }
            result[scan + 1] := current
        }
        return result
    }

    static ComparePriority(windows, firstIndex, secondIndex, activeId) {
        firstPriority := this.SortPriority(windows, firstIndex, activeId)
        secondPriority := this.SortPriority(windows, secondIndex, activeId)
        if (firstPriority != secondPriority) {
            return firstPriority > secondPriority ? -1 : 1
        }
        return StrCompare(windows[firstIndex].id, windows[secondIndex].id)
    }

    static IsBetterCooperativeCandidate(first, second) {
        if (first.overlap != second.overlap) {
            return first.overlap > second.overlap
        }
        if (first.distance != second.distance) {
            return first.distance < second.distance
        }
        return StrCompare(first.id, second.id) < 0
    }

    static SortPriority(windows, index, activeId) {
        window := windows[index]
        priority := window.priority
        if (window.id = activeId) {
            priority += 1.0
        }
        if (window.isNew) {
            priority += 0.5
        }
        return priority
    }

    static ScoreLayout(windows, targets, workArea, mode, config) {
        n := windows.Length
        if (n = 0 || workArea.w <= 0 || workArea.h <= 0) {
            return {Valid: false, Total: 999999, Reason: "empty_layout"}
        }

        valid := true
        overlapRaw := 0.0
        focusRaw := 0.0
        sizeRaw := 0.0
        movementRaw := 0.0
        spacingRaw := 0.0
        centerRaw := 0.0
        workAreaValue := Max(1, workArea.w * workArea.h)
        diagonal := Max(1, Sqrt(workArea.w * workArea.w + workArea.h * workArea.h))

        for window in windows {
            if (!targets.Has(window.id)) {
                valid := false
                continue
            }
            target := targets[window.id]
            if (target.w <= 0 || target.h <= 0 || !Geometry.IsWithin(target, workArea, 1)) {
                valid := false
            }
            if (window.isLocked && !Geometry.Equal(target, window.rect)) {
                valid := false
            }
            if (!window.canResize && (target.w != window.w || target.h != window.h)) {
                valid := false
            }

            idealWidth := window.isNew ? workArea.w * config.NewWidthRatio : window.w
            idealHeight := window.isNew ? workArea.h * config.NewHeightRatio : window.h
            sizeRaw += Abs(target.w - idealWidth) / workArea.w
            sizeRaw += Abs(target.h - idealHeight) / workArea.h

            if (!window.isNew && window.canMove) {
                dx := target.x - window.x
                dy := target.y - window.y
                displacement := Sqrt(dx * dx + dy * dy) / diagonal
                factor := mode = "auto" ? config.AutoMovementWeight : config.ManualMovementWeight
                if (window.recentlyUserChanged && mode = "auto") {
                    factor *= 2.5
                }
                movementRaw += displacement * factor
            } else if (window.isNew && window.canMove) {
                dx := target.x - window.x
                dy := target.y - window.y
                movementRaw += (Sqrt(dx * dx + dy * dy) / diagonal) * 0.15
            }
        }

        if (valid) {
            for firstIndex, first in windows {
                firstRect := targets[first.id]
                for secondIndex, second in windows {
                    if (secondIndex <= firstIndex) {
                        continue
                    }
                    secondRect := targets[second.id]
                    intersection := Geometry.IntersectionArea(firstRect, secondRect)
                    if (intersection <= 0) {
                        gap := this.RectangleGap(firstRect, secondRect)
                        spacingRaw += Min(1.0, gap / Max(1, config.MarginPx * 4)) * 0.15
                        if (Abs(firstRect.y - secondRect.y) <= config.MarginPx / 2) {
                            spacingRaw += Abs(firstRect.h - secondRect.h) / Max(1, workArea.h) * 0.05
                        }
                        continue
                    }
                    overlapRaw += intersection / workAreaValue
                    if (first.isForeground || first.isNew || second.isForeground || second.isNew) {
                        focusRaw += intersection / workAreaValue * Max(first.priority, second.priority)
                    }
                }
            }
        }

        minX := workArea.x + workArea.w
        minY := workArea.y + workArea.h
        maxX := workArea.x
        maxY := workArea.y
        for window in windows {
            if (!targets.Has(window.id)) {
                continue
            }
            target := targets[window.id]
            minX := Min(minX, target.x)
            minY := Min(minY, target.y)
            maxX := Max(maxX, target.x + target.w)
            maxY := Max(maxY, target.y + target.h)
        }
        layoutCenterX := (minX + maxX) / 2
        layoutCenterY := (minY + maxY) / 2
        workCenterX := workArea.x + workArea.w / 2
        workCenterY := workArea.y + workArea.h / 2
        dx := layoutCenterX - workCenterX
        dy := layoutCenterY - workCenterY
        centerRaw := Sqrt(dx * dx + dy * dy) / diagonal

        overlapCost := overlapRaw * config.OverlapWeight
        focusCost := focusRaw * config.FocusWeight
        sizeCost := sizeRaw * config.SizeWeight
        spacingCost := spacingRaw * config.SpacingWeight
        centerCost := centerRaw * config.CenterWeight
        total := movementRaw + overlapCost + focusCost + sizeCost + spacingCost + centerCost
        if (!valid) {
            total += 100000
        }

        return {
            Valid: valid,
            Total: total,
            OverlapCost: overlapCost,
            FocusCost: focusCost,
            SizeCost: sizeCost,
            MovementCost: movementRaw,
            SpacingCost: spacingCost,
            CenterCost: centerCost,
            OverlapRaw: overlapRaw,
            FocusRaw: focusRaw,
            MovementRaw: movementRaw
        }
    }

    static RectangleGap(first, second) {
        horizontal := Max(0, Max(first.x, second.x) - Min(first.x + first.w, second.x + second.w))
        vertical := Max(0, Max(first.y, second.y) - Min(first.y + first.h, second.y + second.h))
        return Sqrt(horizontal * horizontal + vertical * vertical)
    }

    static OriginalTargets(windows) {
        targets := Map()
        for window in windows {
            targets[window.id] := Geometry.Rect(window.x, window.y, window.w, window.h)
        }
        return targets
    }

    static CloneTargets(targets) {
        clone := Map()
        for id, rect in targets {
            clone[id] := Geometry.CopyRect(rect)
        }
        return clone
    }

    static ChangedIds(windows, targets) {
        result := []
        for window in windows {
            if (targets.Has(window.id) && !Geometry.Equal(targets[window.id], window.rect)) {
                result.Push(window.id)
            }
        }
        return result
    }

    static CountChangedExisting(windows, targets, newId) {
        count := 0
        for window in windows {
            if (window.id != newId && targets.Has(window.id)
                && !Geometry.Equal(targets[window.id], window.rect)) {
                count += 1
            }
        }
        return count
    }

    static FindWindowIndex(windows, id) {
        for index, window in windows {
            if (window.id = id) {
                return index
            }
        }
        return 0
    }

    static ModeFamily(mode) {
        return InStr(mode, "auto") = 1 ? "auto" : "manual"
    }

    static ImprovementRatio(before, after) {
        denominator := Max(Abs(before), 0.0001)
        return (before - after) / denominator
    }

    static DeadlineReached(deadline) {
        return deadline && A_TickCount >= deadline
    }

    static InvalidPlan(reason) {
        return {
            Valid: false,
            Targets: Map(),
            ChangedIds: [],
            Reason: reason,
            Strategy: "invalid",
            ScoreBefore: {Valid: false, Total: 999999},
            ScoreAfter: {Valid: false, Total: 999999},
            QualityImprovementRatio: 0.0
        }
    }
}
