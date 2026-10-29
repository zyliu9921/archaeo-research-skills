# MinerU 访问方式探测：判断这一批活有没有可用的凭据/服务
# 用法: powershell -File check_env.ps1 [-LocalPorts 8000,18000]
# 退出码: 0 至少一条路可用；1 无可用路径（应停下来问人）；2 参数错误
param(
  [string]$EnvName = "MINERU_API_KEY",
  [int[]]$LocalPorts = @(8000, 18000)
)

$ErrorActionPreference = "SilentlyContinue"
$usable = $false

# [1] 环境变量：只报有无与长度，绝不回显值
$val = [Environment]::GetEnvironmentVariable($EnvName)
$valUser = [Environment]::GetEnvironmentVariable($EnvName, "User")
$valMachine = [Environment]::GetEnvironmentVariable($EnvName, "Machine")
if ($val) {
  Write-Output ("[1] 环境变量 {0} : ok（长度 {1}，值不回显）" -f $EnvName, $val.Length)
  $usable = $true
} else {
  $hint = if ($valUser -or $valMachine) { "（当前进程未继承，重开终端试试）" } else { "" }
  Write-Output ("[1] 环境变量 {0} : missing{1}" -f $EnvName, $hint)
}

# [2] 本地 MinerU 服务：只看端口是否在听
foreach ($p in $LocalPorts) {
  $client = New-Object System.Net.Sockets.TcpClient
  $open = $false
  try {
    $iar = $client.BeginConnect("127.0.0.1", $p, $null, $null)
    $open = $iar.AsyncWaitHandle.WaitOne(800) -and $client.Connected
  } catch { $open = $false } finally { $client.Close() }
  Write-Output ("[2] 本地服务 127.0.0.1:{0} : {1}" -f $p, $(if ($open) { "reachable" } else { "closed" }))
  if ($open) { $usable = $true }
}

# [3] 宿主插件：脚本无法探测，只能标 unknown
Write-Output "[3] 宿主插件 : unknown（脚本无法读取宿主插件配置，需向使用者确认）"

if ($usable) {
  Write-Output "VERDICT: usable - 可继续，若走宿主插件路径请人工再确认一次"
  exit 0
} else {
  Write-Output "VERDICT: no-path - 停止提交，按 SKILL.md 第 0 步向使用者索取凭据"
  exit 1
}