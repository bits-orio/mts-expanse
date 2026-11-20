#!/usr/bin/env python3
"""Open and operate the mission board, the silo side panel and the reset dialog with a real player.

Uses the game's test mode, the one headless mode that has a connected player.
It needs Factorio 2.1.24 or newer.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FACTORIO = Path(os.environ.get('FACTORIO', str(Path.home() / 'Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio')))
VERSION = json.loads((ROOT / 'info.json').read_text())['version']
TEST_MODE_SINCE = (2, 1, 24)
TICKS = 1200


def engine_version():
    output = subprocess.run([str(FACTORIO), '--version'], capture_output=True, text=True).stdout
    return tuple(int(part) for part in re.search(r'Version: (\d+)\.(\d+)\.(\d+)', output).groups())


def run_case(name):
    path = Path(tempfile.mkdtemp(prefix=f'mts-expanse-windows-{name}-'))
    print(f'{name}: {path}', flush=True)
    mod = path / 'mods' / f'mts-expanse_{VERSION}'
    shutil.copytree(ROOT, mod, ignore=shutil.ignore_patterns('.git', 'scripts', '*.zip', '__pycache__', '.DS_Store'))
    main = mod / 'maps/expanse/main.lua'
    text = main.read_text()
    pos = text.rindex('return Public')
    main.write_text(text[:pos] + "function Public.test_state(name) return state_from_force_name(name) end\n" + text[pos:])
    control = mod / 'control.lua'
    control.write_text(control.read_text() + "\nrequire('windows_probe').install(Expanse)\n")
    shutil.copyfile(ROOT / 'scripts/windows-probe.lua', mod / 'windows_probe.lua')
    mods = [{'name': n, 'enabled': True} for n in ['base', 'quality', 'elevated-rails', 'space-age', 'mts-expanse']]
    (path / 'mods/mod-list.json').write_text(json.dumps({'mods': mods}))
    (path / 'write-data').mkdir()
    (path / 'config.ini').write_text(f'[path]\nread-data={FACTORIO.parent.parent}/data\nwrite-data={path}/write-data\n[general]\nlocale=en\n')
    save = path / 'test.zip'
    runs = [('create', ['--create', str(save)]),
            ('test', ['--test-save', str(save), '--test-ticks', str(TICKS)])]
    for label, args in runs:
        with (path / f'{label}.log').open('w') as output:
            result = subprocess.run([str(FACTORIO), '--config', str(path / 'config.ini'), '--mod-directory', str(path / 'mods'), *args],
                                    stdout=output, stderr=subprocess.STDOUT, timeout=300)
        log = (path / f'{label}.log').read_text() + (path / 'write-data/factorio-current.log').read_text()
        if 'stack traceback:' in log:
            raise AssertionError(log[-6500:])
        if label == 'create' and result.returncode:
            raise AssertionError(log[-6500:])
    # Running out of ticks also exits 0, so the DONE line is the proof it finished.
    report = path / 'write-data/script-output/windows-result.json'
    assert 'WINDOWS_TEST DONE' in log and report.exists(), f'The probe did not finish within {TICKS} ticks: {path}'
    checks = json.loads(report.read_text())
    failed = sorted(check for check, ok in checks.items() if not ok)
    assert not failed and result.returncode == 0, f'Failed: {failed} (exit code {result.returncode})'
    print(f'PASS {name}: {len(checks)} checks', flush=True)


if __name__ == '__main__':
    if engine_version() < TEST_MODE_SINCE:
        sys.exit('test-windows.py needs Factorio 2.1.24 or newer: older builds have no test mode.')
    run_case('standalone')
