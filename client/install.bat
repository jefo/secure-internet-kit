@echo off
:: Secure Internet Kit — Windows Offline Installer
:: Файлы на флешке рядом с install.bat:
::   trusttunnel_client.exe
::   wintun.dll
::   config.toml   (сгенерирован заранее под конкретного клиента)
::
:: Запуск: ПКМ → Запуск от имени Администратора

setlocal enabledelayedexpansion
set INSTALL_DIR=C:\Program Files\Secure Internet Kit
set SCRIPT_DIR=%~dp0

echo ==================================================
echo   Secure Internet Kit — установка
echo ==================================================
echo.

:: Проверка прав администратора
net session >nul 2>&1
if !errorlevel! neq 0 (
    echo [!] ОШИБКА: запусти install.bat от имени Администратора
    echo     ПКМ по install.bat ^> Запуск от имени Администратора
    echo.
    pause
    exit /b 1
)

:: Проверка, что config.toml рядом
if not exist "%SCRIPT_DIR%config.toml" (
    echo [!] ОШИБКА: файл config.toml не найден рядом с install.bat
    echo     Сгенерируй config.toml на сервере и положи на флешку
    echo.
    pause
    exit /b 1
)

echo [1/4] Копирование файлов в %INSTALL_DIR%...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
copy /Y "%SCRIPT_DIR%trusttunnel_client.exe" "%INSTALL_DIR%\" >nul 2>&1
if !errorlevel! neq 0 (
    echo [!] ОШИБКА: trusttunnel_client.exe не найден на флешке
    pause
    exit /b 1
)
copy /Y "%SCRIPT_DIR%wintun.dll"          "%INSTALL_DIR%\" >nul 2>&1
if !errorlevel! neq 0 (
    echo [!] ПРЕДУПРЕЖДЕНИЕ: wintun.dll не найден — VPN может не работать
)
copy /Y "%SCRIPT_DIR%config.toml"         "%INSTALL_DIR%\" >nul
echo     Готово.

echo [2/4] Остановка старой службы (если была)...
sc stop TrustTunnelClient >nul 2>&1
sc delete TrustTunnelClient >nul 2>&1
echo     Готово.

echo [3/4] Регистрация службы Windows...
"%INSTALL_DIR%\trusttunnel_client.exe" --service-install --config "%INSTALL_DIR%\config.toml"
if !errorlevel! neq 0 (
    echo [!] ОШИБКА регистрации службы
    pause
    exit /b 1
)
echo     Служба зарегистрирована.

echo [4/4] Запуск...
sc start TrustTunnelClient
if !errorlevel! neq 0 (
    echo [!] Не удалось запустить службу. Проверь конфиг.
    echo     sc query TrustTunnelClient
    pause
    exit /b 1
)

echo.
echo ==================================================
echo   ГОТОВО. VPN работает в фоне.
echo.
echo   Проверка:
echo     Открой ifconfig.me в браузере
echo     IP должен быть: YOUR_SERVER_IP
echo.
echo   Управление:
echo     sc stop  TrustTunnelClient   — остановить
echo     sc start TrustTunnelClient   — запустить
echo     sc query TrustTunnelClient   — статус
echo ==================================================
pause
