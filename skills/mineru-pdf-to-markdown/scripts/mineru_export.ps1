# MinerU 批量导出：把缓存中的 full.md 与图片导出到「阅读文献 markdown」
# 用法: pwsh -File mineru_export.ps1 -PdfDir "我的库\阅读文献" -OutDir "我的库\阅读文献 markdown" [-CacheRoot <MinerU缓存目录>]
param(
  [Parameter(Mandatory=$true)][string]$PdfDir,
  [Parameter(Mandatory=$true)][string]$OutDir,
  [string]$CacheRoot = $env:MINERU_CACHE,
  [string]$AssetsFolderName = "assets",
  [string]$ReportPath = ""
)
$ErrorActionPreference = "Stop"
if (-not $CacheRoot) { throw "未指定 MinerU 缓存目录：请用 -CacheRoot 传入，或设置环境变量 MINERU_CACHE（DSH 默认为 ~/.dsh/cache/pdf-mineru）" }
if (-not $ReportPath) { $ReportPath = Join-Path (Split-Path $OutDir -Parent) "convert_report.json" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$assetsRoot = Join-Path $OutDir $AssetsFolderName

# 1) 建立 sha256 -> 结果目录 索引（manifest.sourceSha256 即源 PDF 的 sha256）
$index = @{}
Get-ChildItem (Join-Path $CacheRoot "results\sha256") -Directory -ErrorAction SilentlyContinue | ForEach-Object {
  Get-ChildItem $_.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $mf = Join-Path $_.FullName "manifest.json"
    if (Test-Path $mf) {
      $m = Get-Content $mf -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($m.sourceSha256) { $index[$m.sourceSha256.ToLower()] = $_.FullName }
    }
  }
}

$ok = @(); $fail = @()
$enc = New-Object System.Text.UTF8Encoding($false)
foreach ($pdf in Get-ChildItem $PdfDir -Filter *.pdf) {
  $sha = (Get-FileHash $pdf.FullName -Algorithm SHA256).Hash.ToLower()
  $dir = $index[$sha]
  if (-not $dir) { $fail += [pscustomobject]@{ pdf = $pdf.Name; reason = "no cache (尚未解析或解析未完成)" }; continue }
  $md = Get-ChildItem $dir -Recurse -Filter full.md | Select-Object -First 1
  if (-not $md) { $fail += [pscustomobject]@{ pdf = $pdf.Name; reason = "full.md missing in cache" }; continue }
  $base = $pdf.BaseName
  $text = [IO.File]::ReadAllText($md.FullName, [Text.Encoding]::UTF8)
  # 2) 图片目录搬到 Obsidian 可见位置，并改写链接
  $imgDir = Join-Path (Split-Path $md.FullName -Parent) "images"
  $destImg = Join-Path $assetsRoot $base
  if (Test-Path $imgDir) {
    New-Item -ItemType Directory -Force -Path $destImg | Out-Null
    Copy-Item (Join-Path $imgDir "*") $destImg -Recurse -Force
    $text = $text.Replace("(images/", "(assets/$base/")
  }
  $target = Join-Path $OutDir ($base + ".md")
  [IO.File]::WriteAllText($target, $text, $enc)
  $ok += [pscustomobject]@{ pdf = $pdf.Name; md = $target; images = (Get-ChildItem $destImg -ErrorAction SilentlyContinue).Count }
}
$report = [pscustomobject]@{ generatedAt = (Get-Date).ToString("s"); ok = $ok; fail = $fail }
New-Item -ItemType Directory -Force -Path (Split-Path $ReportPath -Parent) | Out-Null
$report | ConvertTo-Json -Depth 5 | Set-Content $ReportPath -Encoding UTF8
"OK=$($ok.Count) FAIL=$($fail.Count)"
foreach ($f in $fail) { "FAIL: $($f.pdf) - $($f.reason)" }