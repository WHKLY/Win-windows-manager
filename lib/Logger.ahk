class Logger {
    __New(logDirectory, debugEnabled := false) {
        this.Directory := logDirectory
        this.DebugEnabled := debugEnabled
        this.Path := RTrim(logDirectory, "\/") "\windowswindowsmanager.log"
        try {
            DirCreate(logDirectory)
        }
    }

    Info(event, fields := 0) {
        this.Write("INFO", event, fields)
    }

    Warn(event, fields := 0) {
        this.Write("WARN", event, fields)
    }

    Error(event, fields := 0) {
        this.Write("ERROR", event, fields)
    }

    Debug(event, fields := 0) {
        if (this.DebugEnabled) {
            this.Write("DEBUG", event, fields)
        }
    }

    Write(level, event, fields) {
        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        suffix := this.FormatFields(fields)
        line := timestamp " [" level "] " event
        if (suffix != "") {
            line .= " " suffix
        }
        line .= "`r`n"
        try {
            FileAppend(line, this.Path, "UTF-8")
        }
        try {
            OutputDebug("WWM " RTrim(line, "`r`n"))
        }
    }

    FormatFields(fields) {
        if (Type(fields) != "Map") {
            return ""
        }
        result := ""
        for key, value in fields {
            if (result != "") {
                result .= " "
            }
            result .= key "=" this.CleanValue(value)
        }
        return result
    }

    CleanValue(value) {
        try {
            text := String(value)
        } catch {
            text := "<unprintable>"
        }
        text := StrReplace(text, "`r", " ")
        text := StrReplace(text, "`n", " ")
        if (StrLen(text) > 180) {
            text := SubStr(text, 1, 180) "..."
        }
        return text
    }
}
