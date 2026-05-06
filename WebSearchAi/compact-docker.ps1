# Compact Docker WSL2 disk (Windows only)
$path = "$env:LOCALAPPDATA\Docker\wsl\disk\docker_data.vhdx"
Write-Host "Shutting down Docker..."
Get-Process | Where-Object { $_.Name -like "*docker*" } | Stop-Process -Force
Get-Service | Where-Object { $_.Name -like "*docker*" } | Stop-Service -Force
Write-Host "Shutting down WSL..."
wsl --shutdown
if (Test-Path $path) {
    Write-Host "Compacting: $path"
    @"
select vdisk file="$path"
attach vdisk readonly
compact vdisk
detach vdisk
"@ | diskpart
    Write-Host "Compaction complete."
}
else {
    Write-Host "Docker VHDX not found: $path"
}