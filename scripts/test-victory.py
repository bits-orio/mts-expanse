#!/usr/bin/env python3
"""Exercise rewards, continued play, and a real 0.1.12 save upgrade in Factorio."""
import concurrent.futures
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FACTORIO = Path(os.environ.get('FACTORIO', str(Path.home() / 'Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio')))
READ_DATA = FACTORIO.parent.parent / 'data'
OLD_ZIP = Path(os.environ.get('PREVIOUS_MOD_ZIP', str(ROOT.parent / 'mts-expanse_0.1.12.zip')))
MTS_ZIP = Path(os.environ.get('MTS_MOD_ZIP', str(Path.home() / 'Library/Application Support/factorio/mods/multi-team-support_0.6.6.zip')))
VERSION = json.loads((ROOT / 'info.json').read_text())['version']
WORK = Path(tempfile.mkdtemp(prefix='mts-expanse-victory-'))


def instrument(mod, platform=False):
    main = mod / 'maps/expanse/main.lua'
    source = main.read_text()
    pos = source.rindex('return Public')
    main.write_text(source[:pos] + "function Public.test_state(name) return state_from_force_name(name or 'player') end\n\n" + source[pos:])
    control = mod / 'control.lua'
    source = control.read_text()
    if platform:
        source = source.replace("local Expanse = require 'maps.expanse.main'", "require('utils.event').on_init(function() settings.global['mts-expanse-use-space-platform'] = {value = true} end)\nlocal Expanse = require 'maps.expanse.main'")
    control.write_text(source + "\nrequire('victory_probe').install(Expanse)\n")
    shutil.copyfile(ROOT / 'scripts/victory-probe.lua', mod / 'victory_probe.lua')


def profile(path, mod, mts, space):
    (path / 'mods').mkdir(parents=True)
    (path / 'write-data').mkdir()
    (path / 'mods' / mod.name).symlink_to(mod)
    mods = [{'name': n, 'enabled': True} for n in ['base', 'mts-expanse']]
    mods += [{'name': n, 'enabled': space} for n in ['space-age', 'quality', 'elevated-rails']]
    if mts:
        (path / 'mods' / MTS_ZIP.name).symlink_to(MTS_ZIP)
        mods.append({'name': 'multi-team-support', 'enabled': True})
    (path / 'mods/mod-list.json').write_text(json.dumps({'mods': mods}))
    (path / 'config.ini').write_text(f'[path]\nread-data={READ_DATA}\nwrite-data={path}/write-data\n[general]\nlocale=en\n')


def run_engine(path, args, label):
    with (path / f'{label}.log').open('w') as output:
        subprocess.run([str(FACTORIO), '--config', str(path / 'config.ini'), '--mod-directory', str(path / 'mods'), *args], stdout=output, stderr=subprocess.STDOUT, check=True)


def run_case(case):
    name, mts, space, platform, upgrade = case
    path = WORK / name
    mod = WORK / (name + '-source') / f'mts-expanse_{VERSION}'
    shutil.copytree(ROOT, mod, ignore=shutil.ignore_patterns('.git', 'scripts', '*.zip', '.DS_Store', '__pycache__'))
    instrument(mod, platform)
    profile(path, mod, mts, space)
    save = path / 'test.zip'
    if upgrade:
        old_root = WORK / (name + '-legacy')
        with zipfile.ZipFile(OLD_ZIP) as archive:
            archive.extractall(old_root)
        old = old_root / 'mts-expanse_0.1.12'
        instrument(old)
        old_profile = WORK / (name + '-old-profile')
        profile(old_profile, old, mts, space)
        run_engine(old_profile, ['--create', str(save)], 'create')
    else:
        run_engine(path, ['--create', str(save)], 'create')
    run_engine(path, ['--benchmark', str(save), '--benchmark-ticks', '10380', '--benchmark-runs', '1', '--benchmark-sanitize'], 'benchmark')
    results = [json.loads(line) for line in (path / 'write-data/script-output/victory-test.jsonl').read_text().splitlines()]
    assert any(r['kind'] == 'keep_playing_pass' and r['upgraded'] == upgrade for r in results), results
    if space:
        assert any(r['kind'] == 'reward_pass' for r in results), results
    log = (path / 'write-data/factorio-current.log').read_text()
    assert 'stack traceback:' not in log, f'Runtime error; see {path}/write-data/factorio-current.log'
    return name


if __name__ == '__main__':
    assert OLD_ZIP.is_file(), f'Set PREVIOUS_MOD_ZIP to the published 0.1.12 ZIP: {OLD_ZIP}'
    assert MTS_ZIP.is_file(), f'Set MTS_MOD_ZIP to the installed MTS ZIP: {MTS_ZIP}'
    print(f'Isolated test profiles: {WORK}', flush=True)
    cases = [
        ('standalone', False, True, False, False),
        ('mts', True, True, False, False),
        ('standalone-platform', False, True, True, False),
        ('mts-platform', True, True, True, False),
        ('vanilla', False, False, False, False),
        ('upgrade-standalone', False, True, False, True),
        ('upgrade-mts', True, True, False, True),
    ]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        for result in executor.map(run_case, cases):
            print(f'PASS {result}', flush=True)
