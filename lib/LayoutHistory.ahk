class LayoutHistory {
    __New(maximumDepth := 1) {
        this.MaximumDepth := Max(1, maximumDepth)
        this.Entries := []
    }

    Save(before, mode, reason := "") {
        entries := []
        for item in before {
            entries.Push({
                hwnd: item.hwnd,
                pid: item.pid,
                id: item.id,
                rect: Geometry.CopyRect(item.rect),
                monitor: item.monitor,
                workArea: Geometry.CopyRect(item.workArea)
            })
        }
        if (entries.Length = 0) {
            return false
        }
        this.Entries.InsertAt(1, {
            createdAt: A_TickCount,
            mode: mode,
            reason: reason,
            entries: entries
        })
        while (this.Entries.Length > this.MaximumDepth) {
            this.Entries.Pop()
        }
        return true
    }

    GetLatest() {
        return this.Entries.Length ? this.Entries[1] : 0
    }

    Clear() {
        this.Entries := []
    }
}
