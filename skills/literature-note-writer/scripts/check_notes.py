#!/usr/bin/env python3
"""结构校验：一批 Obsidian 文献笔记是否符合八节模板约定。

只做机械检查，不判断内容质量。仅依赖标准库（不需要 PyYAML）。

用法:
    python check_notes.py --notes-dir "我的库/笔记"
    python check_notes.py --notes-dir "我的库/笔记" --status-tag "#阅读情况：待整理"
    python check_notes.py --notes-dir "我的库/笔记" --json-out check.json

退出码: 0 全部通过；1 有不合规项；2 参数或路径错误。
"""

import argparse
import json
import os
import re
import sys

REQUIRED_KEYS = ["title", "author", "year", "type", "tags", "sitation"]
DEFAULT_TYPES = ["期刊论文", "辑刊论文", "田野报告", "专著", "学位论文"]
SECTION_RE = re.compile(r"^##\s*([1-8])\.\s*\S", re.M)
WIKILINK_RE = re.compile(r"\[\[([^\]\|#]+)(?:[#\|][^\]]*)?\]\]")
EXT_RE = re.compile(r"^- .*（选读原因：.+）\r?$", re.M)
BAD_CHARS = '\\/:*?"<>|'
# 《考古》体例：期刊论文 / 专著 / 学位论文三种终止形态
SIT_RE = re.compile(
    r"^.+：《.+?》，.*"
    r"(《.+》\d{4}年第\d+期。"
    r"|，\d{4}年，第\d+页。"
    r"|，[博士硕士]学位论文，.+，\d{4}年。)$")


def read_text(path):
    with open(path, "r", encoding="utf-8-sig") as fh:
        return fh.read()


def parse_frontmatter(text):
    """返回 (dict, 错误列表)。手写解析，避免 PyYAML 依赖。"""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}, ["缺少 frontmatter 起始 ---"]
    end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end = i
            break
    if end is None:
        return {}, ["frontmatter 未闭合"]
    data, errors, current_key = {}, [], None
    for raw in lines[1:end]:
        if not raw.strip():
            continue
        if raw.lstrip().startswith("- ") and current_key:
            data.setdefault(current_key, [])
            if isinstance(data[current_key], list):
                data[current_key].append(raw.strip()[2:].strip())
            continue
        m = re.match(r"^([A-Za-z0-9_\-]+):\s*(.*)$", raw)
        if not m:
            errors.append("无法解析的 frontmatter 行: " + raw.strip())
            continue
        key, value = m.group(1), m.group(2).strip()
        current_key = key
        if value == "":
            data[key] = []
        else:
            quoted = (value.startswith('"') and value.endswith('"')) or (
                value.startswith("'") and value.endswith("'")
            )
            data[key] = value
            if not quoted and re.search(r":\s", value):
                errors.append("标量含 ': ' 未加引号，Obsidian 属性可能解析失败: " + key)
    return data, errors


def check_one(path, notes_dir, type_set, status_tag):
    text = read_text(path)
    stem = os.path.splitext(os.path.basename(path))[0]
    r = {"file": os.path.basename(path), "yaml": False, "h1": False, "sections": 0,
         "links": 0, "badLinks": [], "fileNameOk": False, "titleOk": False,
         "typeOk": False, "readOk": False, "sitQuoted": False, "sitKaogu": False,
         "srcKaogu": False, "extFmt": 0, "placeholders": 0, "errors": []}

    fm, fm_errors = parse_frontmatter(text)
    r["errors"].extend(fm_errors)
    missing = [k for k in REQUIRED_KEYS if k not in fm or fm[k] in ("", [], None)]
    if missing:
        r["errors"].append("缺少必备键: " + ", ".join(missing))
    r["yaml"] = not fm_errors and not missing

    title = fm.get("title")
    title = title.strip('"').strip("'") if isinstance(title, str) else ""

    h1s = re.findall(r"^# (?!#)(.+?)\r?$", text, re.M)
    r["h1"] = len(h1s) == 1
    if not r["h1"]:
        r["errors"].append("H1 数量为 %d（应为 1）" % len(h1s))

    r["sections"] = len(set(SECTION_RE.findall(text)))
    if r["sections"] != 8:
        r["errors"].append("八节命中 %d 节" % r["sections"])

    known = {os.path.splitext(os.path.basename(p))[0] for p in
             [os.path.join(notes_dir, f) for f in os.listdir(notes_dir) if f.endswith(".md")]}
    targets = WIKILINK_RE.findall(text)
    r["links"] = len(targets)
    r["badLinks"] = sorted({t.strip() for t in targets if t.strip() not in known})

    r["fileNameOk"] = stem == title and not any(ch in stem for ch in BAD_CHARS)
    r["titleOk"] = bool(title) and r["h1"] and h1s[0].strip() == title and r["fileNameOk"]
    if not r["fileNameOk"]:
        r["errors"].append("文件名与 title 不一致，或含非法字符")

    r["typeOk"] = fm.get("type") in type_set
    if not r["typeOk"]:
        r["errors"].append("type 不在五类之内: %r" % (fm.get("type"),))

    read_line = re.search(r"^\*\*阅读状态：\*\*\s*(\S+)\s*\r?$", text, re.M)
    r["readOk"] = bool(read_line) and read_line.group(1) == status_tag
    if not r["readOk"]:
        r["errors"].append("结尾阅读状态应写作 **阅读状态：** " + status_tag)

    raw_sit = None
    for line in text.splitlines():
        if line.startswith("sitation:"):
            raw_sit = line[len("sitation:"):].strip()
            break
    r["sitQuoted"] = bool(raw_sit) and raw_sit.startswith('"') and raw_sit.endswith('"')
    body_sit = raw_sit.strip('"') if raw_sit else ""
    r["sitKaogu"] = bool(SIT_RE.match(body_sit))
    if not r["sitKaogu"]:
        r["errors"].append("sitation 不是「作者：《篇名》，《刊名》年份年第X期。」形式")

    src_line = re.search(r"^- \*\*来源：\*\*.*$", text, re.M)
    r["srcKaogu"] = bool(src_line) and "《" in src_line.group(0) and "》" in src_line.group(0)

    ext_lines = [l for l in EXT_RE.findall(text) if ("《" in l and "》" in l) or "*" in l]
    r["extFmt"] = len(ext_lines)
    if r["extFmt"] != 3:
        r["errors"].append("延伸阅读符合格式的条目为 %d 条（应为 3）" % r["extFmt"])

    r["placeholders"] = len(re.findall(r"<%|%>|TODO|待填", text))
    if r["placeholders"]:
        r["errors"].append("残留占位符 %d 处" % r["placeholders"])
    return r


def main(argv=None):
    ap = argparse.ArgumentParser(description="校验 Obsidian 文献笔记是否符合八节模板约定")
    ap.add_argument("--notes-dir", default="笔记", help="笔记目录（默认 笔记）")
    ap.add_argument("--status-tag", default="#待整理", help="结尾阅读状态的标签值（默认 #待整理）")
    ap.add_argument("--types", default=",".join(DEFAULT_TYPES), help="允许的 type 取值，逗号分隔")
    ap.add_argument("--json-out", default="", help="把明细写入该 JSON 文件")
    args = ap.parse_args(argv)

    if not os.path.isdir(args.notes_dir):
        print("错误：目录不存在 %s" % args.notes_dir)
        return 2
    type_set = {t.strip() for t in args.types.split(",") if t.strip()}
    files = sorted(f for f in os.listdir(args.notes_dir) if f.endswith(".md")
                   and not f.startswith("obsidian模板"))
    if not files:
        print("错误：%s 下没有 .md 文件" % args.notes_dir)
        return 2

    rows, bad = [], 0
    for name in files:
        r = check_one(os.path.join(args.notes_dir, name), args.notes_dir, type_set, args.status_tag)
        flags = [k for k in ("yaml", "h1", "fileNameOk", "titleOk", "typeOk", "readOk",
                             "sitQuoted", "sitKaogu", "srcKaogu") if not r[k]]
        if r["sections"] != 8:
            flags.append("sections")
        if r["badLinks"]:
            flags.append("badLinks")
        if r["extFmt"] != 3:
            flags.append("extFmt")
        if r["placeholders"]:
            flags.append("placeholders")
        if flags:
            bad += 1
        r["failed"] = flags
        rows.append(r)
        print("%-46s %s" % (r["file"][:44], "OK" if not flags else "FAIL " + ",".join(flags)))

    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as fh:
            json.dump(rows, fh, ensure_ascii=False, indent=2)
    print("COUNT=%d BAD=%d" % (len(rows), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())