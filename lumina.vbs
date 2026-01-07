Dim fso, sh, baseDir, cacheDir, psExe, cmd, rc, logPath
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
cacheDir = baseDir & "\cache"
logPath = cacheDir & "\lumina-vbs.log"
If Not fso.FolderExists(cacheDir) Then
  fso.CreateFolder(cacheDir)
End If
psExe = sh.ExpandEnvironmentStrings("%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")
cmd = """" & psExe & """" & " -NoProfile -ExecutionPolicy Bypass -File " & """" & baseDir & "\cycles.ps1" & """"
rc = sh.Run(cmd, 0, True)
If rc <> 0 Then
  Dim log
  Set log = fso.OpenTextFile(logPath, 8, True)
  log.WriteLine Now & " VBS failed, exit code=" & rc & " cmd=" & cmd
  log.Close
End If
