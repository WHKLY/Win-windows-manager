#Requires AutoHotkey v2.0
#SingleInstance Force

Loop 10 {
    batch := []
    batchNumber := A_Index
    Loop 20 {
        churnGui := Gui("+Resize", "WWM Churn " batchNumber "-" A_Index)
        churnGui.AddText("w180 h50", "Burst create/destroy test")
        churnGui.Show(Format(
            "NoActivate w220 h100 x{1} y{2}",
            40 + Mod(A_Index, 12) * 28,
            40 + Mod(A_Index, 8) * 22
        ))
        batch.Push(churnGui)
    }
    Sleep(8)
    for churnGui in batch {
        churnGui.Destroy()
    }
    Sleep(8)
}

ExitApp(0)
