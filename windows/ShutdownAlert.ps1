$t    = 'YOUR_BOT_TOKEN'
$c    = 'YOUR_USER_CHAT_ID'
$d    = 'C:\ProgramData\BootAlert'
$bootTimeFile = "$d\boot_time.txt"
$uptime = 'Unknown'

if (Test-Path $bootTimeFile) {
    try {
        $bootTime = Get-Date (Get-Content $bootTimeFile).Trim()
        $uptimeSpan = New-TimeSpan -Start $bootTime -End (Get-Date)
        $uptime = '{0} days {1} hrs {2} min' -f $uptimeSpan.Days, $uptimeSpan.Hours, $uptimeSpan.Minutes
    } catch {}
}

$n = $env:COMPUTERNAME
$os = (Get-CimInstance Win32_OperatingSystem).Caption
$txt = "Device: $n`nOS: $os`nEvent: Shutdown/Restart`nTime: $(Get-Date -Format 'yyyy-MM-dd hh:mm:ss tt')`nUptime: $uptime"
$url = 'https://api.telegram.org/bot' + $t + '/sendMessage?chat_id=' + $c + '&text=' + [uri]::EscapeDataString($txt)
try { Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop | Out-Null } catch {}