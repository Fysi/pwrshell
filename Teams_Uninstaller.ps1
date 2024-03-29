<#
.SYNOPSIS
Removes Teams including the Machine Installer that reinstalls each user login.
#>

$UsersRoot = [System.IO.Path]::Combine(($env:Public).trimend("\Public")) 
$AllUsersPath = Get-ChildItem $UsersRoot
$Users = $AllUsersPath.FullName
# Stop the process if it's running
Stop-Process -Name "Teams.exe" -Force -ErrorAction SilentlyContinue

# Get the registry from 32 and 64bit uninstaller records
# Find if anything matches the name Teams Machine Wide Installer  
$uninstall32 = gci "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" | foreach { gp $_.PSPath } | ? { $_ -like "*Teams Machine-Wide Installer*" } | select UninstallString
$uninstall64 = gci "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | foreach { gp $_.PSPath } | ? { $_ -like "*Teams Machine-Wide Installer*" } | select UninstallString

# Run msiexec uninstall silently if either registry path has an uninstall string present
if ($uninstall64) {
    $uninstall64 = $uninstall64.UninstallString -Replace "msiexec.exe","" -Replace "/I","" -Replace "/X",""
    $uninstall64 = $uninstall64.Trim()
    Write-Output "Found Teams Machine Wide Installer (64bit) - uninstalling..."
    Start-Process "msiexec.exe" -arg "/X $uninstall64 /qb" -Wait
}
if ($uninstall32) {
    $uninstall32 = $uninstall32.UninstallString -Replace "msiexec.exe","" -Replace "/I","" -Replace "/X",""
    $uninstall32 = $uninstall32.Trim()
    Write-Output "Found Teams Machine Wide Installer (32bit) - uninstalling..."
    Start-Process "msiexec.exe" -arg "/X $uninstall32 /qb" -Wait
}

# Run the uninstall and files removal from AppData on all users
ForEach($User in $Users){
    $TeamsPath = Convert-Path "$user\AppData\Local\Microsoft\Teams" -ErrorAction SilentlyContinue
    $TeamsUpdateExePath = "$TeamsPath\Update.exe"
    try{
        if (Test-Path -Path $TeamsUpdateExePath) {
            Write-Output "Uninstalling Teams process"
            # Uninstall app
            $proc = Start-Process -FilePath $TeamsUpdateExePath -ArgumentList "-uninstall -s" -PassThru
            $proc.WaitForExit()
            Write-Output "Success! Teams process uninstalled for $user.Name"
        }
        else {
            Write-Output "Not Found. Teams update exe in AppData is not present for $User"
        }
        if (Test-Path -Path $TeamsPath) {
            Write-Output "Deleting Teams directory"
            Remove-Item -Path $TeamsPath -Recurse -Force
            Write-Ouput "Success! Teams directory deleted for $user"
        }
        else {
            Write-Output "Not Found. Teams install was not found for $User at path $TeamsPath"
        }
    }
    catch{
        Write-Error -ErrorRecord $_
    }
}
try{
    if (Test-Path -Path $TeamsMachineInstallerPath) {
        Write-Output "Deleting Teams Machine Installer"
        Remove-Item -Path $TeamsMachineInstallerPath -Recurse -Force
        Write-Output "Success! Teams Machine Installer deleted on $Env:COMPUTERNAME"
    }
    else {
        "Not Found. Not Teams Machine Installer found on $Env:COMPUTERNAME"
    }
}
catch{
    Write-Error -ErrorRecord $_
    exit /b 1
}
