@echo off
echo ==============================================
echo  Starting DevRadar AI Mobile App (Flutter)
echo ==============================================
cd /d "%~dp0mobile"

echo 1. Chay tren Chrome (Web - xem ngay tren trinh duyet)
echo 2. Chay tren Android (May that hoac gia lap)
echo 3. Chay tren Edge
echo 4. Chon thiet bi tu dong (flutter run)
echo.
set /p choice="Chon thiet bi (1-4, mac dinh 1): "

if "%choice%"=="2" (
    flutter run -d android
) else if "%choice%"=="3" (
    flutter run -d edge
) else if "%choice%"=="4" (
    flutter run
) else (
    flutter run -d chrome
)
