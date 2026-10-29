# 快速上手

## 场景一：把外文文献译成中文

1. 装 `archaeology-translation`。
2. 对 AI 说：「按 archaeology-translation 的规范翻译这篇，术语先查 glossary，遗址名上网核实。」
3. 交稿后对照 SKILL.md 末尾的自检清单逐条过。

最常见的失败不是译错术语，而是**中国遗址名凭拼音猜**。规则要求查证；查不到就写
`待核实（原文: Dadiwan）`，不允许直接给一个中文名。

## 场景二：把注释改成《考古》体例

1. 装 `kaogu-citation-format`。
2. 说：「把这些注释改成《考古》2026 年起的注释体例。」
3. 重点核对四处易错点：中文专著的**出版地**、页码在**年份之后**、页码连接号用 **—**（不是 ～）、
   译著**不加 [英][美] 前缀**。

## 场景三：一批 PDF 转成 Markdown

1. 装 `mineru-pdf-to-markdown`，并准备好 MinerU 的访问方式（官方 API key 或本地 CLI）。
2. 目录约定：

   ```
   我的库/
     阅读文献/          # PDF 放这里
     阅读文献 markdown/ # 转换产物
   ```

3. 让 AI 逐篇提交解析、收齐结果，再运行导出脚本：

   ```powershell
   pwsh -File skills/mineru-pdf-to-markdown/scripts/mineru_export.ps1 `
     -PdfDir "我的库\阅读文献" -OutDir "我的库\阅读文献 markdown" -CacheRoot "<MinerU缓存目录>"
   ```

   脚本按 PDF 的 sha256 匹配缓存中的 `manifest.json`，导出 `full.md`，图片复制到 `assets/<PDF基名>/`，
   并把正文里的 `(images/` 改写成 `(assets/<PDF基名>/`，确保 Obsidian 能显示图。

## 场景四：写成八节精读笔记

1. 装 `literature-note-writer`，把 `assets/obsidian-template.md` 放进你的库根目录。
2. 让 AI 逐篇读 Markdown 后按模板写笔记，存放于 `笔记/`。
3. 校验：

   ```bash
   python skills/literature-note-writer/scripts/check_notes.py `
     --notes-dir "我的库/笔记" --status-tag "#待整理"
   ```

   无 Python 环境时用 PowerShell 版：

   ```powershell
   powershell -File skills/literature-note-writer/scripts/check_notes.ps1 `
     -NotesDir "我的库\笔记" -StatusTag "#待整理"
   ```

   `--status-tag` 要与你库里 `**阅读状态：**` 后面的标签值一致；不一致时 13 条会全被判失败。

   末行 `COUNT=n BAD=m`，`BAD` 必须为 0。校验不通过时脚本会逐条打印哪个字段不合规。

## 常见问题

**问：为什么笔记文件名不写作者和年份？**
答：双链以文件名寻址，文件名越短越稳定；作者年份在 YAML 属性里，Obsidian 可按属性检索。

**问：为什么第 8 节要求取自本文参考文献？**
答：从文献自己的引用里挑，延伸阅读才与本文论证同源；从库里别的 PDF 凑数，会把笔记变成书单。

**问：转换后数字全丢怎么办？**
答：用 `pdftotext -f <页> -l <页> -enc UTF-8` 抽原 PDF 的对应页核对。核不到就不要写数字，
在笔记里注明「原文该处数据在转换中丢失，须回溯原刊」。