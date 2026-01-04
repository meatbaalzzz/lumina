Set objShell = CreateObject("WScript.Shell")
' Ejecuta el script cycles.ps1 de forma invisible
objShell.Run "powershell.exe -ExecutionPolicy Bypass -File """ & _
             CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName) & _
             "\cycles.ps1""", 0
