#!/usr/bin/env python3
"""Inlines web/audio_unlock.js, web/social_creator.js and web/share_test.js into
export_presets.cfg (html/head_include), each as its own <script> block.

    python3 tools/sync_web_head.py

The script must run before the Godot engine loads so it can capture the
engine's AudioContext; html/head_include is the smallest way to put it in
the exported page (no custom HTML shell needed).
"""
import os
import re

root = os.path.join(os.path.dirname(__file__), '..')
js = open(os.path.join(root, 'web', 'audio_unlock.js')).read()
tag = '<script>\n' + js + '</script>'
# Social MVP 0.2A: photo picker + message dialog, a separate script.
social = open(os.path.join(root, 'web', 'social_creator.js')).read()
tag += '\n<script>\n' + social + '</script>'
# Developer share test page (?sharetest=1); inert without the parameter.
sharetest = open(os.path.join(root, 'web', 'share_test.js')).read()
tag += '\n<script>\n' + sharetest + '</script>'
# ConfigFile string: escape backslashes and double quotes.
value = tag.replace('\\', '\\\\').replace('"', '\\"')
path = os.path.join(root, 'export_presets.cfg')
cfg = open(path).read()
new, n = re.subn(r'html/head_include=".*?(?<!\\)"', lambda m: 'html/head_include="' + value + '"', cfg, flags=re.S)
assert n == 1, 'html/head_include not found in export_presets.cfg'
open(path, 'w').write(new)
print('head_include updated (%d + %d + %d bytes of JS)' % (len(js), len(social), len(sharetest)))
