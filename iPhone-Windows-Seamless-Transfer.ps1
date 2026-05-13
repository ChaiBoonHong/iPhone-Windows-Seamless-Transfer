<#PSScriptInfo
.VERSION 1.0.0
.GUID 8b1f4f67-5f67-4a3f-9f39-5a0d6d3d3e2a
.AUTHOR ChaiBoonHong
.COMPANYNAME ChaiBoonHong
.COPYRIGHT 2026 ChaiBoonHong
.TAGS smb file-sharing iphone windows transfer local
.LICENSEURI https://raw.githubusercontent.com/ChaiBoonHong/iPhone-Windows-Seamless-Transfer/master/LICENSE
.PROJECTURI https://github.com/ChaiBoonHong/iPhone-Windows-Seamless-Transfer
.RELEASENOTES Initial publishable PowerShell script version of the batch workflow.
#>

<#
.SYNOPSIS
Sets up a local SMB share for iPhone-to-Windows file transfer.

.DESCRIPTION
Creates or updates a local Windows user, prepares a folder, assigns permissions,
creates an SMB share, opens the required firewall rules, and writes connection
instructions to a text file inside the shared folder.
#>

[CmdletBinding()]
param()

function Assert-Administrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($currentIdentity)

    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host 'Requesting administrative privileges...'
        $arguments = @(
            '-NoProfile'
            '-ExecutionPolicy'
            'Bypass'
            '-File'
            ('"{0}"' -f $PSCommandPath)
        )

        Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -Verb RunAs
        exit
    }
}

function ConvertTo-PlainText {
    param(
        [Parameter(Mandatory)]
        [Security.SecureString]$SecureString
    )

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}

function Get-LocalIPv4Addresses {
    $addresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -and
            $_.IPAddress -notlike '127.*' -and
            $_.IPAddress -notlike '169.254.*'
        } |
        Select-Object -ExpandProperty IPAddress -Unique

    if ($addresses) {
        return $addresses
    }

    return @(
        (ipconfig | Select-String 'IPv4' | ForEach-Object { $_.Line.Trim() })
    )
}

function Write-ShareDetailsFile {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '',
        Justification='Password input is collected as SecureString and only converted for the generated local instructions file.')]
    param(
        [Parameter(Mandatory)]
        [string]$FolderPath,

        [Parameter(Mandatory)]
        [string]$ShareUser
    )

    $exportFile = Join-Path $FolderPath 'iPhone_Share_Details.txt'
    $lines = @(
        '===============================================================================',
        '                          SETUP COMPLETE!',
        '===============================================================================',
        '',
        'YOUR AVAILABLE IP ADDRESSES:',
        '-------------------------------------------------------------------------------'
    )

    $lines += Get-LocalIPv4Addresses
    $lines += @(
        '-------------------------------------------------------------------------------',
        '',
        'IMPORTANT IP SELECTION GUIDE:',
        '* Ignore addresses starting with "169.254." (Disconnected adapters)',
        '* Ignore addresses like "192.168.56.x" if you use VirtualBox',
        '* Look for your main Wi-Fi/Ethernet IP (e.g., 192.168.1.x, 192.168.2.x)',
        '',
        '===============================================================================',
        '                    HOW TO CONNECT ON YOUR IPHONE',
        '===============================================================================',
        '1. Open the "Files" app on your iPhone.',
        '2. Tap the three dots (...) in the top right corner.',
        '3. Tap "Connect to Server".',
        '4. Type the following using your correct IP address from above:',
        '',
        '      smb://[YOUR_CORRECT_IP_ADDRESS]',
        '',
        '5. Tap "Connect".',
        '6. Choose "Registered User" and enter the username shown above and the password you created during setup.',
        '',
        ('      Username:  {0}' -f $ShareUser),
        '',
        '7. Tap "Next". You will now see your shared folder!',
        '===============================================================================' 
    )

    $lines | Set-Content -Path $exportFile -Encoding utf8
    return $exportFile
}

Assert-Administrator

Clear-Host
Write-Host '==============================================================================='
Write-Host '                      SHARE CONFIGURATION'
Write-Host '==============================================================================='
Write-Host 'Please define your connection details below.'
Write-Host ''

$shareUser = Read-Host "Enter Username (Press ENTER for default 'AppleUser')"
if ([string]::IsNullOrWhiteSpace($shareUser)) {
    $shareUser = 'AppleUser'
}

$sharePasswordSecure = $null
while (-not $sharePasswordSecure) {
    $sharePasswordSecure = Read-Host 'Enter a NEW Password for this user' -AsSecureString
    $plainPassword = ConvertTo-PlainText -SecureString $sharePasswordSecure
    if ([string]::IsNullOrWhiteSpace($plainPassword)) {
        Write-Host '[ERROR] Password cannot be empty.'
        $sharePasswordSecure = $null
    }
}

$sharePassword = ConvertTo-PlainText -SecureString $sharePasswordSecure

$folderPath = Read-Host "Enter folder path (Press ENTER for default 'C:\shared_folder')"
if ([string]::IsNullOrWhiteSpace($folderPath)) {
    $folderPath = 'C:\shared_folder'
}

Write-Host ''
Write-Host '==============================================================================='
Write-Host ('Setting up share with User: {0} at Path: {1}' -f $shareUser, $folderPath)
Write-Host '==============================================================================='
Write-Host ''

try {
    Write-Host '--- Step 1: Forcing Network Profile to Private ---'
    Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private | Out-Null

    Write-Host ('--- Step 2: Creating or updating Local Share User [{0}] ---' -f $shareUser)
    & net user "$shareUser" "$sharePassword" /add /passwordchg:no | Out-Null
    if ($LASTEXITCODE -ne 0) {
        & net user "$shareUser" "$sharePassword" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create or update the user account.'
        }
    }

    Write-Host '--- Step 3: Preparing Folder and Permissions ---'
    if (-not (Test-Path -LiteralPath $folderPath)) {
        New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $folderPath)) {
        throw 'Could not create the target folder.'
    }

    & icacls "$folderPath" /grant "$shareUser":(OI)(CI)F /T | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to grant folder permissions.'
    }

    Write-Host '--- Step 4: Enabling Sharing and Opening Firewalls ---'
    & net share "$shareUser`_Share" /delete /y | Out-Null
    & net share "$shareUser`_Share"="$folderPath" /grant:"$shareUser",full | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to create the SMB share.'
    }

    & netsh advfirewall firewall set rule group='File and Printer Sharing' new enable=Yes | Out-Null
    & netsh advfirewall firewall add rule name='Force iOS SMB In (TCP 445)' dir=in action=allow protocol=TCP localport=445 | Out-Null

    Write-Host '--- Step 5: Restarting Windows File Sharing Service ---'
    & net stop LanmanServer /y | Out-Null
    & net start LanmanServer | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'Windows File Sharing service could not be restarted automatically.'
    }

    $exportFile = Write-ShareDetailsFile -FolderPath $folderPath -ShareUser $shareUser

    Clear-Host
    Get-Content -Path $exportFile
    Write-Host ''
    Write-Host 'SUCCESS: The details above have been saved directly inside your shared folder:'
    Write-Host ('"{0}"' -f $exportFile)
    Write-Host ''
    Read-Host 'Press Enter to exit'
}
catch {
    Write-Host ''
    Write-Host 'Setup failed. Review the messages above, then run the script again.'
    Write-Host $_.Exception.Message
    Write-Host ''
    Read-Host 'Press Enter to exit'
    exit 1
}
