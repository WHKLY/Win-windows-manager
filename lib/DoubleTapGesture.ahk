class DoubleTapGesture {
    __New(maxIntervalMs) {
        this.MaxIntervalMs := maxIntervalMs
        this.LastTapAt := -1
    }

    Press(timestamp) {
        if (this.LastTapAt < 0) {
            this.LastTapAt := timestamp
            return false
        }

        elapsed := timestamp - this.LastTapAt
        this.LastTapAt := timestamp
        if (elapsed >= 0 && elapsed <= this.MaxIntervalMs) {
            this.LastTapAt := -1
            return true
        }
        return false
    }

    SetMaxInterval(maxIntervalMs) {
        this.MaxIntervalMs := maxIntervalMs
        this.Reset()
    }

    Reset() {
        this.LastTapAt := -1
    }
}
