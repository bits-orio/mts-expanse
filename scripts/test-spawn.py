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
# The published 0.1.15 is a Factorio 2.0 mod. On a newer engine the old save is
# made by PREVIOUS_FACTORIO with PREVIOUS_MTS_MOD_ZIP, then loaded by FACTORIO.
OLD_FACTORIO = Path(os.environ.get('PREVIOUS_FACTORIO', str(FACTORIO)))
OLD_MTS = Path(os.environ.get('PREVIOUS_MTS_MOD_ZIP', str(MTS)))
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
    def write_profile(mods_dir, config, engine, mts_zip):
        (mods_dir / mts_zip.name).symlink_to(mts_zip)
        mods = [{'name': n, 'enabled': True} for n in ['base', 'mts-expanse', 'multi-team-support']]
        mods += [{'name': n, 'enabled': space} for n in ['space-age', 'quality', 'elevated-rails']]
        (mods_dir / 'mod-list.json').write_text(json.dumps({'mods': mods}))
        config.write_text(f'[path]\nread-data={engine.parent.parent}/data\nwrite-data={path}/write-data\n[general]\nlocale=en\n')

    (path / 'write-data').mkdir()
    write_profile(path / 'mods', path / 'config.ini', FACTORIO, MTS)
    create = (FACTORIO, path / 'config.ini', path / 'mods')
    if upgrade:
        # The old version gets its own mod folder, so each engine sees one copy.
        old = path / 'old-mods/mts-expanse_0.1.15'
        old.mkdir(parents=True)
        # The published 0.1.15 source, independent of the working tree or branch.
        archive = subprocess.check_output(['git', 'archive', '--format=zip', '37315e7053d6ada5c1dc57c41e91706775050e00'], cwd=ROOT)
        with zipfile.ZipFile(io.BytesIO(archive)) as z:
            z.extractall(old)
        instrument(old, True)
        write_profile(path / 'old-mods', path / 'config-old.ini', OLD_FACTORIO, OLD_MTS)
        create = (OLD_FACTORIO, path / 'config-old.ini', path / 'old-mods')
    save = path / 'test.zip'
    load = (FACTORIO, path / 'config.ini', path / 'mods')
    for label, (engine, config, mods_dir), args in [('create', create, ['--create', str(save)]),
            ('benchmark', load, ['--benchmark', str(save), '--benchmark-ticks', '180', '--benchmark-runs', '1', '--benchmark-sanitize'])]:
        with (path / f'{label}.log').open('w') as log:
            result = subprocess.run([str(engine), '--config', str(config), '--mod-directory', str(mods_dir), *args], stdout=log, stderr=subprocess.STDOUT, timeout=120)
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
