
function Set-Version
{
    Param ([string]$filePath, [string]$version)
    $tempFilePath = $filePath + ".tmp"
    Get-Content $filePath |
        %{[regex]::replace($_, 'AssemblyVersion\("[0-9]+(\.([0-9]+)){1,3}"\)', "AssemblyVersion(""${version}"")")} |
        %{[regex]::replace($_, 'AssemblyFileVersion\("[0-9]+(\.([0-9]+)){1,3}"\)', "AssemblyFileVersion(""${version}"")")} > $tempFilePath
    Move-Item $tempFilePath $filePath -Force
}

function Get-Version
{
    Param([string]$filePath)
    return Get-Content $filePath | 
        %{[regex]::matches($_, 'AssemblyVersion\("(?<version>[0-9]+(\.([0-9]+)){1,3})"\)')} | %{$_.Groups['version'].value}
}

function Set-Installer-Version
{
    Param([string]$filePath, [string]$version)
    $tempFilePath = $filePath + ".tmp"
    Get-Content -Encoding UTF8 $filePath |
        %{[regex]::replace($_, 'AppVersion\=[0-9.]+', "AppVersion=${version}")} |
        %{[regex]::replace($_, 'VersionInfoVersion\=[0-9.]+', "VersionInfoVersion=${version}")} |
        Out-File -Encoding UTF8 $tempFilePath
    Move-Item $tempFilePath $filePath -Force
}

Write-Output 'Updating Version ...'
$currentVersion = Get-Version 'Skype Historian\Properties\AssemblyInfo.cs'
Write-Output "Current Version ${currentVersion}"
$currentVersionObject = New-Object Version $currentVersion
$nextVersionObject = New-Object Version($currentVersionObject.Major, $currentVersionObject.Minor, ($currentVersionObject.Build + 1), $currentVersionObject.Revision)
$nextVersion = $nextVersionObject.ToString()
Write-Output "Updating to ${nextVersion}"
Set-Version 'Skype Historian\Properties\AssemblyInfo.cs' $nextVersion
Set-Installer-Version 'Skype Historian.iss' $nextVersion
New-Item '.\Installers' -type directory -force
echo $nextVersion | Out-File -Encoding ASCII '.\Installers\latest-version.txt'
Write-Output 'Building Skype Historian ...'
C:\Windows\Microsoft.NET\Framework\v3.5\MSBuild 'Skype Historian.sln' /t:Rebuild /p:Configuration=Release /p:PlatformToolset=v90
if ($LastExitCode -ne 0)
{
    Write-Error 'Build Failed.'
}
else
{
    Write-Output 'Building Installer ...'
    rm '.\Installers\*.exe'
    & "${Env:ProgramFiles}\Inno Setup 5\iscc" 'Skype Historian.iss'
    if ($LastExitCode -eq 0)
    {
        Write-Output 'Finishing ...'
        $targetFileName = ".\Installers\Skype_Historian_${nextVersion}_Setup.exe"
        Move-Item '.\Installers\Setup.exe' $targetFileName -Force
        Write-Output "Installer: ${targetFileName}"
    }
    else
    {
        Write-Error 'Installer Build Failed'
    }
}
