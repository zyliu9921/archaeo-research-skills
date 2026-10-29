# 验收：怎么确认它在你机器上真的能用

这份文档是**可复现的验收流程**，不是功能说明。功能见 [quickstart](quickstart.md)，规范见各 `SKILL.md`。

它要回答四个问题：

1. 脚本在你机器上跑得起来吗？（环境问题）
2. 校验器是真的在检查，还是永远返回 OK？（工具可信度）
3. AI 只看这份规范，能写出结构合格的笔记吗？（规范可执行性）
4. 笔记内容对不对得上原文？（内容真实性）

前三个可以自动化或半自动化，第四个必须人工抽样。

---

## 判定标准

五项全过才算「可用」。任何一项失败，先查下面的失败对照表，再判断是环境问题还是规范问题。

| # | 检查项 | 通过标准 |
|---|---|---|
| 1 | 凭据探测脚本 | 能跑到底并给出 `VERDICT:` 行（`usable` 或 `no-path` 都算通过，崩了算失败） |
| 2 | 校验器正向 | `examples/` 输出 `COUNT=1 BAD=0`，末行退出码 0 |
| 3 | 校验器反向 | `tests/fixtures/` 输出 `COUNT=1 BAD=1` 并列出 8 个失败项，退出码 1 |
| 4 | 端到端 | 一篇真论文写出的笔记，校验输出 `COUNT=1 BAD=0` |
| 5 | 内容抽样 | 下面「步骤 4」的 6 条全过 |

第 2、3 项必须**同时**满足。只有正向通过，说明不了校验器有效——一个永远返回 OK 的脚本也能通过正向测试。

---

## 步骤 0：在干净目录里装

不要在原仓库里测，否则你测的是自己已经改过的版本。

```bash
# macOS / Linux
mkdir -p /tmp/verify && cd /tmp/verify
git clone https://github.com/zyliu9921/archaeo-research-skills.git
cd archaeo-research-skills
```

```powershell
# Windows PowerShell
$v = "$env:TEMP\verify"; New-Item -ItemType Directory -Force $v | Out-Null
Set-Location $v
git clone https://github.com/zyliu9921/archaeo-research-skills.git
Set-Location archaeo-research-skills
```

---

## 步骤 1：凭据探测

转换 PDF 需要 MinerU。**先确认有没有可用的访问方式，再动手**——不要等转换失败才回头查。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File skills/mineru-pdf-to-markdown/scripts/check_env.ps1
```

```bash
bash skills/mineru-pdf-to-markdown/scripts/check_env.sh
```

看最后一行：

- `VERDICT: usable` —— 有可用访问方式，继续。脚本只回显长度，不回显密钥本身。
- `VERDICT: no-path` —— 三条路都没有：宿主插件、`MINERU_API_KEY` 环境变量、本地服务端口。此时**停下来配**，不要硬跑。
- 脚本崩溃 / 报语法错 —— 环境问题，记下来，不影响后面几步的结构校验（那几步不需要 MinerU）。

配置方式（三选一，详见 `skills/mineru-pdf-to-markdown/SKILL.md`「凭据放在哪里」）：

```powershell
setx MINERU_API_KEY "你的token"   # 之后要重开终端
```

密钥只写进你自己的环境变量或凭据库，不要写进笔记、不要贴进对话。

---

## 步骤 2：校验器自检（双向）

这是整个验收里最关键的一步，因为后面所有「通过」都建立在校验器可信之上。

### 2a 正向：合格示例必须通过

```powershell
python skills/literature-note-writer/scripts/check_notes.py --notes-dir skills/literature-note-writer/examples
```

```powershell
# 没有 Python 时用 PowerShell 版，参数等价
powershell -NoProfile -ExecutionPolicy Bypass -File skills/literature-note-writer/scripts/check_notes.ps1 -NotesDir skills/literature-note-writer/examples
```

期望：

```
河湾遗址新石器时代早中期聚落形态的初步分析.md        OK
COUNT=1 BAD=0
```

### 2b 反向：故意写坏的样本必须报错

`skills/literature-note-writer/tests/fixtures/故意写坏的测试笔记.md` 是专门造的坏样本，里面埋了 8 个坑：`type: literature`、只有 4 节、`sitation` 没加引号、来源没书名号、延伸阅读条目没有选读原因、链到不存在的笔记、残留 `<% %>` 占位符、状态写成 `#已整理`。

```powershell
python skills/literature-note-writer/scripts/check_notes.py --notes-dir skills/literature-note-writer/tests/fixtures --status-tag "#待整理"
```

期望（失败项可能因你的修改略有出入，但必须是失败）：

```
故意写坏的测试笔记.md    FAIL typeOk,readOk,sitQuoted,srcKaogu,sections,badLinks,extFmt,placeholders
COUNT=1 BAD=1
```

**如果它输出 OK，停下来**：校验器坏了，后面所有绿灯都不可信。

### 2c 两个版本一致（可选，但推荐）

同一份坏样本，Python 版和 PowerShell 版必须报出**同一组**失败项。不一致说明两版规则有分叉。

### 关于 `--status-tag`

校验器默认要求结尾是 `**阅读状态：** #待整理`。如果你已有的笔记库用的是别的标签（例如 `#阅读情况：待整理`），用参数传入：

```powershell
python .../check_notes.py --notes-dir 笔记 --status-tag "#阅读情况：待整理"
```

---

## 步骤 3：端到端跑一篇

选一篇你自己领域的中文期刊论文 PDF，走完整链路：

1. 转 Markdown（`skills/mineru-pdf-to-markdown/SKILL.md`）
2. 写笔记（`skills/literature-note-writer/SKILL.md`）
3. 校验（在**仓库根目录**执行）：

```powershell
python skills/literature-note-writer/scripts/check_notes.py --notes-dir "你的笔记目录"
```

这行命令由四段组成，缺一不可：

| 片段 | 含义 | 能不能改 |
|---|---|---|
| `python` | 用哪个解释器跑脚本 | 能。没有 Python 就换成下面的 PowerShell 版 |
| `skills/literature-note-writer/scripts/check_notes.py` | 脚本文件的位置，相对于仓库根目录 | 能，改成你实际存放的绝对路径 |
| `--notes-dir` | 参数名：告诉脚本「要检查哪个文件夹」 | 不能，名字写死 |
| `"你的笔记目录"` | 参数值，**这是占位符，必须换成你机器上的真实路径** | 必须改 |

`<你的笔记目录>` 这种尖括号写法是文档里的通用占位符，**不要照抄**，直接把整段（含尖括号）替换成路径，路径带空格时加引号。

三种真实写法：

```powershell
# 笔记和仓库在同一层目录
python skills/literature-note-writer/scripts/check_notes.py --notes-dir "../笔记"

# 笔记本体在别的盘（Windows 反斜杠，整条路径加引号）
python skills/literature-note-writer/scripts/check_notes.py --notes-dir "E:\硕士论文\obsidian笔记\笔记"

# 用绝对路径指向任意位置
python C:\tools\archaeo-research-skills\skills\literature-note-writer\scripts\check_notes.py --notes-dir "D:\vault\笔记"
```

没有可用的 Python 时（Windows 上 `python` 常是 Microsoft Store 的占位程序，跑了静默退出、什么都不输出），换 PowerShell 版，参数一一对应：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File skills/literature-note-writer/scripts/check_notes.ps1 -NotesDir "你的笔记目录"
```

期望 `COUNT=1 BAD=0`。

失败时看输出里的字段名，对照失败表定位。**不要为了让校验通过而删内容**——校验器管的是结构，删内容只会让笔记更差。

---

## 步骤 4：内容抽样（人工，不可省）

校验器只保证结构合规，**不保证内容正确**。它能查「有没有 8 节」「引文格式对不对」，查不出「这段摘录是否被篡改」「这个页码是不是真的」。

抽 6 条，一条不过就回去查全篇：

| # | 抽什么 | 怎么核 |
|---|---|---|
| 1 | 任意 2 条「重要摘录」 | 回 PDF 里搜原文，必须**逐字命中**（标点也要对） |
| 2 | 任意 2 个正文数字 | 回原刊核（比例、件数、测年值最容易在转换中丢） |
| 3 | `sitation` 的刊名/年份/期次 | 看 PDF 首页页眉，以页眉为准，不以文件名或 Zotero 元数据为准 |
| 4 | 至少 1 个标注的页码 | 确认「印刷页码 = PDF 页码」的偏移量算对了（常有关页无页码的情况） |
| 5 | 第 2、3 节 | **是否整段抄了摘要**。这两节应当是提炼概括，不是照搬；校验器不检查这一项 |
| 6 | 第 8 节三条延伸阅读 | 是否真出自本文参考文献；撞库里已有笔记时才该有双链，没有双链属正常 |

第 5 条是实测中最容易被误读的地方：规范强调「摘录必须逐字」，容易被顺势理解成第 3 节也照抄原文，而作者摘要一段往往就超过「1—3 句」。**判据：第 2、3 节出现连续 3 句以上的原文，就是抄录，不是概括。**

如果你对某条摘录的页码没把握，正确的做法是写「所在章节：3.2」这类可回溯的定位，**不要填一个看起来合理的页码**。

---

## 步骤 5：记录

把结论贴到 issue 或自己的备忘里，方便下次环境变动后比对：

```text
验收日期：YYYY-MM-DD
仓库版本：git rev-parse --short HEAD 的结果
系统 / 语言：
[1] check_env        : usable / no-path
[2] 校验器正向       : COUNT=1 BAD=0
[3] 校验器反向       : COUNT=1 BAD=1，失败项 8 个
[4] 端到端           : COUNT=1 BAD=0
[5] 内容抽样         : 6/6 通过 / 第 N 条未过（原因）
结论：可用 / 部分可用 / 不可用
```

---

## 失败对照表

| 现象 | 多半是 | 怎么办 |
|---|---|---|
| `python` 无输出、静默退出 1 | Windows 的 Microsoft Store 存根，不是真解释器 | 用 `py -3` 或装真 Python；或改用 `check_notes.ps1` |
| `ModuleNotFoundError: yaml` | 误以为需要 PyYAML | 不需要，脚本手写了解析，检查是不是跑错了文件 |
| 中文显示成乱码 | 控制台编码（GBK）问题，不是文件坏了 | `chcp 65001` 或 `[Console]::OutputEncoding=[Text.Encoding]::UTF8`；用编辑器确认文件本身 |
| `.ps1` 报「字符串缺少终止符」/ 中文路径乱码 | 脚本被按 GBK 读取 | 脚本必须以 **UTF-8 带 BOM** 保存 |
| `git` 报 `dubious ownership` | 盘符不记录文件属主（常见于外挂盘） | `git config --global --add safe.directory "<仓库绝对路径>"`，路径用正斜杠、不带尾部斜杠 |
| `Recv failure: Connection was reset` | 网络层拦截 | 配代理：`git config --global http.https://github.com.proxy http://127.0.0.1:<端口>` |
| 转换成功但笔记里数字全丢 | PDF 排版导致数字被丢弃 | 用 `pdftotext` 回原文补，别猜 |
| 校验报 `sections` 少一节 | 第 8 节后直接跟 `---`，被 Markdown 当成 setext 标题吞了 | `---` 前留一个空行 |

---

## 这套验收不覆盖什么

- **不判断笔记写得好不好**。结构对、事实可核，不等于分析有洞见。第 5 条抽样只防「错」，不保证「好」。
- **不覆盖英文/日文文献**的题录细节，那些要对着 `kaogu-citation-format` 单独核。
- **不覆盖 MinerU 的解析质量**。转换本身丢内容（尤其是数字、表格、竖排）是已知限制，只能靠抽样发现。
- **不替代投稿前的格式终审**。《考古》体例是归纳结果，不是编辑部官方文件，最终以刊物要求为准。