#!/usr/bin/env python3
"""EVENT STUDIO release builder (see event_studio/docs/PROTECTION.md, Layer 4).

Produces dist/event_studio/ and dist/event_studio-<version>.zip, ready to upload to the
Cfx.re Portal (Created Assets) for Asset Escrow. Fails the build if anything would weaken
protection or break Cfx.re release rules.

Usage:  python3 tools/build_release.py [--no-zip] [--skip-tests]
"""
import fnmatch
import os
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'event_studio')
DIST = os.path.join(ROOT, 'dist')
OUT = os.path.join(DIST, 'event_studio')

# Never shipped to customers.
EXCLUDE = [
    'tests/*', 'tests/**',
    'web/js/dev.js',
    'docs/RESEARCH.md', 'docs/MASTER_PLAN.md', 'docs/ARCHITECTURE.md', 'docs/EVENT_ENGINE.md',
    'docs/EVENT_CATALOG.md', 'docs/SECURITY.md', 'docs/DATABASE.md', 'docs/DEVELOPMENT.md',
    'docs/TESTING.md', 'docs/PROTECTION.md',
]

# Core code that must always be encrypted by escrow (never escrow_ignore'd).
CORE_DIRS = ['server/', 'client/', 'shared/', 'modes/', 'integrations/framework/']

# Patterns that are forbidden by Cfx.re release rules or trip "prohibited logic" detection.
FORBIDDEN = [
    (r'\bloadstring\s*\(', 'loadstring (dynamic code)'),
    (r'\bRunString\b', 'RunString (dynamic code)'),
    (r'sv_licenseKey', 'reads the server license key (custom licensing)'),
    (r'ip-api\.com|ipify\.org|checkip\.', 'IP lookup (IP locking)'),
    (r'(?i)license[_-]?(check|verify|server|validate)\s*[=(]', 'custom license check'),
    (r'(?i)\b(obfuscat|luraph|moonsec|ironbrew|prometheus_obf)', 'obfuscator marker'),
]

errors, warnings = [], []


def rel(p):
    return os.path.relpath(p, SRC).replace(os.sep, '/')


def excluded(path):
    return any(fnmatch.fnmatch(path, pat) for pat in EXCLUDE)


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def manifest_list(text, key):
    m = re.search(key + r"\s*\{(.*?)\}", text, re.S)
    return re.findall(r"'([^']+)'", m.group(1)) if m else []


def check_versions(manifest):
    mv = re.search(r"^version\s+'([^']+)'", manifest, re.M)
    iv = re.search(r"ES\.version\s*=\s*'([^']+)'", read(os.path.join(SRC, 'shared/init.lua')))
    changelog = read(os.path.join(SRC, 'CHANGELOG.md'))
    if re.search(r"^## \[Unreleased\]", changelog, re.M):
        warnings.append('CHANGELOG has an [Unreleased] section — move it under a version before publishing')
    cv = re.search(r"^## \[(?!Unreleased)([^\]]+)\]", changelog, re.M)
    versions = {k: v.group(1) if v else None for k, v in [('fxmanifest', mv), ('ES.version', iv), ('CHANGELOG', cv)]}
    if len(set(versions.values())) != 1 or None in versions.values():
        errors.append(f'version mismatch: {versions}')
    return versions['fxmanifest']


def check_manifest(manifest):
    if not re.search(r"^lua54\s+'yes'", manifest, re.M):
        errors.append("fxmanifest must declare lua54 'yes' (required by Asset Escrow)")
    ignore = manifest_list(manifest, 'escrow_ignore')
    if not ignore:
        errors.append('fxmanifest has no escrow_ignore block (config would be encrypted and uneditable)')
    for pat in ignore:
        for core in CORE_DIRS:
            probe = core + 'x.lua'
            if fnmatch.fnmatch(probe, pat) or pat.startswith(core):
                errors.append(f"escrow_ignore '{pat}' would expose core code in {core}")
        if pat.startswith('**') or pat in ('*', '*.lua', '**/*.lua'):
            errors.append(f"escrow_ignore '{pat}' is too broad")
    return ignore


def check_sources(files):
    for path in files:
        if not path.endswith('.lua'):
            continue
        text = read(os.path.join(SRC, path))
        for pat, why in FORBIDDEN:
            if re.search(pat, text):
                errors.append(f'{path}: forbidden pattern — {why}')
        if re.search(r'\bload\s*\(', text) and 'PerformHttpRequest' in text:
            errors.append(f'{path}: load() in a file that performs HTTP requests (remote code loading)')


def check_secrets():
    discord = read(os.path.join(SRC, 'config/discord.lua'))
    for url in re.findall(r"'(https://[^']*discord[^']*)'", discord):
        errors.append(f'config/discord.lua contains a webhook URL ({url[:40]}…) — clear it before release')
    for shared in ['config/general.lua', 'config/ui.lua', 'config/commands.lua', 'config/scoring.lua', 'config/framework.lua']:
        text = read(os.path.join(SRC, shared))
        if re.search(r"(?i)(webhook|password|secret|api[_-]?key)\s*=\s*'[^']+'", text):
            errors.append(f'{shared} is shared with clients and must not contain secrets')


def check_syntax(files):
    luac = shutil.which('luac5.4') or shutil.which('luac')
    if not luac:
        warnings.append('luac not found — Lua syntax check skipped')
        return
    for path in files:
        if path.endswith('.lua'):
            r = subprocess.run([luac, '-p', os.path.join(SRC, path)], capture_output=True, text=True)
            if r.returncode != 0:
                errors.append(f'syntax: {r.stderr.strip()}')


def run_tests():
    lua = shutil.which('lua5.4') or shutil.which('lua')
    if not lua:
        warnings.append('lua not found — tests skipped')
        return
    r = subprocess.run([lua, os.path.join(SRC, 'tests/run.lua')], capture_output=True, text=True, cwd=SRC)
    tail = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else r.stderr
    if r.returncode != 0:
        errors.append(f'tests failed: {tail}')
    else:
        print(f'  tests: {tail}')


def main():
    args = set(sys.argv[1:])
    manifest = read(os.path.join(SRC, 'fxmanifest.lua'))
    print('EVENT STUDIO release build')
    version = check_versions(manifest)
    ignore = check_manifest(manifest)

    files = []
    for dirpath, _, names in os.walk(SRC):
        for n in names:
            p = rel(os.path.join(dirpath, n))
            if not excluded(p):
                files.append(p)
    files.sort()

    check_sources(files)
    check_secrets()
    check_syntax(files)
    if '--skip-tests' not in args:
        run_tests()

    for w in warnings:
        print(f'  WARN  {w}')
    if errors:
        for e in errors:
            print(f'  FAIL  {e}')
        print(f'\nRelease blocked: {len(errors)} problem(s).')
        sys.exit(1)

    shutil.rmtree(OUT, ignore_errors=True)
    for p in files:
        dst = os.path.join(OUT, p)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(os.path.join(SRC, p), dst)

    editable = [p for p in files if any(fnmatch.fnmatch(p, pat) for pat in ignore)]
    encrypted = [p for p in files if p.endswith('.lua') and p not in editable]
    print(f'  version {version}: {len(files)} files, {len(encrypted)} Lua files will be escrow-encrypted, '
          f'{len(editable)} stay editable (config/locales/themes/hooks/sql)')

    if '--no-zip' not in args:
        zpath = os.path.join(DIST, f'event_studio-{version}.zip')
        with zipfile.ZipFile(zpath, 'w', zipfile.ZIP_DEFLATED) as z:
            for p in files:
                z.write(os.path.join(OUT, p), f'event_studio/{p}')
        print(f'  wrote {os.path.relpath(zpath, ROOT)} — upload it in the Cfx.re Portal (Created Assets) for escrow')
    print('OK')


if __name__ == '__main__':
    main()
