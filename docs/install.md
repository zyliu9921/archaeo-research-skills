# 安装：把 skill 装进你自己的 agent

本仓库不发布到任何包管理器（没有 npm / pip 包），四个 skill 就是四个普通目录，**复制到宿主的 skills 目录即可生效**。

装好后的第一件事不是跑转换，而是按 [verify.md](verify.md) 的五步验收确认它在你机器上真的能用。

---

## 先选：你要装哪几个

| skill | 解决什么 | 依赖 |
|---|---|---|
| `archaeology-translation` | 考古/学术文献翻译，术语与遗址名定名 | 无 |
| `kaogu-citation-format` | 《考古》期刊注释体例 | 无 |
| `mineru-pdf-to-markdown` | 批量 PDF → Markdown | MinerU 访问方式（插件 / API key / 本地服务）+ `pdftotext` |
| `literature-note-writer` | 八节精读笔记 + 结构校验 | Python 3.8+ 或 PowerShell（校验脚本二选一） |

只做翻译就只装第一个，四个之间没有互相调用。

---

## 方法一：git clone（推荐，能更新）

```bash
# macOS / Linux
git clone https://github.com/zyliu9921/archaeo-research-skills.git ~/archaeo-research-skills
cp -r ~/archaeo-research-skills/skills/archaeology-translation ~/.claude/skills/
cp -r ~/archaeo-research-skills/skills/kaogu-citation-format ~/.claude/skills/
```

```powershell
# Windows PowerShell
git clone https://github.com/zyliu9921/archaeo-research-skills.git "$env:USERPROFILE\archaeo-research-skills"
New-Item -ItemType Directory -Force "$env:USERPROFILE\.dsh\skills" | Out-Null
Copy-Item -Recurse -Force "$env:USERPROFILE\archaeo-research-skills\skills\archaeology-translation" "$env:USERPROFILE\.dsh\skills\"
Copy-Item -Recurse -Force "$env:USERPROFILE\archaeo-research-skills\skills\kaogu-citation-format" "$env:USERPROFILE\.dsh\skills\"
```

四个都要就把两行 `Copy-Item` 换成通配：

```powershell
Copy-Item -Recurse -Force "$env:USERPROFILE\archaeo-research-skills\skills\*" "$env:USERPROFILE\.dsh\skills\"
```

```bash
cp -r ~/archaeo-research-skills/skills/* ~/.claude/skills/
```

### 想跟着仓库更新，用软链接代替复制

复制之后每次更新都要重来一遍。软链接指向仓库目录，`git pull` 之后立即生效：

```bash
# macOS / Linux
ln -s ~/archaeo-research-skills/skills/archaeology-translation ~/.claude/skills/archaeology-translation
```

```powershell
# Windows：普通用户用目录联接（junction），不需要管理员权限
# 注意 /J 是目录联接，不是符号链接；/D 需要开发者模式或管理员
cmd /c mklink /J "%USERPROFILE%\.dsh\skills\archaeology-translation" "%USERPROFILE%\archaeo-research-skills\skills\archaeology-translation"
```

代价：链接指向的仓库目录被你删了、移动了，skill 就失效，且不会有提示。

---

## 方法二：下载 ZIP（不想装 git）

1. 打开 https://github.com/zyliu9921/archaeo-research-skills
2. 绿色 **Code** 按钮 → **Download ZIP**
3. 解压，把 `skills/` 下你需要的子目录复制到宿主的 skills 目录（同方法一的目标路径）

代价：没有版本历史，更新要重新下一次。

---

## 装到哪个目录

不同宿主的目录约定不一样，**目录名以宿主文档为准**，本仓库只约定 `SKILL.md` 这个格式。

| 宿主 | 用户级目录 | 项目级目录 |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `<项目>/.claude/skills/` |
| DeepSeek Harness | `~/.dsh/skills/`（Windows：`C:\Users\<用户名>\.dsh\skills\`） | 视宿主配置 |
| 其他支持 `SKILL.md` 的宿主 | 见宿主文档 | 见宿主文档 |

两条硬规则：

1. **目录名必须等于 `SKILL.md` 里 `name` 字段的值**。`skills/archaeology-translation/SKILL.md` 里写的是 `name: archaeology-translation`，装成 `考古翻译/` 就加载不到。
2. **`description` 决定会不会被触发**。它是宿主做语义匹配的唯一依据，改 description 等于改触发范围。

`references/`、`scripts/`、`assets/` 子目录要一起复制——`SKILL.md` 里按相对路径引用它们。

---

## 装完怎么确认

### 1. 宿主认不认

重启宿主或在会话里问一句：

```text
你现在能用到哪些 skill？
```

回答里出现 `archaeology-translation` 等名字，就说明加载成功。没出现，先查目录名与 `name` 是否一致。

### 2. 触发词灵不灵

用真实任务试，而不是问「你会翻译吗」：

```text
把这段英文翻译成中文：household archaeology 关注的是家户层面的活动……
```

预期：agent 主动加载 `archaeology-translation`，查术语库后给出「家户考古」而不是「家庭考古」。

### 3. 脚本能不能跑

```powershell
python ~/.dsh/skills/literature-note-writer/scripts/check_notes.py --notes-dir <你的笔记目录>
```

或 PowerShell 版（Windows 上 `python` 常是 Microsoft Store 占位程序）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.dsh\skills\literature-note-writer\scripts\check_notes.ps1" -NotesDir "<你的笔记目录>"
```

报 `ModuleNotFoundError: yaml` 说明跑错了脚本——本仓库的校验脚本**只用标准库**，不需要 PyYAML。

### 4. 完整验收

装完先按 [verify.md](verify.md) 走一遍，尤其是「校验器反向测试」：合格示例必须通过，坏样本必须被判失败。两者同时成立，才说明工具可信。

---

## 更新与卸载

```bash
# 更新（用 clone 或软链接的）
cd ~/archaeo-research-skills && git pull
# 软链接的到此结束；复制安装的还要再 cp 一次

# 卸载
rm -rf ~/.claude/skills/archaeology-translation
```

```powershell
# Windows 卸载（软链接用 Remove-Item 会连带删仓库内容，先删链接本身）
Remove-Item "$env:USERPROFILE\.dsh\skills\archaeology-translation" -Recurse -Force
```

用 junction 装的，删链接不会删仓库目录；但混合操作容易搞混，卸载前先确认目标是链接还是实体目录。

---

## 环境前提

| 需要 | 用于 | 检查方式 |
|---|---|---|
| MinerU 访问方式 | 只有 `mineru-pdf-to-markdown` 需要 | `powershell -File skills/mineru-pdf-to-markdown/scripts/check_env.ps1` |
| `pdftotext`（poppler） | 回原文核对数字、页码 | `pdftotext -v` |
| Python 3.8+ | 校验脚本（可选） | `py -3 --version` |
| Obsidian | 笔记模板的双链、YAML 属性 | 打开 vault 看双链是否可跳 |
| PowerShell 5.1+ | Windows 下的脚本 | `$PSVersionTable.PSVersion` |

`archaeology-translation` 与 `kaogu-citation-format` 两个纯文字 skill **零依赖**，任何宿主都能装。