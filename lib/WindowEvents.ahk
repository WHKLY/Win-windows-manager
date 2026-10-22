class WindowEvents {
    static EVENT_SYSTEM_FOREGROUND := 0x0003
    static EVENT_SYSTEM_MOVESIZESTART := 0x000A
    static EVENT_SYSTEM_MOVESIZEEND := 0x000B
    static EVENT_OBJECT_CREATE := 0x8000
    static EVENT_OBJECT_DESTROY := 0x8001
    static EVENT_OBJECT_SHOW := 0x8002
    static WINEVENT_OUTOFCONTEXT := 0x0000

    __New(app) {
        this.App := app
        this.Hooks := []
        this.Callback := 0
    }

    Start() {
        if (this.Callback) {
            return
        }
        this.Callback := CallbackCreate(ObjBindMethod(this, "OnEvent"), "Fast", 7)
        if (!this.Callback) {
            throw Error("CallbackCreate failed for SetWinEventHook")
        }

        events := [
            WindowEvents.EVENT_SYSTEM_FOREGROUND,
            WindowEvents.EVENT_SYSTEM_MOVESIZESTART,
            WindowEvents.EVENT_SYSTEM_MOVESIZEEND,
            WindowEvents.EVENT_OBJECT_CREATE,
            WindowEvents.EVENT_OBJECT_DESTROY,
            WindowEvents.EVENT_OBJECT_SHOW
        ]
        for eventNumber in events {
            hook := DllCall(
                "SetWinEventHook",
                "UInt", eventNumber,
                "UInt", eventNumber,
                "Ptr", 0,
                "Ptr", this.Callback,
                "UInt", 0,
                "UInt", 0,
                "UInt", WindowEvents.WINEVENT_OUTOFCONTEXT,
                "Ptr"
            )
            if (!hook) {
                this.Stop()
                throw Error("SetWinEventHook failed for event " eventNumber)
            }
            this.Hooks.Push(hook)
        }
    }

    Stop() {
        for hook in this.Hooks {
            try {
                DllCall("UnhookWinEvent", "Ptr", hook)
            }
        }
        this.Hooks := []
        if (this.Callback) {
            try {
                CallbackFree(this.Callback)
            }
            this.Callback := 0
        }
    }

    OnEvent(hook, eventNumber, hwnd, idObject, idChild, eventThread, eventTime) {
        try {
            if (idObject = 0 && idChild = 0 && hwnd) {
                this.App.OnWindowEvent(eventNumber, hwnd)
            }
        } catch Error as err {
            try {
                this.App.Logger.Error("event_callback_error", Map(
                    "event", eventNumber,
                    "hwnd", hwnd,
                    "error", err.Message
                ))
            }
        }
    }
}
