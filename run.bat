@echo off
setlocal
title iPhone-Windows-Seamless-Transfer
:: ==========================================================
:: CHECK FOR ADMINISTRATOR PRIVILEGES & AUTO-ELEVATE
:: ==========================================================
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: ==========================================================
:: USER INPUT FOR CONFIGURATION (WITH DEFAULTS)
:: ==========================================================
cls
echo ===============================================================================
echo                       SHARE CONFIGURATION
echo ===============================================================================
echo Please define your connection details below.
echo.

:: Username Input with Default
set "shareUser="
set /p shareUser="Enter Username (Press ENTER for default 'AppleUser'): "
if "%shareUser%"=="" set "shareUser=AppleUser"

:: Password Input (Required)
set "sharePass="
:PassLoop
set /p sharePass="Enter a NEW Password for this user: "
if "%sharePass%"=="" (
    echo [ERROR] Password cannot be empty.
    goto PassLoop
)

:: Folder Path Input with Default
set "folderPath="
set /p folderPath="Enter folder path (Press ENTER for default 'C:\shared_folder'): "
if "%folderPath%"=="" set "folderPath=C:\shared_folder"

echo.
echo ===============================================================================
echo Setting up share with User: %shareUser% at Path: %folderPath%
echo ===============================================================================
echo.

echo --- Step 1: Forcing Network Profile to Private ---
powershell -Command "Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private" >nul 2>&1

echo --- Step 2: Creating or updating Local Share User [%shareUser%] ---
net user "%shareUser%" "%sharePass%" /add /passwordchg:no >nul 2>&1
if errorlevel 1 (
    net user "%shareUser%" "%sharePass%" >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Could not create or update the user account.
        goto :Fail
    )
)

echo --- Step 3: Preparing Folder and Permissions ---
if not exist "%folderPath%" mkdir "%folderPath%"
if not exist "%folderPath%" (
    echo [ERROR] Could not create the target folder.
    goto :Fail
)
icacls "%folderPath%" /grant "%shareUser%":(OI)(CI)F /T >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to grant folder permissions.
    goto :Fail
)

echo --- Step 4: Enabling Sharing and Opening Firewalls ---
net share "%shareUser%_Share" /delete /y >nul 2>&1
net share "%shareUser%_Share"="%folderPath%" /grant:"%shareUser%",full >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to create the SMB share.
    goto :Fail
)
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes >nul 2>&1
netsh advfirewall firewall add rule name="Force iOS SMB In (TCP 445)" dir=in action=allow protocol=TCP localport=445 >nul 2>&1

echo --- Step 5: Ensuring Windows File Sharing Service Starts Automatically ---
sc config LanmanServer start= auto >nul 2>&1
if errorlevel 1 (
    echo [WARN] Could not set Windows File Sharing service to automatic start.
)
net stop LanmanServer /y >nul 2>&1
net start LanmanServer >nul 2>&1
if errorlevel 1 (
    echo [WARN] Windows File Sharing service could not be restarted automatically.
)

:: ==========================================================
:: EXPORT DETAILS TO TEXT FILE (INSIDE SHARED FOLDER)
:: ==========================================================
set "exportFile=%folderPath%\iPhone_Share_Details.txt"

echo =============================================================================== > "%exportFile%"
echo                           SETUP COMPLETE!                                       >> "%exportFile%"
echo =============================================================================== >> "%exportFile%"
echo. >> "%exportFile%"
echo YOUR AVAILABLE IP ADDRESSES: >> "%exportFile%"
echo ------------------------------------------------------------------------------- >> "%exportFile%"
ipconfig | findstr "IPv4" >> "%exportFile%"
echo ------------------------------------------------------------------------------- >> "%exportFile%"
echo. >> "%exportFile%"
echo IMPORTANT IP SELECTION GUIDE: >> "%exportFile%"
echo * Ignore addresses starting with "169.254." (Disconnected adapters) >> "%exportFile%"
echo * Ignore addresses like "192.168.56.x" if you use VirtualBox >> "%exportFile%"
echo * Look for your main Wi-Fi/Ethernet IP (e.g., 192.168.1.x, 192.168.2.x) >> "%exportFile%"
echo. >> "%exportFile%"
echo =============================================================================== >> "%exportFile%"
echo                    HOW TO CONNECT ON YOUR IPHONE                                >> "%exportFile%"
echo =============================================================================== >> "%exportFile%"
echo 1. Open the "Files" app on your iPhone. >> "%exportFile%"
echo 2. Tap the three dots (...) in the top right corner. >> "%exportFile%"
echo 3. Tap "Connect to Server". >> "%exportFile%"
echo 4. Type the following using your correct IP address from above: >> "%exportFile%"
echo. >> "%exportFile%"
echo      smb://[YOUR_CORRECT_IP_ADDRESS] >> "%exportFile%"
echo. >> "%exportFile%"
echo 5. Tap "Connect". >> "%exportFile%"
echo 6. Choose "Registered User" and enter these exact credentials: >> "%exportFile%"
echo. >> "%exportFile%"
echo      Username:  %shareUser% >> "%exportFile%"
echo      Password:  %sharePass% >> "%exportFile%"
echo. >> "%exportFile%"
echo 7. Tap "Next". You will now see your shared folder! >> "%exportFile%"
echo =============================================================================== >> "%exportFile%"

:: ==========================================================
:: DISPLAY THE GENERATED FILE ON SCREEN
:: ==========================================================
cls
type "%exportFile%"
echo.
echo SUCCESS: The details above have been saved directly inside your shared folder:
echo "%exportFile%"
echo.
pause
goto :EOF

:Fail
echo.
echo Setup failed. Review the messages above, then run the script again.
echo.
pause
exit /b 1