#!/usr/bin/env python3
"""Check the mission rocket cargo setting at 1 t (the default) and at a bigger rocket.

A startup setting cannot be passed on the command line, so each case patches
the default value in its own disposable copy of the mod.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FACTORIO = Path(os.environ.get('FACTORIO', str(Path.home() / 'Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio')))
VERSION = json.loads((ROOT / 'info.json').read_text())['version']
TICKS = 3000
DEFAULT = "        default_value = '1',\n        allowed_values = { '1', '2', '3', '4', '5' },"


def run_case(tonnes):
    name = f'{tonnes}t'
    path = Path(tempfile.mkdtemp(prefix=f'mts-expanse-lift-{name}-'))
    print(f'{name}: {path}', flush=True)
    mod = path / 'mods' / f'mts-expanse_{VERSION}'
    shutil.copytree(ROOT, mod, ignore=shutil.ignore_patterns('.git', 'scripts', '*.zip', '__pycache__', '.DS_Store'))
    settings = mod / 'settings.lua'
    text = settings.read_text()
    assert text.count(DEFAULT) == 1, 'The mission rocket cargo setting moved; update DEFAULT in this script.'
    settings.write_text(text.replace(DEFAULT, DEFAULT.replace("'1',\n", f"'{tonnes}',\n")))
    main = mod / 'maps/expanse/main.lua'
    text = main.read_text()
    pos = text.rindex('return Public')
    main.write_text(text[:pos] + "function Public.test_state(name) return state_from_force_name(name) end\n" + text[pos:])
    control = mod / 'control.lua'
    control.write_text(control.read_text() + "\nrequire('rocket_lift_probe').install(Expanse)\n")
    shutil.copyfile(ROOT / 'scripts/rocket-lift-probe.lua', mod / 'rocket_lift_probe.lua')
    mods = [{'name': n, 'enabled': True} for n in ['base', 'quality', 'elevated-rails', 'space-age', 'mts-expanse']]
    (path / 'mods/mod-list.json').write_text(json.dumps({'mods': mods}))
    (path / 'write-data').mkdir()
    (path / 'config.ini').write_text(f'[path]\nread-data={FACTORIO.parent.parent}/data\nwrite-data={path}/write-data\n[general]\nlocale=en\n')
    save = path / 'test.zip'
    runs = [('create', ['--create', str(save)]),
            ('benchmark', ['--benchmark', str(save), '--benchmark-ticks', str(TICKS), '--benchmark-runs', '1', '--benchmark-sanitize'])]
    for label, args in runs:
        with (path / f'{label}.log').open('w') as output:
            result = subprocess.run([str(FACTORIO), '--config', str(path / 'config.ini'), '--mod-directory', str(path / 'mods'), *args],
                                    stdout=output, stderr=subprocess.STDOUT, timeout=300)
        log = (path / f'{label}.log').read_text() + (path / 'write-data/factorio-current.log').read_text()
        if result.returncode or 'stack traceback:' in log:
            raise AssertionError(log[-6500:])
    report = path / 'write-data/script-output/rocket-lift-result.json'
    assert report.exists(), f'The probe did not finish within {TICKS} ticks: {path}'
    checks = json.loads(report.read_text())
    failed = sorted(check for check, ok in checks.items() if not ok)
    assert not failed, f'{name} failed: {failed}'
    print(f'PASS {name}: {len(checks)} checks', flush=True)


if __name__ == '__main__':
    for tonnes in [int(value) for value in os.environ.get('LIFT_CASES', '1,3').split(',')]:
        run_case(tonnes)
