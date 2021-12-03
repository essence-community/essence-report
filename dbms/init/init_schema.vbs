Const ForReading = 1    
Const ForWriting = 2

set WshShell = WScript.CreateObject("WScript.Shell")

Dim currDir, sUser, sPw, connectionPreBd, connectionBd, sMetaUser, sMetaPw, connectionMetaBd, newDataBase, newSchema, commadLiquibase
Set fso = CreateObject("Scripting.FileSystemObject")
currDir = fso.GetParentFolderName(Wscript.ScriptFullName)

WshShell.CurrentDirectory = currDir

If fso.FileExists(currDir & "\liquibase.init.properties") Then
    commadLiquibase = "cd "& currDir & "\.. && gradlew.bat update -PrunList=init"

    set WshExec = WshShell.Exec(commadLiquibase)
    Set TextStream = WshExec.StdOut
    While Not TextStream.AtEndOfStream
        WScript.StdOut.Write TextStream.ReadLine() & vbCrLf
    Wend
    WScript.Quit 0
End If

WScript.StdOut.Write "Connection(jdbc:postgresql://127.0.0.1:5432/postgres): "
connectionPreBd = WScript.StdIn.ReadLine

If Len(connectionPreBd) = 0 Then
    connectionPreBd = "jdbc:postgresql://127.0.0.1:5432/postgres"
End if

WScript.StdOut.Write "Superadmin User (postgres): "
sUser = WScript.StdIn.ReadLine

If Len(sUser) = 0 Then
    sUser = "postgres"
End if

WScript.StdOut.Write "Superadmin Password (postgres): "
sPw = WScript.StdIn.ReadLine

If Len(sPw) = 0 Then
    sPw = "postgres"
End if

WScript.StdOut.Write "Connection Meta(jdbc:postgresql://127.0.0.1:5432/core): "
connectionMetaBd = WScript.StdIn.ReadLine

If Len(connectionMetaBd) = 0 Then
    connectionMetaBd = "jdbc:postgresql://127.0.0.1:5432/core"
End if

WScript.StdOut.Write "Superadmin Meta User (s_su): "
sMetaUser = WScript.StdIn.ReadLine

If Len(sMetaUser) = 0 Then
    sMetaUser = "s_su"
End if

WScript.StdOut.Write "Superadmin Meta Password (s_su): "
sMetaPw = WScript.StdIn.ReadLine

If Len(sMetaPw) = 0 Then
    sMetaPw = "s_su"
End if

WScript.StdOut.Write "Name DataBase: "
newDataBase = WScript.StdIn.ReadLine

If Len(newDataBase) = 0 Then
    WScript.StdOut.Write "Error empty DataBase"
    WScript.Quit 1
End if

connectionBd = Left(connectionPreBd, InStrRev(connectionPreBd, "/")) & newDataBase

WScript.StdOut.Write "Prefix Schema: "
newSchema = WScript.StdIn.ReadLine

If Len(newSchema) = 0 Then
    WScript.StdOut.Write "Error empty prefix Schema"
    WScript.Quit 1
End if

Function ReplaceSchema(strFileName)
    Set objFSO = CreateObject("Scripting.FileSystemObject")
    Set objFile = objFSO.OpenTextFile(strFileName, ForReading)
    strText = objFile.ReadAll
    objFile.Close

    strNewText = Replace(strText, "#user.update#", newSchema & "p")
    strNewText = Replace(strNewText, "#user.table#", newSchema & "t")
    strNewText = Replace(strNewText, "#user.connect#", newSchema & "c")
    strNewText = Replace(strNewText, "#name.db#", newDataBase)
    strNewText = Replace(strNewText, "#user.admin#", sUser)
    strNewText = Replace(strNewText, "#schemaConnection#", connectionBd)
    strNewText = Replace(strNewText, "#schemaConnectionAdmin#", sUser)
    strNewText = Replace(strNewText, "#schemaConnectionAdminPw#", sPw)
    strNewText = Replace(strNewText, "#metaConnection#", connectionMetaBd)
    strNewText = Replace(strNewText, "#metaConnectionAdmin#", sMetaUser)
    strNewText = Replace(strNewText, "#metaConnectionAdminPw#", sMetaPw)
    Set objFile = objFSO.OpenTextFile(strFileName, ForWriting)
    objFile.Write strNewText
    objFile.Close
End Function

ReplaceSchema(currDir & "\db.sql")
ReplaceSchema(currDir & "\db.changelog.init.xml")

commadLiquibase = "cd " & currDir & "\.. && gradlew.bat update -PrunList=init -Pliquibase.username=#schemaConnectionAdmin# -Pliquibase.password=#schemaConnectionAdminPw# -Pliquibase.url=#schemaConnection# -Pliquibase.driver=org.postgresql.Driver"
commadLiquibase = Replace(commadLiquibase, "#schemaConnection#", connectionPreBd)
commadLiquibase = Replace(commadLiquibase, "#schemaConnectionAdmin#", sUser)
commadLiquibase = Replace(commadLiquibase, "#schemaConnectionAdminPw#", sPw)
set WshExec = WshShell.Exec(commadLiquibase)
Set TextStream = WshExec.StdOut
While Not TextStream.AtEndOfStream
    WScript.StdOut.Write TextStream.ReadLine() & vbCrLf
Wend


ReplaceSchema(currDir & "\..\db.changelog.meta.xml")
ReplaceSchema(currDir & "\..\db.changelog.schema.xml")
ReplaceSchema(currDir & "\..\liquibase.meta.properties")
ReplaceSchema(currDir & "\..\liquibase.schema.properties")

Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objFile = objFSO.CreateTextFile( currDir & "\liquibase.init.properties", True)
objFile.WriteLine "driver: org.postgresql.Driver"
objFile.WriteLine "url: " & connectionPreBd
objFile.WriteLine "username: " & sUser
objFile.WriteLine "password: " & sPw
objFile.Close