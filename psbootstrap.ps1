[CmdletBinding()]
Param()

# Only tested with Powershell V4
#requires -version 4.0
Set-StrictMode -Version Latest  # Helps to catch errors

# Directories
# $MY_HOME is needed because user-data starts up as SYSTEM user which is *not* Administrator.
$MY_HOME = "C:\Users\Administrator"
$DOWNLOADS = "$MY_HOME\Downloads"
$SSH_DIR = "$MY_HOME\.ssh"
$TREES = "$MY_HOME\trees"
$MC_REPO = "$TREES\mozilla-central"
$AURORA_REPO = "$TREES\mozilla-aurora"

# Versions
$MOZILLABUILD_VERSION = "2.2.0"
$NOTEPADPP_MAJOR_VER = "6"
$NOTEPADPP_VERSION = "$NOTEPADPP_MAJOR_VER.9.2"
$FXDEV_ARCH = "64"
$FXDEV_VERSION = "51.0a2"
$LLVM_ARCH = "32"
$LLVM_VERSION = "3.9.0"

# Programs
$FXDEV_FILENAME = "firefox-$FXDEV_VERSION.en-US.win$FXDEV_ARCH.installer.exe"
$FXDEV_ARCHIVE = "https://archive.mozilla.org/pub/firefox/nightly/latest-mozilla-aurora/$FXDEV_FILENAME"
$FXDEV_FILE_WITH_DIR = "$DOWNLOADS\$FXDEV_FILENAME"
$GIT_ARCH = "32"
$GIT_VERSION = "2.10.0"
$GIT_FILENAME = "Git-$GIT_VERSION-$GIT_ARCH-bit.exe"
$GIT_FTP = "https://github.com/git-for-windows/git/releases/download/v$GIT_VERSION.windows.1/$GIT_FILENAME"
$GIT_FILE_WITH_DIR = "$DOWNLOADS\$GIT_FILENAME"
# Get list of names by running the following in PowerShell:
#   [Environment+SpecialFolder]::GetNames([Environment+SpecialFolder])
# From https://msdn.microsoft.com/en-us/library/system.environment.specialfolder.aspx
$GIT_BINARY = [Environment]::GetFolderPath("ProgramFilesX86") + "\Git\bin\git.exe"

# MozillaBuild
$MOZILLABUILD_INSTALLDIR = "C:\mozilla-build"
$MOZILLABUILD_GENERIC_START = "start-shell.bat"
$MOZILLABUILD_GENERIC_START_FULL_PATH = "$MOZILLABUILD_INSTALLDIR\fz-$MOZILLABUILD_GENERIC_START"
# For 32-bit, use "start-shell-msvc2015.bat". For 64-bit, use "start-shell-msvc2015-x64.bat"
# Remember to also tweak the LLVM arch.
$MOZILLABUILD_START_SCRIPT = "start-shell-msvc2015.bat"
#$MOZILLABUILD_START_SCRIPT = "start-shell-msvc2015-x64.bat"
$MOZILLABUILD_START_SCRIPT_FULL_PATH = "$MOZILLABUILD_INSTALLDIR\fz-$MOZILLABUILD_START_SCRIPT"
$PYTHON_BINARY = "$MOZILLABUILD_INSTALLDIR\python\python2.7.exe"
$HG_BINARY = "$MOZILLABUILD_INSTALLDIR\python\Scripts\hg"

Function DownloadBinary ($binName, $location) {
    # .DESCRIPTION
    # Downloads binaries.
    $wc = New-Object net.webclient  # Download prerequisites by not using Invoke-WebRequest (slow)
    if (-not (Test-Path $location)) {
        $wc.Downloadfile($binName, $location)
    }
}

Function InstallBinary ($binName) {
    # .DESCRIPTION
    # Installs NSIS programs using the /S switch.
    & $binName /S | out-null
}

Function ExtractArchive ($fileName, $dirName) {
    # .DESCRIPTION
    # Extracts archives using 7-Zip in mozilla-build directory.
    (C:\mozilla-build\7zip\7z.exe x -y -o"$dirName" $fileName) | out-null
}

Function ConvertToUnicodeNoBOM ($fileName) {
    # .DESCRIPTION
    # Converts files to Unicode without BOM.
    # Adapted from https://stackoverflow.com/a/5596984
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)
    [System.IO.File]::WriteAllLines($fileName,
                                    (Get-Content $fileName), $Utf8NoBomEncoding)
}

# Windows Registry settings
# Disable the Windows Error Dialog
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\Windows Error Reporting' -Name DontShowUI -Value 1 | out-null
# Turn on crash dumps
New-Item -Path 'HKLM:\Software\Microsoft\Windows\Windows Error Reporting' -Name LocalDumps | out-null
Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\Windows Error Reporting\LocalDumps' -Name DumpCount -Value 500 | out-null
Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\Windows Error Reporting\LocalDumps' -Name DumpType -Value 1 | out-null
# Get Group Policy Settings Reference from https://www.microsoft.com/en-us/download/details.aspx?id=25250
# Disable Application Compatibility Engine and Program Compatibility Assistant
New-Item -Path 'HKLM:\Software\Policies\Microsoft\Windows' -Name AppCompat | out-null
Set-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\AppCompat' -Name DisableEngine -Value 1 | out-null
Set-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\AppCompat' -Name DisablePCA -Value 1 | out-null
& gpupdate /force | out-null

# Create a shortcut to ~ in Favorites. Adapted from https://stackoverflow.com/a/9701907
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$MY_HOME\Links\Administrator.lnk")
$Shortcut.TargetPath = "$MY_HOME"
$Shortcut.Save()

# Microsoft Visual Studio 2015 Community Edition with Updates
$VS2015COMMUNITY_FTP = "https://go.microsoft.com/fwlink/?LinkID=626924"
$VS2015COMMUNITY_SETUP = "$DOWNLOADS\vs_community_ENU.exe"
$VS2015COMMUNITY_SETUP_DEPLOYMENT = "$DOWNLOADS\AdminDeployment.xml"
DownloadBinary $VS2015COMMUNITY_FTP $VS2015COMMUNITY_SETUP
DownloadBinary https://gist.githubusercontent.com/nth10sd/970e782985f5a48fc240d2742c3aaa26/raw/4ed73523208384f19b6ace0eba3d01f67145ea50/msvc2015AdminDeployment-win2012R2.xml $VS2015COMMUNITY_SETUP_DEPLOYMENT
& $VS2015COMMUNITY_SETUP /Passive /NoRestart /AdminFile $VS2015COMMUNITY_SETUP_DEPLOYMENT | Write-Output

# Standalone Debugging Tools for Windows as part of Windows 8.1 SDK
$DEBUGGINGTOOLS_FTP = "https://download.microsoft.com/download/A/6/A/A6AC035D-DA3F-4F0C-ADA4-37C8E5D34E3D/setup/WinSDKDebuggingTools_amd64/dbg_amd64.msi"
$DEBUGGINGTOOLS_SETUP = "$DOWNLOADS\Debugging_Tools_for_Windows_(x64).msi"
DownloadBinary $DEBUGGINGTOOLS_FTP $DEBUGGINGTOOLS_SETUP
Start-Process "msiexec" "/i $DEBUGGINGTOOLS_SETUP /Passive /NoRestart" -NoNewWindow -Wait

# MozillaBuild
$MOZILLABUILD_FTP = "https://ftp.mozilla.org/pub/mozilla/libraries/win32/MozillaBuildSetup-$MOZILLABUILD_VERSION.exe"
$MOZILLABUILD_SETUP = "$DOWNLOADS\MozillaBuildSetup-$MOZILLABUILD_VERSION.exe"
DownloadBinary $MOZILLABUILD_FTP $MOZILLABUILD_SETUP
InstallBinary $MOZILLABUILD_SETUP

# LLVM (MSVC should be installed first)
$LLVM_FTP = "http://llvm.org/releases/$LLVM_VERSION/LLVM-$LLVM_VERSION-win$LLVM_ARCH.exe"
$LLVM_FILE = "$DOWNLOADS\LLVM-$LLVM_VERSION-win$LLVM_ARCH.exe"
DownloadBinary $LLVM_FTP $LLVM_FILE
InstallBinary $LLVM_FILE

# Notepad++ editor
$NOTEPADPP_FTP = "https://notepad-plus-plus.org/repository/$NOTEPADPP_MAJOR_VER.x/$NOTEPADPP_VERSION/npp.$NOTEPADPP_VERSION.Installer.exe"
$NOTEPADPP_FILE = "$DOWNLOADS\npp.$NOTEPADPP_VERSION.Installer.exe"
DownloadBinary $NOTEPADPP_FTP $NOTEPADPP_FILE
InstallBinary $NOTEPADPP_FILE

# Firefox Developer Edition (Aurora)
DownloadBinary $FXDEV_ARCHIVE $FXDEV_FILE_WITH_DIR
& $FXDEV_FILE_WITH_DIR -ms | out-null

# Git
DownloadBinary $GIT_FTP $GIT_FILE_WITH_DIR
& $GIT_FILE_WITH_DIR /SILENT | out-null

& $GIT_BINARY clone "https://github.com/MozillaSecurity/lithium.git" "$MY_HOME\lithium" | out-null
& $GIT_BINARY clone "https://github.com/MozillaSecurity/funfuzz" "$MY_HOME\funfuzz" | out-null
& $GIT_BINARY clone "https://github.com/MozillaSecurity/FuzzManager" "$MY_HOME\FuzzManager" | out-null

New-Item $SSH_DIR -type directory | out-null
New-Item "$SSH_DIR\config" -type file -value 'Host *
StrictHostKeyChecking no
' | out-null
# Create a shortcut to C:\mozilla-build in Favorites. Adapted from https://stackoverflow.com/a/9701907
$WshShell2 = New-Object -comObject WScript.Shell
$Shortcut2 = $WshShell2.CreateShortcut("$MY_HOME\Links\mozilla-build.lnk")
$Shortcut2.TargetPath = "C:\mozilla-build"
$Shortcut2.Save()
# Modifying custom mozilla-build script for running fuzzing.
# Step 1: -encoding utf8 is needed for out-file for the batch file to be run properly.
# See https://technet.microsoft.com/en-us/library/hh849882.aspx
cat "$MOZILLABUILD_INSTALLDIR\$MOZILLABUILD_START_SCRIPT" |
    % { $_ -replace "CALL $MOZILLABUILD_GENERIC_START", "CALL fz-$MOZILLABUILD_GENERIC_START" } |
    out-file $MOZILLABUILD_START_SCRIPT_FULL_PATH -encoding utf8 |
    out-null
cat "$MOZILLABUILD_INSTALLDIR\$MOZILLABUILD_GENERIC_START" |
    % { $_ -replace ' --login -i', ' --login -c "pip install --upgrade boto numpy requests ; python -u ~/funfuzz/loopBot.py -b \"--random\" -t \"js\" --target-time 28800 | tee ~/log-loopBotPy.txt"' } |
    out-file $MOZILLABUILD_GENERIC_START_FULL_PATH -encoding utf8 |
    out-null
# Step 2: Now convert the file generated in step 1 from Unicode with BOM to Unicode without BOM:
ConvertToUnicodeNoBOM $MOZILLABUILD_START_SCRIPT_FULL_PATH
ConvertToUnicodeNoBOM $MOZILLABUILD_GENERIC_START_FULL_PATH

New-Item $TREES -type directory | out-null
& $PYTHON_BINARY -u $HG_BINARY --cwd $TREES clone https://hg.mozilla.org/mozilla-central $MC_REPO | out-null
& $PYTHON_BINARY -u $HG_BINARY --cwd $TREES clone https://hg.mozilla.org/releases/mozilla-aurora/ $AURORA_REPO | out-null
