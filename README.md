# archaeo-research-skills

面向中文考古学研究的 AI Agent 指令集：文献翻译规范、期刊注释体例、PDF 批量转 Markdown、文献精读笔记。

> **本仓库是「提示词 / 指令包」，不是软件。** 它由若干 `SKILL.md` 组成，需要宿主支持 skill 目录
> （Claude Code、DeepSeek Harness 或兼容实现）才会被 AI 读取。下载后不会自动运行，也不含可执行程序。

**English**: A collection of SKILL.md instruction packs for Chinese archaeology research — translation
conventions with a glossary, the citation style of the journal *Kaogu* (《考古》), batch PDF→Markdown
conversion via MinerU, and structured Obsidian reading notes. Prompt packs, not software.

---

## 包含什么

| Skill | 解决的问题 | 依赖 |
|---|---|---|
| [`archaeology-translation`](skills/archaeology-translation/SKILL.md) | 英译中时遗址名、器物名、术语怎么译；去翻译腔的行文规则；术语库 | 无（术语库为 Markdown） |
| [`kaogu-citation-format`](skills/kaogu-citation-format/SKILL.md) | 《考古》注释的著录格式：中文专著、期刊、译著、学位论文、古籍、外文、日文 | 无 |
| [`mineru-pdf-to-markdown`](skills/mineru-pdf-to-markdown/SKILL.md) | 一批 PDF 用 MinerU 转 Markdown，导出正文与图片并改写图片链接 | MinerU 访问方式（API / CLI / 宿主插件） |
| [`literature-note-writer`](skills/literature-note-writer/SKILL.md) | 按八节模板写精读笔记，校验结构、双链与引文格式 | Python 3（校验脚本） |

四者是**可独立安装**的：只做翻译，装第一个就够；只想校注释，装第二个就够。

## 安装

把需要的目录整个复制到宿主的 skills 目录：

```bash
# 例：只装翻译与引文格式
cp -r skills/archaeology-translation skills/kaogu-citation-format ~/.claude/skills/
```

DeepSeek Harness 的 skills 目录为 `~/.dsh/skills/`（Windows 下 `C:\Users\<用户名>\.dsh\skills\`）。
Claude Code 为 `~/.claude/skills/`。具体以宿主文档为准——不同宿主的目录名与加载机制不完全一致，
本仓库只提供 `SKILL.md` 这一约定格式。

## 快速上手

见 [`docs/quickstart.md`](docs/quickstart.md)。最省事的验证方式：装好 `kaogu-citation-format` 后，
让 AI 把一条 GB/T 7714 格式的文献条目改成《考古》体例，看输出是否符合
`作者：《篇名》，《刊名》年份年第X期。`。

## 使用前请知道的边界

1. **《考古》体例是归纳结果，不是官方文件。** `kaogu-citation-format` 的规则由 2012—2026 年该刊
   已发表文章的注释归纳而成。期刊编辑部可能另有未公开的细则，投稿前请以刊物官方征稿要求为准。
   本仓库不声称代表《考古》编辑部。
2. **术语译法有分歧。** 术语库中标「学界通行」的条目依据中文学界的常用译法；标「约定」的条目是
   特定译者的选择。二者都需使用者按自己面对的文本再判断，不作为强制标准。
3. **转换质量取决于 MinerU。** 中文排版 PDF 常出现数字整体丢失（年份、页码、表内数值）。
   本仓库的规则要求「缺数据就写明缺失，禁止编造」，不保证转换结果可直接引用。
4. **笔记模板面向 Obsidian。** 八节结构、双链、YAML 属性按 Obsidian 的解析规则设计，
   在纯 Markdown 阅读器中可读但双链不会跳转。

## 目录

```
skills/
  archaeology-translation/     # 翻译规范 + 术语库
    SKILL.md
    references/glossary.md
  kaogu-citation-format/       # 《考古》注释体例
    SKILL.md
  mineru-pdf-to-markdown/      # PDF → Markdown
    SKILL.md
    scripts/mineru_export.ps1
  literature-note-writer/      # 八节精读笔记
    SKILL.md
    scripts/check_notes.py     # 校验（Python 3，仅标准库）
    scripts/check_notes.ps1    # 校验（PowerShell 版，无 Python 环境用）
    assets/obsidian-template.md
    examples/河湾遗址新石器时代早中期聚落形态的初步分析.md
docs/quickstart.md
```

## 四个 skill 如何串起来

```
PDF ──mineru-pdf-to-markdown──> Markdown ──literature-note-writer──> 精读笔记
                                            │
               archaeology-translation ─────┘（外文文献先译）
               kaogu-citation-format ───────┘（笔记里的引文与来源）
```

四步都可单独使用，串起来才是完整的「文献入库」流程。

## 贡献

术语补充、体例修正、边界情况都欢迎提 Issue。提交术语请附**依据**（哪本工具书、哪篇论文、
哪家机构的译名表），只给结论的条目会被标为「待核实」。参见 [CONTRIBUTING](CONTRIBUTING.md)。

## 许可

- `scripts/` 下的代码：[MIT](LICENSE)
- 其余文字（`SKILL.md`、`references/`、`assets/`、`docs/`）：[CC BY 4.0](LICENSE-CC-BY-4.0.md)

## 致谢与出处

本仓库内容来自作者在中文考古学文献整理中的实际使用与修订，部分规则在真实项目中反复校正
（如「引用格式必须区分中文期刊与外文期刊」「期次要以原刊页眉为准而非文件名年份」）。
示例笔记为虚构文献，遗址、作者、刊名均为占位值，只用于展示笔记应达到的结构与详略。

---

作者：zyliu9921 · 仓库：https://github.com/zyliu9921/archaeo-research-skills