# Secure Internet Kit Windows Installer v2.0 (Offline Ready)
# Запускать от имени Администратора!

Param(
    [Parameter(Mandatory=$true)]
    [string]$DeepLink
)

$InstallDir = "C:\Program Files\Secure Internet Kit"
$ClientBin = "$InstallDir\trusttunnel_client.exe"
$WizardBin = "$InstallDir\setup_wizard.exe"
$ConfigPath = "$InstallDir\config.toml"
$WintunDll = "$InstallDir\wintun.dll"

# 1. Проверка прав администратора
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Пожалуйста, запустите скрипт от имени Администратора!"
    exit
}

Write-Host "--- [1/4] Подготовка папок ---" -ForegroundColor Cyan
if (!(Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir }

Write-Host "--- [2/4] Установка компонентов ---" -ForegroundColor Cyan

$LocalDist = Join-Path $PSScriptRoot "dist"
if (Test-Path $LocalDist) {
    Write-Host "Обнаружены локальные файлы. Копирую из папки /dist..." -ForegroundColor Green
    Copy-Item "$LocalDist\*" -Destination $InstallDir -Force
    Write-Host "Файлы скопированы!" -ForegroundColor Green
} else {
    Write-Host "Локальные файлы не найдены. Скачиваю из интернета..." -ForegroundColor Yellow
    
    $BaseUrl = "https://github.com/TrustTunnel/TrustTunnelClient/releases/latest/download"
    
    Invoke-WebRequest -Uri "$BaseUrl/trusttunnel_client-x86_64-pc-windows-msvc.zip" -OutFile "$InstallDir\client.zip"
    Expand-Archive -Path "$InstallDir\client.zip" -DestinationPath $InstallDir -Force
    Remove-Item "$InstallDir\client.zip"
    
    # Скачивание Wintun.dll (критично для Windows TUN интерфейса)
    if (!(Test-Path $WintunDll)) {
        Write-Host "Скачивание Wintun драйвера..."
        Invoke-WebRequest -Uri "https://www.wintun.net/builds/wintun-0.14.1.zip" -OutFile "$InstallDir\wintun.zip"
        Expand-Archive -Path "$InstallDir\wintun.zip" -DestinationPath "$InstallDir\wintun_temp" -Force
        Copy-Item "$InstallDir\wintun_temp\wintun\bin\amd64\wintun.dll" -Destination $WintunDll
        Remove-Item "$InstallDir\wintun.zip"
        Remove-Item "$InstallDir\wintun_temp" -Recurse
    }
}

# Проверка наличия критичных файлов
if (!(Test-Path $ClientBin)) { Write-Error "trusttunnel_client.exe не найден!"; exit }
if (!(Test-Path $WizardBin)) { Write-Error "setup_wizard.exe не найден!"; exit }
if (!(Test-Path $WintunDll)) { Write-Warning "wintun.dll не найден. VPN может не заработать." }

Write-Host "--- [3/4] Настройка конфигурации ---" -ForegroundColor Cyan
# Сохраняем диплинк во временный файл, чтобы wizard его прожевал
$TempLinkFile = "$env:TEMP\link.txt"
$DeepLink | Out-File -FilePath $TempLinkFile -Encoding ascii

& $WizardBin --mode non-interactive --endpoint_config $TempLinkFile --settings $ConfigPath
Remove-Item $TempLinkFile

Write-Host "--- [3.5/3] Настройка DNS-over-HTTPS (DoH) ---" -ForegroundColor Cyan
# Добавляем зашифрованные DNS-апстримы для защиты от DNS-слежки
$DohConfig = @"

dns_upstreams = [
    `"https://dns.adguard-dns.com/dns-query`",
    `"https://cloudflare-dns.com/dns-query`",
    `"https://dns.google/dns-query`"
]
"@

$ConfigContent = Get-Content $ConfigPath -Raw
if ($ConfigContent -match 'dns_upstreams') {
    Write-Host "DoH уже настроен, пропускаю." -ForegroundColor Yellow
} else {
    # Insert before [listener.tun]; appending after it would make dns_upstreams
    # a key of that table instead of a top-level setting.
    $parts = $ConfigContent -split '(?m)^\[listener\.tun\]', 2
    if ($parts.Count -eq 2) {
        $NewConfig = $parts[0].TrimEnd() + "`n`n" + $DohConfig + "`n[listener.tun]" + $parts[1]
    } else {
        $NewConfig = $ConfigContent.TrimEnd() + "`n`n" + $DohConfig
    }
    $NewConfig | Set-Content $ConfigPath
    Write-Host "DoH настроен! DNS-запросы теперь зашифрованы." -ForegroundColor Green
}

Write-Host "--- [3.6/3] Настройка Selective Routing ---" -ForegroundColor Cyan
# Список исключений вшит в скрипт (банки, госуслуги, локальные сервисы РФ)
$Exclusions = @(
    "sberbank.ru", "*.sberbank.ru",
    "gosuslugi.ru", "*.gosuslugi.ru",
    "tinkoff.ru", "*.tinkoff.ru",
    "alfabank.ru", "*.alfabank.ru",
    "vtb.ru", "*.vtb.ru",
    "avito.ru", "*.avito.ru",
    "yandex.ru", "*.yandex.ru",
    "mail.ru", "*.mail.ru",
    "ok.ru", "*.ok.ru",
    "vk.com", "*.vk.com",
    "wildberries.ru", "*.wildberries.ru",
    "ozon.ru", "*.ozon.ru",
    "nalog.ru", "*.nalog.ru",
    "pfr.gov.ru", "*.pfr.gov.ru",
    "roskazna.ru", "*.roskazna.ru"
)
$ExclusionsString = ($Exclusions | ForEach-Object { "`"$_`"" }) -join ", "

$ConfigContent = Get-Content $ConfigPath -Raw
$NewConfig = $ConfigContent -replace 'exclusions = \[\]', "exclusions = [$ExclusionsString]"
$NewConfig | Set-Content $ConfigPath
Write-Host "Список исключений (банки, госуслуги) добавлен в конфиг." -ForegroundColor Green

Write-Host "--- [4/4] Установка службы Windows ---" -ForegroundColor Cyan
# Устанавливаем VPN как службу, чтобы он работал всегда
& $ClientBin --service-install --config $ConfigPath

# Запускаем службу
Start-Service "TrustTunnelClient"

Write-Host "--------------------------------------------------" -ForegroundColor Green
Write-Host "✅ Установка Secure Internet Kit завершена!" -ForegroundColor Green
Write-Host "VPN работает как фоновая служба." -ForegroundColor Green
Write-Host "Проверка статуса: Get-Service TrustTunnelClient" -ForegroundColor Green
Write-Host "--------------------------------------------------" -ForegroundColor Green
