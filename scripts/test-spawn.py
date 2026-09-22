#!/usr/bin/env python3
"""Exercise team surface reuse and save upgrades in disposable Factorio profiles."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile
import io

ROOT = Path(__file__).resolve().parents[1]
FACTORIO = Path(os.environ.get('FACTORIO', str(Path.home() / 'Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio')))
MTS = Path(os.environ.get('MTS_MOD_ZIP', str(Path.home() / 'Library/Application Support/factorio/mods/multi-team-support_0.6.6.zip')))
VERSION = json.loads((ROOT / 'info.json').read_text())['version']


def instrument(mod, upgrade):
    main = mod / 'maps/expanse/main.lua'
    source = main.read_text()
    pos = source.rindex('return Public')
    main.write_text(source[:pos] + """
function Public.test_state(name) return state_from_force_name(name) end
Public.test_ensure_state = ensure_state_ready
Public.test_configuration_changed = on_configuration_changed
function Public.test_root() return expanse end
""" + source[pos:])
    control = mod / 'control.lua'
    control.write_text(control.read_text() + f"\nrequire('spawn_probe').install(Expanse, {str(upgrade).lower()})\n")
    shutil.copyfile(ROOT / 'scripts/spawn-probe.lua', mod / 'spawn_probe.lua')


def run_case(name, space, upgrade=False):
    path = Path(tempfile.mkdtemp(prefix=f'mts-expanse-spawn-{name}-'))
    print(f'{name}: {path}', flush=True)
    mod = path / 'mods' / f'mts-expanse_{VERSION}'
    shutil.copytree(ROOT, mod, ignore=shutil.ignore_patterns('.git', 'scripts', 'dist', '*.zip', '__pycache__', '.DS_Store'))
    instrument(mod, upgrade)
    old = None
    if upgrade:
        old = path / 'mods/mts-expanse_0.1.15'
        old.mkdir()
        # The published 0.1.15 source, independent of the working tree or branch.
        archive = subprocess.check_output(['git', 'archive', '--format=zip', '37315e7053d6ada5c1dc57c41e91706775050e00'], cwd=ROOT)
        with zipfile.ZipFile(io.BytesIO(archive)) as z:
            z.extractall(old)
        instrument(old, True)
    (path / 'mods' / MTS.name).symlink_to(MTS)
    mods = [{'name': n, 'enabled': True} for n in ['base', 'mts-expanse', 'multi-team-support']]
    mods += [{'name': n, 'enabled': space} for n in ['space-age', 'quality', 'elevated-rails']]
    (path / 'mods/mod-list.json').write_text(json.dumps({'mods': mods}))
    (path / 'write-data').mkdir()
    (path / 'config.ini').write_text(f'[path]\nread-data={FACTORIO.parent.parent}/data\nwrite-data={path}/write-data\n[general]\nlocale=en\n')
    save = path / 'test.zip'
    for label, args in [('create', ['--create', str(save)]), ('benchmark', ['--benchmark', str(save), '--benchmark-ticks', '180', '--benchmark-runs', '1', '--benchmark-sanitize'])]:
        if upgrade:
            mods[1]['version'] = '0.1.15' if label == 'create' else VERSION
            (path / 'mods/mod-list.json').write_text(json.dumps({'mods': mods}))
        with (path / f'{label}.log').open('w') as log:
            result = subprocess.run([str(FACTORIO), '--config', str(path / 'config.ini'), '--mod-directory', str(path / 'mods'), *args], stdout=log, stderr=subprocess.STDOUT, timeout=120)
        if result.returncode or 'stack traceback:' in (path / f'{label}.log').read_text():
            raise AssertionError((path / f'{label}.log').read_text()[-7000:])
        engine_log = (path / 'write-data/factorio-current.log').read_text()
        assert 'stack traceback:' not in engine_log, engine_log[-7000:]
    results = json.loads((path / 'write-data/script-output/spawn-result.json').read_text())
    print(json.dumps(results, indent=2), flush=True)
    assert all(results['checks'].values()), results
    print(f'PASS {name}', flush=True)


if __name__ == '__main__':
    run_case('space-age', True)
    run_case('vanilla', False)
    run_case('upgrade-space-age', True, True)
    run_case('upgrade-vanilla', False, True)
