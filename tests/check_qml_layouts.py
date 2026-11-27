#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Items directly inside a RowLayout, ColumnLayout or GridLayout must not set
width, height, x, y or anchors: the layout owns those, and Qt calls it
undefined behaviour. Use implicitWidth/implicitHeight or Layout.* instead.

qmllint's Qt Quick plugin reports the same thing (Quick.layout-positioning),
but not every qmllint has that plugin (Python's PySide6 copy doesn't), so
scripts/check.sh runs this as well.

Usage: check_qml_layouts.py FILE.qml...   Exit 1 if anything is found."""
import re
import sys

LAYOUT = re.compile(r"(Row|Column|Grid)Layout$")
TOKEN = re.compile(r"([A-Z]\w*(?:\.\w+)?)\s*\{|\{|\}|([A-Za-z_.]+)\s*:")
OWNED = {"width", "height", "x", "y"}

found = 0
for path in sys.argv[1:]:
    stack = []  # object types, innermost last ("?" for other braces)
    with open(path, encoding="utf-8") as fh:
        for number, line in enumerate(fh, 1):
            code = re.sub(r"//.*", "", line)
            for tok in TOKEN.finditer(code):
                if tok.group(1):
                    stack.append(tok.group(1))
                elif tok.group(0) == "{":
                    stack.append("?")
                elif tok.group(0) == "}":
                    if stack:
                        stack.pop()
                else:
                    prop = tok.group(2)
                    if len(stack) >= 2 and LAYOUT.match(stack[-2]) and (prop in OWNED or prop.startswith("anchors")):
                        fix = (f"use implicit{prop[:1].upper()}{prop[1:]} or Layout.* instead"
                               if prop in ("width", "height") else "use Layout.* instead")
                        print(f"{path}:{number}: {prop} set on {stack[-1]} inside {stack[-2]}; {fix}")
                        found += 1
sys.exit(1 if found else 0)
