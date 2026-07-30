# --- DHCP Scope Picker (run as Administrator ON the DHCP server) ---
$scopes = Get-DhcpServerv4Scope

if (-not $scopes) {
    Write-Host "No scopes found (or access denied - run as Admin)." -ForegroundColor Red
    return
}

Write-Host "`nAvailable DHCP Scopes`n" -ForegroundColor Cyan
$i = 1; $menu = @{}
foreach ($s in $scopes) {
    $menu[$i] = $s.ScopeId
    "{0,3}. {1,-16} {2,-20} [{3}]" -f $i, $s.ScopeId, $s.Name, $s.State
    $i++
}

[int]$choice = Read-Host "`nEnter the number of the scope to inspect"
if (-not $menu.ContainsKey($choice)) {
    Write-Host "Invalid selection." -ForegroundColor Red
    return
}

$picked = $menu[$choice]
Write-Host "`n=== Stats for scope $picked ===`n" -ForegroundColor Green
Get-DhcpServerv4ScopeStatistics -ScopeId $picked |
    Select-Object ScopeId, Free, InUse, Reserved, PercentageInUse |
    Format-Table -AutoSize