#Requires AutoHotkey v2.0
#SingleInstance Force

outputPath := A_Args.Length ? A_Args[1] : ""
testGui := Gui("+Resize", "WWM Registry Integration Host")
testGui.AddText("w280 h80", "Temporary external window for integration tests")
testGui.Show("w420 h300 x220 y180")

if (outputPath != "") {
    FileAppend(testGui.Hwnd, outputPath, "UTF-8")
}

SetTimer((*) => ExitApp(0), -10000)
