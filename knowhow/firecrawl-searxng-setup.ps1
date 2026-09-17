# firecrawl-searxng-setup.ps1
# PC再起動後に WSL2 を起動し、Docker コンテナを立ち上げ、portproxy を設定する
# タスクスケジューラからログオン時に管理者権限で実行する想定

$ports = @(3002, 8888)
$composePath = "~/Projects/firecrawl/docker-compose.yaml"

# --- 0. WSL2 を確実に起動し、Docker デーモンの準備完了を待つ ---
Write-Host "WSL2 を起動中..."
wsl.exe -- echo "WSL booted" | Out-Null

Write-Host "Docker デーモンの起動を待機..."
$maxRetries = 30
for ($i = 0; $i -lt $maxRetries; $i++) {
    wsl.exe bash -c "docker info" *> $null
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 2
}
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker デーモンが起動しませんでした"
    exit 1
}

# --- 1. WSL2 を起動し Docker コンテナを立ち上げる ---
# systemd=true により Docker は WSL 起動時に自動起動する
Write-Host "WSL2 + Docker コンテナを起動中..."
wsl.exe bash -c "docker compose -f $composePath up -d"

# --- 2. WSL2 の IP アドレスを取得 ---
$wslIp = (wsl.exe bash -c "hostname -I").Trim().Split()[0]

if (-not $wslIp) {
    Write-Error "WSL2 の IP アドレスを取得できませんでした"
    exit 1
}

Write-Host "WSL2 IP: $wslIp"

# --- 3. portproxy を設定 ---
foreach ($port in $ports) {
    netsh interface portproxy delete v4tov4 listenport=$port listenaddress=0.0.0.0 2>$null
    netsh interface portproxy add v4tov4 listenport=$port listenaddress=0.0.0.0 connectport=$port connectaddress=$wslIp
    Write-Host "Port $port -> ${wslIp}:${port}"
}

Write-Host "`nportproxy 設定完了:"
netsh interface portproxy show all
