class Geometry {
    static Rect(x, y, w, h) {
        return {
            x: Round(x),
            y: Round(y),
            w: Max(0, Round(w)),
            h: Max(0, Round(h))
        }
    }

    static CopyRect(rect) {
        return Geometry.Rect(rect.x, rect.y, rect.w, rect.h)
    }

    static Area(rect) {
        return rect.w * rect.h
    }

    static Center(rect) {
        return {
            x: rect.x + rect.w / 2,
            y: rect.y + rect.h / 2
        }
    }

    static Clamp(value, minimum, maximum) {
        if (maximum < minimum) {
            return minimum
        }
        return Max(minimum, Min(maximum, value))
    }

    static ClampRect(rect, workArea, margin := 0) {
        availableWidth := Max(1, workArea.w - margin * 2)
        availableHeight := Max(1, workArea.h - margin * 2)
        width := Min(rect.w, availableWidth)
        height := Min(rect.h, availableHeight)
        maximumX := workArea.x + workArea.w - margin - width
        maximumY := workArea.y + workArea.h - margin - height
        x := Geometry.Clamp(rect.x, workArea.x + margin, maximumX)
        y := Geometry.Clamp(rect.y, workArea.y + margin, maximumY)
        return Geometry.Rect(x, y, width, height)
    }

    static IsWithin(rect, area, tolerance := 0) {
        return rect.x >= area.x - tolerance
            && rect.y >= area.y - tolerance
            && rect.x + rect.w <= area.x + area.w + tolerance
            && rect.y + rect.h <= area.y + area.h + tolerance
    }

    static IntersectionArea(first, second) {
        left := Max(first.x, second.x)
        top := Max(first.y, second.y)
        right := Min(first.x + first.w, second.x + second.w)
        bottom := Min(first.y + first.h, second.y + second.h)
        if (right <= left || bottom <= top) {
            return 0
        }
        return (right - left) * (bottom - top)
    }

    static Equal(first, second, tolerance := 0) {
        return Abs(first.x - second.x) <= tolerance
            && Abs(first.y - second.y) <= tolerance
            && Abs(first.w - second.w) <= tolerance
            && Abs(first.h - second.h) <= tolerance
    }

    static Distance(first, second) {
        dx := first.x - second.x
        dy := first.y - second.y
        return Sqrt(dx * dx + dy * dy)
    }

    static SmoothStep(value) {
        t := Geometry.Clamp(value, 0.0, 1.0)
        return t * t * (3.0 - 2.0 * t)
    }

    static InterpolateRect(from, target, progress) {
        eased := Geometry.SmoothStep(progress)
        return Geometry.Rect(
            from.x + (target.x - from.x) * eased,
            from.y + (target.y - from.y) * eased,
            from.w + (target.w - from.w) * eased,
            from.h + (target.h - from.h) * eased
        )
    }
}
