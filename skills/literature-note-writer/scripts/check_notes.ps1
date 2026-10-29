# 结构校验 PowerShell 版（无 Python 环境的替代方案）
# 用法: pwsh -File check_notes.ps1 -NotesDir "我的库\笔记" -StatusTag "#待整理"
param(
  [string]$NotesDir = "笔记",
  [string]$StatusTag = "#待整理",
  [string]$JsonOut = ""
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $NotesDir)) { Write-Error "目录不存在: $NotesDir"; exit 2 }

$types = @("期刊论文", "辑刊论文", "田野报告", "专著", "学位论文")
$files = Get-ChildItem $NotesDir -Filter *.md | Where-Object { $_.Name -notlike "obsidian模板*" }
if (-not $files) { Write-Error "$NotesDir 下没有 .md 文件"; exit 2 }
$known = @{}
foreach ($f in $files) { $known[$f.BaseName] = $true }

$rows = @(); $bad = 0
foreach ($f in $files) {
  $t = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
  $r = [ordered]@{ file = $f.Name; yaml = $false; h1 = $false; sections = 0; links = 0; badLinks = @()
                   fileNameOk = $false; titleOk = $false; typeOk = $false; readOk = $false
                   sitQuoted = $false; sitKaogu = $false; srcKaogu = $false; extFmt = 0; placeholders = 0 }

  # frontmatter
  $keys = @("title","author","year","type","tags","sitation")
  $fm = @{}
  if ($t -match "(?s)^---\r?\n(.*?)\r?\n---") {
    $fmLines = $matches[1] -split "\r?\n"
    for ($i = 0; $i -lt $fmLines.Count; $i++) {
      if ($fmLines[$i] -match "^([A-Za-z0-9_\-]+):\s*(.*)$") {
        $k = $matches[1]; $v = $matches[2].Trim()
        if ($v -eq "") {
          # 空值后若接列表项，则视为有值
          $j = $i + 1
          while ($j -lt $fmLines.Count -and $fmLines[$j].Trim() -eq "") { $j++ }
          if ($j -lt $fmLines.Count -and $fmLines[$j].TrimStart().StartsWith("- ")) { $v = "LIST" }
        }
        $fm[$k] = $v
      }
    }
  }
  $missing = @($keys | Where-Object { -not $fm.ContainsKey($_) -or $fm[$_] -eq "" })
  $r.yaml = ($missing.Count -eq 0)

  $title = if ($fm["title"]) { $fm["title"].Trim([char]34) } else { "" }
  $h1 = [regex]::Matches($t, "(?m)^# (?!#)(.+?)\r?$")
  $r.h1 = ($h1.Count -eq 1)
  $r.sections = ([regex]::Matches($t, "(?m)^##\s*[1-8]\.\s*\S") | ForEach-Object { $_.Value.Trim() } | Sort-Object -Unique).Count

  $tg = [regex]::Matches($t, "\[\[([^\]\|#]+)")
  $r.links = $tg.Count
  $r.badLinks = @($tg | ForEach-Object { $_.Groups[1].Value.Trim() } | Where-Object { -not $known.ContainsKey($_) } | Sort-Object -Unique)

  $r.fileNameOk = ($f.BaseName -eq $title) -and ($f.BaseName -notmatch '[\\/:*?"<>|]')
  $r.titleOk = $r.h1 -and ($h1[0].Groups[1].Value.Trim() -eq $title) -and $r.fileNameOk
  $r.typeOk = $types -contains $fm["type"]
  $r.readOk = ($t -match "(?m)^\*\*阅读状态：\*\*\s*(\S+)\s*\r?$") -and ($matches[1] -eq $StatusTag)

  $sitLine = (Get-Content $f.FullName -Encoding UTF8 | Where-Object { $_ -like "sitation:*" } | Select-Object -First 1)
  $raw = if ($sitLine) { $sitLine.Substring(9).Trim() } else { "" }
  $r.sitQuoted = $raw.StartsWith('"') -and $raw.EndsWith('"')
  $body = $raw.Trim('"')
  $r.sitKaogu = $body -match '^.+：《.+?》，.*(《.+》\d{4}年第\d+期。|，\d{4}年，第\d+页。|，[博士硕士]学位论文，.+，\d{4}年。)$'
  $srcLine = ($t -split "\r?\n" | Where-Object { $_ -like "- **来源：** *" } | Select-Object -First 1)
  $r.srcKaogu = [bool]$srcLine -and $srcLine.Contains("《") -and $srcLine.Contains("》")

  $ext = [regex]::Matches($t, "(?m)^- .*（选读原因：.+）\r?$") | Where-Object { $_.Value.Contains("《") -or $_.Value.Contains("*") }
  $r.extFmt = @($ext).Count
  $r.placeholders = ([regex]::Matches($t, "<%|%>|TODO|待填")).Count

  $failed = @()
  foreach ($k in @("yaml","h1","fileNameOk","titleOk","typeOk","readOk","sitQuoted","sitKaogu","srcKaogu")) {
    if (-not $r[$k]) { $failed += $k }
  }
  if ($r.sections -ne 8) { $failed += "sections" }
  if ($r.badLinks.Count -gt 0) { $failed += "badLinks" }
  if ($r.extFmt -ne 3) { $failed += "extFmt" }
  if ($r.placeholders -gt 0) { $failed += "placeholders" }
  if ($failed.Count -gt 0) { $bad++ }

  Write-Output ("{0,-46} {1}" -f $f.Name.Substring(0, [Math]::Min(44, $f.Name.Length)), $(if ($failed.Count) { "FAIL " + ($failed -join ",") } else { "OK" }))
  $rows += [pscustomobject]$r
}
if ($JsonOut) { $rows | ConvertTo-Json -Depth 5 | Set-Content $JsonOut -Encoding UTF8 }
Write-Output ("COUNT=$($files.Count) BAD=$bad")
if ($bad -gt 0) { exit 1 } else { exit 0 }