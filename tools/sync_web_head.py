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
# The player build ("Web Friend Test", preset 1), the QA build ("Web QA",
# preset 2) and the Magnet lab build (preset 3) get everything except the
# developer share test page.
player_tag = tag.replace('\n<script>\n' + sharetest + '</script>', '')
assert player_tag != tag
# The QA build keeps its page crash-forensics log apart from the normal
# game's (the QA and Friend Test builds may share one browser origin).
qa_tag = player_tag.replace("'chain_escape_page_events'", "'chain_escape_qa_page_events'")
assert qa_tag.count("'chain_escape_qa_page_events'") == 1
# The Magnet lab build ("Web Magnet Lab", preset 3) likewise.
magnet_tag = player_tag.replace("'chain_escape_page_events'", "'chain_escape_magnetlab_page_events'")


def esc(t):
    # ConfigFile string: escape backslashes and double quotes.
    return t.replace('\\', '\\\\').replace('"', '\\"')


path = os.path.join(root, 'export_presets.cfg')
cfg = open(path).read()
parts = re.split(r'(?m)^(?=\[preset\.\d+\.options\])', cfg)
out = []
done = 0
for part in parts:
    m = re.match(r'\[preset\.(\d+)\.options\]', part)
    if m:
        value = esc({'0': tag, '1': player_tag, '2': qa_tag, '3': magnet_tag}[m.group(1)])
        part, n = re.subn(r'html/head_include=".*?(?<!\\)"', lambda _m: 'html/head_include="' + value + '"', part, flags=re.S)
        assert n == 1, 'html/head_include not found in preset %s' % m.group(1)
        done += 1
    out.append(part)
assert done == 4, 'expected presets 0 (Web), 1 (Web Friend Test), 2 (Web QA) and 3 (Web Magnet Lab)'
open(path, 'w').write(''.join(out))
print('head_include updated (%d + %d + %d bytes of JS)' % (len(js), len(social), len(sharetest)))
