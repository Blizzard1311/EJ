#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
PROJECT_YML = REPO_ROOT / "project.yml"
PBXPROJ = REPO_ROOT / "Yiji.xcodeproj" / "project.pbxproj"
APP_BUNDLE_ID = "com.blizzard1311.yiji"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


def parse_project_yml_build(text: str) -> tuple[int, str]:
    in_yiji_target = False
    for line in text.splitlines():
        if line.startswith("  YijiApp:"):
            in_yiji_target = True
            continue
        if in_yiji_target and re.match(r"^  [A-Za-z0-9_]+:\s*$", line):
            in_yiji_target = False
        if in_yiji_target:
            match = re.match(r'^        CURRENT_PROJECT_VERSION: "(\d+)"\s*$', line)
            if match:
                return int(match.group(1)), match.group(0)
    raise RuntimeError("Failed to find YijiApp CURRENT_PROJECT_VERSION in project.yml")


def update_project_yml(text: str, new_build: int) -> tuple[str, int]:
    lines = text.splitlines(keepends=True)
    in_yiji_target = False
    replaced = 0

    for index, line in enumerate(lines):
        if line.startswith("  YijiApp:"):
            in_yiji_target = True
            continue
        if in_yiji_target and re.match(r"^  [A-Za-z0-9_]+:\s*$", line):
            in_yiji_target = False
        if in_yiji_target and re.match(r'^        CURRENT_PROJECT_VERSION: "\d+"\s*$', line):
            line_ending = "\n" if line.endswith("\n") else ""
            lines[index] = f'        CURRENT_PROJECT_VERSION: "{new_build}"{line_ending}'
            replaced += 1
            break

    if replaced != 1:
        raise RuntimeError("Failed to update YijiApp CURRENT_PROJECT_VERSION in project.yml")

    return "".join(lines), replaced


def split_xcconfig_blocks(text: str) -> list[str]:
    blocks: list[str] = []
    current: list[str] = []
    inside_xcbuild_section = False

    for line in text.splitlines(keepends=True):
        if "/* Begin XCBuildConfiguration section */" in line:
            inside_xcbuild_section = True
        if inside_xcbuild_section:
            current.append(line)
            if line.strip() == "};":
                blocks.append("".join(current))
                current = []
        if "/* End XCBuildConfiguration section */" in line:
            inside_xcbuild_section = False

    return blocks


def parse_pbxproj_builds(text: str) -> list[int]:
    builds: list[int] = []
    for block in split_xcconfig_blocks(text):
        if f"PRODUCT_BUNDLE_IDENTIFIER = {APP_BUNDLE_ID};" not in block:
            continue
        match = re.search(r"CURRENT_PROJECT_VERSION = (\d+);", block)
        if match:
            builds.append(int(match.group(1)))
    if not builds:
        raise RuntimeError("Failed to find YijiApp CURRENT_PROJECT_VERSION in project.pbxproj")
    return builds


def update_pbxproj(text: str, new_build: int) -> tuple[str, int]:
    pattern = re.compile(
        rf"(?P<block>\n\t\t[0-9A-F]+.*?PRODUCT_BUNDLE_IDENTIFIER = {re.escape(APP_BUNDLE_ID)};.*?\n\t\t\t\}};)",
        re.S,
    )

    replaced_blocks = 0

    def replace_block(match: re.Match[str]) -> str:
        nonlocal replaced_blocks
        block = match.group("block")
        updated_block, count = re.subn(
            r"CURRENT_PROJECT_VERSION = \d+;",
            f"CURRENT_PROJECT_VERSION = {new_build};",
            block,
            count=1,
        )
        if count != 1:
            raise RuntimeError("Failed to replace CURRENT_PROJECT_VERSION inside YijiApp build block")
        replaced_blocks += 1
        return updated_block

    updated_text = pattern.sub(replace_block, text)

    if replaced_blocks != 2:
        raise RuntimeError(
            f"Expected to update 2 YijiApp build configurations in project.pbxproj, updated {replaced_blocks}"
        )

    return updated_text, replaced_blocks


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Increment YijiApp build number before archiving."
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write changes back to project.yml and project.pbxproj.",
    )
    args = parser.parse_args()

    project_yml_text = read_text(PROJECT_YML)
    pbxproj_text = read_text(PBXPROJ)

    project_build, _ = parse_project_yml_build(project_yml_text)
    pbxproj_builds = parse_pbxproj_builds(pbxproj_text)

    if len(set(pbxproj_builds)) != 1:
        raise RuntimeError(
            f"YijiApp CURRENT_PROJECT_VERSION mismatch in project.pbxproj: {pbxproj_builds}"
        )

    pbxproj_build = pbxproj_builds[0]
    if project_build != pbxproj_build:
        raise RuntimeError(
            f"Build number mismatch between project.yml ({project_build}) and project.pbxproj ({pbxproj_build})"
        )

    new_build = project_build + 1
    print(f"YijiApp build number: {project_build} -> {new_build}")

    if not args.apply:
        print("Dry run only. Re-run with --apply to write changes.")
        return 0

    updated_project_yml, _ = update_project_yml(project_yml_text, new_build)
    updated_pbxproj, _ = update_pbxproj(pbxproj_text, new_build)

    write_text(PROJECT_YML, updated_project_yml)
    write_text(PBXPROJ, updated_pbxproj)
    print("Updated project.yml and Yiji.xcodeproj/project.pbxproj")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:  # pragma: no cover
        print(f"[build-number] {error}", file=sys.stderr)
        raise SystemExit(1)
