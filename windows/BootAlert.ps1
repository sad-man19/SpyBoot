$t    = 'YOUR_BOT_TOKEN'
$c    = 'YOUR_USER_CHAT_ID'
$d    = 'C:\ProgramData\BootAlert'
$l    = "$d\log.txt"
$idFile = "$d\boot_id.txt"
$bootTimeFile = "$d\boot_time.txt"

if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }

# --- Boot detection ---
$curBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss')
$isNew = $true
if (Test-Path $idFile) {
    $saved = Get-Content $idFile
    if ($saved -eq $curBoot) { $isNew = $false }
}
if ($isNew) {
    $ts = Get-Date -Format 'yyyy-MM-dd hh:mm:ss tt'
    Add-Content -Path $l -Value $ts
    $curBoot | Out-File $idFile -Force
    Get-Date -Format 'yyyy-MM-dd HH:mm:ss' | Out-File $bootTimeFile
}

Write-Host "Boot detection: isNew=$isNew, Queue file exists: $(Test-Path $l)"
# --- Internet check ---
if (-not (Test-Connection 8.8.8.8 -Count 1 -Quiet)) { exit }

# --- Network info ---
$n = $env:COMPUTERNAME
$os = (Get-CimInstance Win32_OperatingSystem).Caption
$localIPs = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -ne '127.0.0.1' }).IPAddress -join ', '
$ssid = 'N/A'
try {
    $adapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' -and $_.MediaType -eq '802.3' -and $_.InterfaceDescription -match 'Wi-Fi|Wireless' }
    if (-not $adapter) { $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and ($_.InterfaceDescription -match 'Wi-Fi|Wireless') } }
    if ($adapter) { $ssid = (netsh wlan show interfaces | Select-String 'SSID').Line.Split(':')[1].Trim() }
} catch {}
$gateway = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' | Where-Object { $_.NextHop -ne '0.0.0.0' }).NextHop -join ', '
$pubIP = 'Unavailable'; $loc = ''
try {
    $pubIP = (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing).Content.Trim()
    $geo = Invoke-WebRequest -Uri "http://ip-api.com/json/$pubIP" -UseBasicParsing | ConvertFrom-Json
    if ($geo.status -eq 'success') { $loc = "$($geo.city), $($geo.country) ($($geo.isp))" } else { $loc = 'Unknown' }
} catch {}

# --- Send queued ---
$ms = Get-Content $l -ErrorAction SilentlyContinue
if ($ms) {
    foreach ($m in $ms) {
        $txt = "Device: $n`nOS: $os`nBooted at: $m`nLocal IP: $localIPs`nSSID: $ssid`nGateway: $gateway`nPublic IP: $pubIP`nLocation: $loc"
        $url = 'https://api.telegram.org/bot' + $t + '/sendMessage?chat_id=' + $c + '&text=' + [uri]::EscapeDataString($txt)
        try { Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop | Out-Null } catch { exit }
    }
    Remove-Item $l -Force
}