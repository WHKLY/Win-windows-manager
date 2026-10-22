#Requires AutoHotkey v2.0
#SingleInstance Force

Loop 80 {
    batch := []
    batchNumber := A_Index
    Loop 12 {
        raceGui := Gui("+Resize", "WWM Destroy Race " batchNumber "-" A_Index)
        raceGui.AddText("w140 h40", "Destroy race test")
        raceGui.Show(Format(
            "NoActivate w180 h80 x{1} y{2}",
            50 + Mod(A_Index, 8) * 22,
            50 + Mod(A_Index, 6) * 18
        ))
        batch.Push(raceGui)
    }
    Sleep(55)
    for raceGui in batch {
        raceGui.Destroy()
    }
    Sleep(3)
}

ExitApp(0)
