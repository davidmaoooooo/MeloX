#!/usr/bin/env python3

"""Parse the platform sections in MeloX's release notes."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys


PLATFORM_HEADINGS = {
    "ios": "iOS + Apple Watch",
    "macos": "macOS",
}
DOCUMENT_TITLE = "MeloX 更新日志"
HEADING_PATTERN = re.compile(r"^(?P<level>#{1,6})\s+(?P<title>.+?)\s*$")


def parse_release_notes(path: Path) -> dict[str, list[str]]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise ValueError(f"无法读取更新日志 {path}：{error}") from error

    sections = {platform: [] for platform in PLATFORM_HEADINGS}
    expected_platform_by_heading = {
        heading: platform for platform, heading in PLATFORM_HEADINGS.items()
    }
    seen_platforms: set[str] = set()
    current_platform: str | None = None
    saw_title = False

    for line_number, line in enumerate(lines, start=1):
        stripped_line = line.strip()
        if not stripped_line:
            continue

        heading_match = HEADING_PATTERN.fullmatch(stripped_line)
        if heading_match:
            level = len(heading_match.group("level"))
            heading = heading_match.group("title")
            if level == 1 and heading == DOCUMENT_TITLE and not saw_title:
                saw_title = True
                current_platform = None
                continue
            if level == 2 and heading in expected_platform_by_heading:
                platform = expected_platform_by_heading[heading]
                if platform in seen_platforms:
                    raise ValueError(f"更新日志第 {line_number} 行重复定义 {heading}")
                seen_platforms.add(platform)
                current_platform = platform
                continue
            raise ValueError(
                f"更新日志第 {line_number} 行包含未知标题：{stripped_line}"
            )

        if not saw_title:
            raise ValueError(f"更新日志必须以 # {DOCUMENT_TITLE} 开头")
        if current_platform is None:
            raise ValueError(
                f"更新日志第 {line_number} 行不属于任何平台区块"
            )
        if not stripped_line.startswith("- ") or not stripped_line[2:].strip():
            raise ValueError(
                f"更新日志第 {line_number} 行必须是单条 Markdown 列表项"
            )
        sections[current_platform].append(stripped_line)

    if not saw_title:
        raise ValueError(f"更新日志必须以 # {DOCUMENT_TITLE} 开头")

    missing_headings = [
        heading
        for platform, heading in PLATFORM_HEADINGS.items()
        if platform not in seen_platforms
    ]
    if missing_headings:
        raise ValueError(f"更新日志缺少平台区块：{', '.join(missing_headings)}")
    if not any(sections.values()):
        raise ValueError("iOS + Apple Watch 与 macOS 更新日志不能同时为空")

    return sections


def write_platform_notes(
    entries: list[str],
    output: Path,
    *,
    allow_empty: bool = False,
) -> None:
    if not entries and not allow_empty:
        raise ValueError("不能为没有更新内容的平台生成更新日志")
    output.parent.mkdir(parents=True, exist_ok=True)
    markdown = "\n".join(entries)
    output.write_text(f"{markdown}\n" if markdown else "", encoding="utf-8")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--notes", required=True, type=Path)
    parser.add_argument("--platform", choices=PLATFORM_HEADINGS)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--github-output", type=Path)
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    if (arguments.platform is None) != (arguments.output is None):
        print("--platform 与 --output 必须一起使用", file=sys.stderr)
        return 2
    if arguments.output is None and arguments.github_output is None:
        print("必须提供 --output 或 --github-output", file=sys.stderr)
        return 2

    try:
        sections = parse_release_notes(arguments.notes)
        if arguments.platform is not None:
            write_platform_notes(
                sections[arguments.platform],
                arguments.output,
            )
        if arguments.github_output is not None:
            targets = [platform for platform, entries in sections.items() if entries]
            with arguments.github_output.open("a", encoding="utf-8") as output:
                output.write(f"platforms={json.dumps(targets, separators=(',', ':'))}\n")
                for platform in PLATFORM_HEADINGS:
                    output.write(
                        f"has_{platform}={'true' if sections[platform] else 'false'}\n"
                    )
    except ValueError as error:
        print(f"解析更新日志失败：{error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
