<#
.SYNOPSIS
    System Health Diagnostic Tool (Read-Only + Full Audit)
.DESCRIPTION
    Gathers a complete system health report including CPU, Disk, Drivers, Network, Pending Updates,
    Event Log Errors, Security Posture, Windows Version, Serial Number, Model, and MAC Addresses.
#>

# --- Color Engine (ANSI / Fallback) ---
$SupportsANSI = $Host.UI.SupportsVirtualTerminal
if ($SupportsANSI)
{
	$esc = [char]27
	$red = "$esc[91m"
	$green = "$esc[92m"
	$yellow = "$esc[93m"
	$cyan = "$esc[96m"
	$reset = "$esc[0m"
}
else { $red = $green = $yellow = $cyan = $reset = "" }

function Write-Color { param ([string]$Message,
		[string]$Color = "White"); if ($SupportsANSI) { $map = @{ Red = $red; Green = $green; Yellow = $yellow; Cyan = $cyan; White = "" }; Write-Host "$($map[$Color])$Message$reset" }
	else { Write-Host $Message -ForegroundColor $Color } }
function Get-StatusText { param ($Text,
		$Color); if ($SupportsANSI) { $map = @{ Red = $red; Green = $green; Yellow = $yellow; Cyan = $cyan }; return "$($map[$Color])$Text$reset" }
	else { return $Text } }
function Write-SectionHeader { param ($Title); if ($SupportsANSI) { Write-Host "`n$cyan===================================================================$reset"; Write-Host "$cyan          $Title          $reset"; Write-Host "$cyan===================================================================$reset" }
	else { Write-Color "`n===================================================================" Cyan; Write-Color "          $Title          " Cyan; Write-Color "===================================================================" Cyan } }

# --- Report Object ---
$report = @{ }
Write-Color "Gathering system data, please wait..." Yellow

# --- Basic Info ---
$report.ComputerName = $env:COMPUTERNAME
$report.Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$os = Get-CimInstance Win32_OperatingSystem
$report.LastBootTime = $os.LastBootUpTime
$report.Uptime = (Get-Date) - $os.LastBootUpTime

# --- Additional System Info ---
try
{
	$bios = Get-CimInstance Win32_BIOS
	$cs = Get-CimInstance Win32_ComputerSystem
	$report.WindowsVersion = "$($os.Caption) $($os.Version) $($os.BuildNumber) $($os.OSArchitecture)" # e.g., Windows 11 Pro 23H2 10.0.22621 x64
	$report.SerialNumber = $bios.SerialNumber
	$report.Model = $cs.Model
	$report.Manufacturer = $cs.Manufacturer
	$report.MACAddresses = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Select-Object -ExpandProperty MacAddress
}
catch
{
	$report.WindowsVersion = "Unknown"
	$report.SerialNumber = "Unknown"
	$report.Model = "Unknown"
	$report.Manufacturer = "Unknown"
	$report.MACAddresses = @("Unknown")
}

# --- CPU ---
$report.CpuConsumers = Get-Process | Sort CPU -Descending | Select -First 5

# --- Network ---
$report.PingTest = Test-Connection 8.8.8.8 -Count 1 -Quiet
try { Resolve-DnsName google.com -ErrorAction Stop | Out-Null; $report.DnsTest = $true }
catch { $report.DnsTest = $false }

# --- Disk & Drivers ---
$report.DiskInfo = Get-Volume | Where DriveLetter
$report.DriverIssues = Get-PnpDevice -Status Error

# --- Windows Updates (Read-Only) ---
try
{
	$updateSession = New-Object -ComObject "Microsoft.Update.Session"
	$updateSearcher = $updateSession.CreateUpdateSearcher()
	$searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
	$report.PendingUpdates = $searchResult.Updates
	$report.PendingUpdatesList = @()
	foreach ($update in $report.PendingUpdates)
	{
		$kb = ($update.Title | Select-String "KB\d+" -AllMatches).Matches.Value -join ","
		$report.PendingUpdatesList += [PSCustomObject]@{
			Title = $update.Title
			KB    = if ($kb) { $kb }else{ "N/A" }
			Downloaded = $update.IsDownloaded
			Mandatory = $update.IsMandatory
		}
	}
}
catch { $report.PendingUpdates = @(); $report.PendingUpdatesList = @() }

# --- Reboot Detection ---
$pendingFileRename = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -ErrorAction SilentlyContinue).PendingFileRenameOperations -ne $null
$wuReboot = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
$cbsReboot = Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
$report.RebootPending = $pendingFileRename -or $wuReboot -or $cbsReboot
$report.UpdateRebootRequired = $wuReboot

# --- Event Logs (Last 72 hours) ---
try
{
	$eventFilter = @{ LogName = @('System', 'Application'); Level = @(1, 2); StartTime = (Get-Date).AddHours(-72) }
	$report.Events = Get-WinEvent -FilterHashtable $eventFilter -MaxEvents 20 -ErrorAction Stop
}
catch { $report.Events = @() }

# --- Security Data ---
try { $report.Activation = Get-CimInstance SoftwareLicensingProduct | Where-Object { $_.Name -like "Windows*" -and $_.PartialProductKey } }
catch { $report.Activation = @() }
try { $report.FirewallProfiles = Get-NetFirewallProfile }
catch { $report.FirewallProfiles = @() }
try { $report.DefenderStatus = Get-MpComputerStatus -ErrorAction Stop }
catch { $report.DefenderStatus = $null }

# --- Header ---
Write-Color "`n--- System Health Report ---" Cyan
Write-Host "Report for $($report.ComputerName) on $($report.Timestamp)`n"
Write-Host "Windows Version: $($report.WindowsVersion)"
Write-Host "Model / Manufacturer: $($report.Model) / $($report.Manufacturer)"
Write-Host "Serial Number: $($report.SerialNumber)"
Write-Host "MAC Address(es): $($report.MACAddresses -join ', ')`n"

# --- Summary ---
Write-SectionHeader "At-a-Glance Summary"
$internetText = if ($report.PingTest -and $report.DnsTest) { Get-StatusText "CONNECTED" Green }
else { Get-StatusText "DISCONNECTED" Red }
$driversText = if ($report.DriverIssues) { Get-StatusText "ISSUES ($($report.DriverIssues.Count))" Yellow }
else { Get-StatusText "OK" Green }
$diskLow = $report.DiskInfo | Where { (($_.SizeRemaining/$_.Size) * 100) -lt 15 }
$diskText = if ($diskLow) { Get-StatusText "LOW DISK" Red }
else { Get-StatusText "OK" Green }
$rebootText = if ($report.RebootPending) { Get-StatusText "REBOOT REQUIRED" Red }
else { Get-StatusText "OK" Green }
$updatesText = if ($report.PendingUpdates.Count -gt 0) { Get-StatusText "PENDING ($($report.PendingUpdates.Count))" Yellow }
else { Get-StatusText "UP TO DATE" Green }
$updateRebootText = if ($report.UpdateRebootRequired) { Get-StatusText "REBOOT REQUIRED (Updates)" Red }
else { Get-StatusText "No reboot needed" Green }

Write-Host " - Internet:        $internetText"
Write-Host " - Disk:            $diskText"
Write-Host " - Drivers:         $driversText"
Write-Host " - Updates:         $updatesText"
Write-Host " - Update Reboot:   $updateRebootText"
Write-Host " - System Reboot:   $rebootText"

# --- PC Uptime ---
Write-SectionHeader "PC Uptime"
Write-Host "Last Boot: $($report.LastBootTime)"
Write-Host "Uptime: $($report.Uptime.Days)d $($report.Uptime.Hours)h $($report.Uptime.Minutes)m"

# --- CPU ---
Write-SectionHeader "Top CPU Consumers"
$report.CpuConsumers | Select ProcessName, Id, @{ n = "CPU(s)"; e = { [math]::Round($_.CPU, 2) } } | Format-Table -AutoSize

# --- Disk ---
Write-SectionHeader "Disk Space"
$report.DiskInfo | Select DriveLetter, @{ n = "Free(GB)"; e = { [math]::Round($_.SizeRemaining/1GB, 2) } }, @{ n = "Status"; e = { if ((($_.SizeRemaining/$_.Size) * 100) -lt 15) { Get-StatusText "LOW" Red }
		else { Get-StatusText "OK" Green } } } | Format-Table -AutoSize

# --- Drivers ---
Write-SectionHeader "Driver Issues"
if ($report.DriverIssues) { $report.DriverIssues | Select FriendlyName, Status | Format-Table }
else { Write-Color "No driver issues detected." Green }

# --- Event Logs ---
Write-SectionHeader "Recent Critical & Error Events (Last 72 Hours)"
if ($report.Events -and $report.Events.Count -gt 0)
{
	$report.Events | Select-Object TimeCreated, @{ Name = "Level"; Expression = { Get-StatusText $_.LevelDisplayName Red } }, ProviderName, Id, @{ Name = 'Message'; Expression = { ($_.Message -split [Environment]::NewLine)[0] } } | Format-Table -AutoSize -Wrap
}
else { Write-Color "No critical or error events found." Green }

# --- Security Posture ---
Write-SectionHeader "Security Posture"
Write-Host "`n- Windows Activation:"
$report.Activation | Select-Object @{ Name = "Product"; Expression = { $_.Name } }, @{ Name = "Status"; Expression = { if ($_.LicenseStatus -eq 1) { Get-StatusText "Licensed" Green }
		else { Get-StatusText "Unlicensed" Red } } } | Format-Table -AutoSize
Write-Host "`n- Firewall Status:"
$report.FirewallProfiles | Select-Object Name, @{ Name = "Enabled"; Expression = { if ($_.Enabled) { Get-StatusText "True" Green }
		else { Get-StatusText "False" Red } } } | Format-Table -AutoSize
Write-Host "`n- Windows Defender:"
if ($report.DefenderStatus) { $report.DefenderStatus | Select-Object @{ Name = "Antivirus"; Expression = { if ($_.AntivirusEnabled) { Get-StatusText "Enabled" Green }
			else { Get-StatusText "Disabled" Red } } }, @{ Name = "Real-Time Protection"; Expression = { if ($_.RealTimeProtectionEnabled) { Get-StatusText "Enabled" Green }
			else { Get-StatusText "Disabled" Red } } } | Format-Table -AutoSize }
else { Write-Color "No Windows Defender status. A third-party AV may be active." Yellow }
Write-Host "`n- UAC Status:"
$uacEnabled = 1
try { $uacKey = Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ErrorAction Stop; if ($uacKey.GetValue("EnableLUA") -ne $null) { $uacEnabled = $uacKey.GetValue("EnableLUA") } }
catch { }
$uacStatus = if ($uacEnabled -eq 0) { Get-StatusText "Disabled" Red }
else { Get-StatusText "Enabled" Green }
Write-Host "UAC is $uacStatus"

# --- Windows Updates ---
Write-SectionHeader "Windows Updates"
if ($report.PendingUpdates.Count -gt 0)
{
	Write-Color "Found $($report.PendingUpdates.Count) update(s)." Yellow
	$report.PendingUpdatesList | Select Title, KB, Downloaded, Mandatory | Format-Table -AutoSize -Wrap
}
else { Write-Color "System is up to date." Green }

# --- Done ---
Write-Color "`nScan complete." Cyan