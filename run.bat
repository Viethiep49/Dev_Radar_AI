@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
rem ==========================================================================
rem  DevRadar AI - chay toan bo du an bang 1 lenh (bam dup file nay).
rem    run.bat        : DB + backend (Docker) roi chay app Flutter
rem    run.bat ai     : them AI engine + Ollama (chat/tom tat AI that, can GPU)
rem    run.bat stop   : tat cac container
rem ==========================================================================
cd /d "%~dp0"

if /i "%~1"=="stop" (
    docker compose stop
    exit /b
)

rem ---- 1. Kiem tra Docker -------------------------------------------------
docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker Desktop chua chay. Hay mo Docker Desktop roi chay lai run.bat.
    pause
    exit /b 1
)

rem ---- 2. File .env --------------------------------------------------------
if not exist ".env" (
    echo Tao .env tu .env.example ...
    copy /y .env.example .env >nul
)
set "PORT=8080"
for /f "usebackq tokens=1,* delims==" %%a in (".env") do (
    if /i "%%a"=="BACKEND_PORT" if not "%%b"=="" set "PORT=%%b"
)

rem ---- 3. Bat server ---------------------------------------------------------
if /i "%~1"=="ai" (
    echo [1/4] Bat DB + backend + AI engine + Ollama ^(lan dau tai model se lau^)...
    docker compose up -d --build
) else (
    echo [1/4] Bat DB + backend + video engine...
    docker compose up -d --build db backend video-engine
)
if errorlevel 1 (
    echo [!] docker compose loi. Xem thong bao phia tren.
    pause
    exit /b 1
)

echo [2/4] Doi backend san sang tai http://localhost:%PORT% ...
set /a TRIES=0
:wait_backend
set /a TRIES+=1
curl -sf "http://localhost:%PORT%/health" >nul 2>&1 && goto backend_ok
if !TRIES! geq 60 (
    echo [!] Backend khong phan hoi. Xem log: docker compose logs backend
    pause
    exit /b 1
)
ping -n 3 127.0.0.1 >nul
goto wait_backend
:backend_ok

echo [3/4] Nap du lieu demo ^(demo@devradar.dev / demo1234^)...
docker compose exec -T backend python -m scripts.seed >nul 2>&1

rem ---- 4. Chay app Flutter ---------------------------------------------------
set "FLUTTER=flutter"
where flutter >nul 2>&1
if errorlevel 1 (
    if exist "E:\tools\flutter\bin\flutter.bat" (
        set "FLUTTER=E:\tools\flutter\bin\flutter.bat"
    ) else (
        echo [!] Khong tim thay Flutter. Cai Flutter hoac them vao PATH.
        echo     Backend van dang chay: http://localhost:%PORT%/docs
        pause
        exit /b 1
    )
)

echo.
echo [4/4] Chon noi chay app:
echo     1. Chrome ^(xem nhanh tren trinh duyet^)  [mac dinh]
echo     2. May ao Android ^(emulator^)
echo     3. Dien thoai that cung Wi-Fi
echo     4. Chi bat server, khong chay app
set "CHOICE=1"
set /p "CHOICE=Chon (1-4): "

cd mobile
call "%FLUTTER%" pub get >nul
if "%CHOICE%"=="2" (
    call :start_emulator
    call "%FLUTTER%" run -d emulator --dart-define=API_BASE_URL=http://10.0.2.2:%PORT%
) else if "%CHOICE%"=="3" (
    set "LANIP="
    for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr /c:"IPv4"') do if not defined LANIP set "LANIP=%%i"
    set "LANIP=!LANIP: =!"
    echo IP may tinh: !LANIP!  ^(dien thoai phai cung Wi-Fi^)
    call "%FLUTTER%" run --dart-define=API_BASE_URL=http://!LANIP!:%PORT%
) else if "%CHOICE%"=="4" (
    echo Server dang chay. API docs: http://localhost:%PORT%/docs  ^|  Tat: run.bat stop
) else (
    call "%FLUTTER%" run -d chrome --dart-define=API_BASE_URL=http://localhost:%PORT%
)
exit /b

rem ---- Bat may ao Android (AVD devradar_api36 trong E:	ools) va doi boot xong ----
:start_emulator
if exist "E:	oolsndroid-homevd" (
    set "ANDROID_USER_HOME=E:	oolsndroid-home"
    set "ANDROID_AVD_HOME=E:	oolsndroid-homevd"
)
if exist "E:	oolsndroid-sdk" set "ANDROID_HOME=E:	oolsndroid-sdk"
set "ADB=adb"
if defined ANDROID_HOME set "ADB=%ANDROID_HOME%\platform-toolsdb.exe"
"%ADB%" devices | findstr /r "emulator-[0-9]*.*device$" >nul && exit /b
echo Dang bat may ao Android ^(lan dau mat 1-2 phut^)...
call "%FLUTTER%" emulators --launch devradar_api36
"%ADB%" wait-for-device
:wait_boot
for /f %%b in ('"%ADB%" shell getprop sys.boot_completed 2^>nul') do if "%%b"=="1" exit /b
ping -n 3 127.0.0.1 >nul
goto wait_boot
