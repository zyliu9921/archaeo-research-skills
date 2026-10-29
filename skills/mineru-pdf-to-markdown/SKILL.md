---
name: mineru-pdf-to-markdown
description: 用 MinerU 把一批 PDF（尤其中文考古、历史类排版复杂的论文与报告）批量转成 Markdown，导出正文与图片，并把图片链接改写成 Obsidian／本地可预览的相对路径。当用户要求「批量 PDF 转 Markdown」「文献转 markdown」「MinerU 转换」「把这一文件夹的 PDF 都转掉」时使用。
---

# PDF 批量转 Markdown（MinerU）

把一整个文件夹的 PDF 交给 MinerU 解析，收齐结果后导出 Markdown 与图片。产出面向后续阅读与笔记写作，不追求出版级排版还原。

## 前置条件

需要一种 MinerU 访问方式，三选一：

| 方式 | 说明 | 适用 |
|---|---|---|
| 宿主插件 | 宿主已装 MinerU 插件（如 DeepSeek Harness 的 `async_parse_pdf` / `read_pdf`），工具内部读插件配置与凭据 | 最省事 |
| 官方 API | `https://mineru.net/api/v4`，需 `MINERU_API_KEY`；提交任务→轮询→下载结果包 | 跨宿主、批量 |
| 本地 CLI | 自建 MinerU 服务或命令行版 | 离线、有算力 |

无论哪种方式，产物的目录结构都应包含 `full.md`（或等价的主 Markdown）与 `images/`。

## 工作区约定

```
我的库/
  阅读文献/              # 待处理 PDF
  阅读文献 markdown/     # 转换产物：<PDF基名>.md
  阅读文献 markdown/assets/<PDF基名>/   # 该篇图片
  convert_report.json    # 成功／失败清单
```

`-PdfDir`、`-OutDir` 可任意指定，其余路径由脚本推导。

## 步骤

### 1. 逐篇提交解析

- 对 `阅读文献/` 内**每个** PDF 提交一次解析任务，记下任务 id。
- 逐个收取结果；失败或超时的记入失败清单，**不要伪造**「已转换」。
- 长文档解析可能需数分钟到十几分钟，用后台任务等待，不要空转轮询。

### 2. 定位解析缓存

MinerU 插件把结果写在缓存目录，形如：

```
<缓存根>/results/sha256/<cacheKey 前2位>/<cacheKey>/manifest.json
<缓存根>/results/sha256/<cacheKey 前2位>/<cacheKey>/files/<fileId>/full.md
```

**常见错误**：用 PDF 自身 sha256 的前两位拼目录。目录名取的是 `manifest.cacheKey` 的前两位，二者不同。
正确做法是反过来：遍历缓存中的 `manifest.json`，读 `sourceSha256`（等于 PDF 文件 sha256）建立索引。

### 3. 导出

```powershell
pwsh -File scripts/mineru_export.ps1 `
  -PdfDir "我的库\阅读文献" -OutDir "我的库\阅读文献 markdown" `
  -CacheRoot "$env:USERPROFILE\.dsh\cache\pdf-mineru"
```

脚本做四件事：

1. 计算每个 PDF 的 sha256，与 `manifest.sourceSha256` 匹配找到缓存目录；
2. 把 `full.md` 写成 `<PDF基名>.md`；
3. 把 `images/` 复制到 `assets/<PDF基名>/`，并把正文 `(images/` 改写成 `(assets/<PDF基名>/`；
4. 输出 `convert_report.json`（`ok` / `fail` 明细）。

`-CacheRoot` 也可用环境变量 `MINERU_CACHE` 提供；DSH 默认缓存根为 `~/.dsh/cache/pdf-mineru`。

### 4. 质量抽查

转换质量随版面差异很大，导出后必须抽检：

- **数字丢失**：中文排版 PDF 常整片丢年份、页码、表内数值。用 `pdftotext -f <页> -l <页> -enc UTF-8 <pdf> <out.txt>` 抽原页对照。
- **编码问题**：少数 PDF 用 Adobe-GB1 子集且无 ToUnicode，`pdftotext` 与图像渲染都只剩标点与拉丁字母；此时只能信 MinerU 的 Markdown，引用数据需另行外部核实。
- **表格与图注**：跨页表格易错位，图号图注可能落到下一段。

缺数据就在后续笔记里写明「原文该处数据在转换中丢失，须回溯原刊」，**禁止编造**页码或数值。

### 5. 汇报

交付时给三张清单：

1. 成功清单（PDF → md 路径、图片数量）；
2. 失败清单（PDF 名 + 失败原因 + 处置建议）；
3. 质量存疑清单（数字丢失、表格错位、编码不可读）。

## 环境坑

1. **写文件工具可能被沙箱拒绝**（报 `EISDIR ... .tmpdir\...tmp`）。改用脚本写：`[IO.File]::WriteAllText($p, $s, (New-Object System.Text.UTF8Encoding($false)))`。
2. **`.ps1` 必须存成 UTF8 带 BOM**，否则 Windows PowerShell 5.1 按 GBK 解码，中文路径与正则全乱。建议直接用 `pwsh`（PowerShell 7）。
3. 缓存目录名取 `manifest.cacheKey` 前两位，**不是** PDF sha 的前两位。
4. 控制台按 GBK 显示时，`Get-Content` 打印 UTF-8 中文会乱码——不要据此判断文件损坏，改用 `-Encoding UTF8`。
5. 批量导出前先跑一个 PDF 验证路径，再全量跑；一次全量失败排查成本高。

## 边界

- 本 skill 不处理 OCR 之外的版面重建，不保证标题层级与原文一致。
- 论文原文的版权归原作者与刊物，转换产物仅供个人阅读使用，不要公开分发。