"""Windows native removal tests; all mutations are confined to new temporary fixtures."""
import ctypes
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import zipfile

SCRIPT = Path(__file__).resolve().parents[1] / 'assets/update/uninstall-race-version.ps1'
BUILD = 'RACE-0.0.5-Windows'
BASE = Path(tempfile.mkdtemp(prefix='ryhze-uninstall-tests-')).resolve()
results = []


def fixture(name):
    root = BASE / name / 'RACE/versions'
    target = root / BUILD
    package = target / BUILD
    (package / 'data').mkdir(parents=True)
    content = {'RACE.exe': b'isolated engine fixture', 'data/core.bin': b'owned fixture data'}
    if name == 'long-path':
        content['Diagnostics/Performance/Project/Assets/Cache/' + 'f' * 64 + '-v1.race_cache'] = b'long path regression'
    for path, data in content.items():
        (package / path).parent.mkdir(parents=True, exist_ok=True)
        (package / path).write_bytes(data)
    manifest = {'schemaVersion': 1, 'product': 'RACE', 'version': '0.0.5', 'files': [
        {'path': path, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
        for path, data in content.items()
    ]}
    manifest_file = package / 'package-manifest.json'
    manifest_file.write_text(json.dumps(manifest), encoding='utf-8')
    digest = hashlib.sha256(manifest_file.read_bytes()).hexdigest()
    return root, target, package, digest


def invoke(name, item, success=False, extra=None):
    root, target, package, digest = item
    args = ['powershell.exe', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', str(SCRIPT),
            '-Root', str(root), '-BuildId', BUILD, '-Executable', str(package / 'RACE.exe'), '-Version', '0.0.5']
    if extra is not None:
        for flag in extra[::2]:
            if flag in args:
                index = args.index(flag)
                del args[index:index + 2]
    args += extra if extra is not None else ['-ManifestSha256', digest]
    result = subprocess.run(args, capture_output=True, text=True, timeout=60)
    assert (result.returncode == 0) == success, (name, result.stdout, result.stderr)
    if success:
        assert not target.exists(), name
    else:
        assert (package / 'RACE.exe').exists(), name
    results.append({'test': name, 'passed': True, 'message': (result.stdout or result.stderr).strip()})


normal = fixture('normal')
other = normal[0] / 'RACE-other'
other.mkdir()
(other / 'project.race').write_text('keep', encoding='utf-8')
invoke('only selected owned installation removed', normal, True)
assert (other / 'project.race').read_text() == 'keep'
invoke('missing managed directory is idempotent', normal, True)

long_path = fixture('long-path')
long_archive = BASE / 'long.zip'
with zipfile.ZipFile(long_archive, 'w') as archive:
    for file in long_path[2].rglob('*'):
        if file.is_file():
            archive.write(file, f'{BUILD}/{file.relative_to(long_path[2]).as_posix()}')
long_sha = hashlib.sha256(long_archive.read_bytes()).hexdigest()
long_root = BASE / ('support-folder-' * 4) / 'RACE/versions'
install = subprocess.run(['powershell.exe', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File',
    str(SCRIPT.with_name('install-race-version.ps1')), '-Archive', str(long_archive), '-Root', str(long_root),
    '-BuildId', BUILD, '-Entrypoint', f'{BUILD}/RACE.exe', '-Sha256', long_sha], capture_output=True, text=True, timeout=60)
assert install.returncode == 0, (install.stdout, install.stderr)
long_package = long_root / BUILD / BUILD
assert max(len(str(p)) for p in long_package.rglob('*')) > 260
invoke('long path package installs and uninstalls', (long_root, long_root / BUILD, long_package, long_path[3]), True)

changed = fixture('modified')
(changed[2] / 'data/core.bin').write_bytes(b'user changes')
invoke('modified bundled file preserved', changed)
assert (changed[2] / 'data/core.bin').read_bytes() == b'user changes'

extra = fixture('extra')
(extra[2] / 'project.race').write_text('user project', encoding='utf-8')
invoke('extra project prevents any removal', extra)
assert (extra[2] / 'project.race').read_text() == 'user project'

folder = fixture('empty-project')
(folder[2] / 'MyProject').mkdir()
invoke('empty user project folder preserved', folder)

tampered = fixture('manifest')
(tampered[2] / 'package-manifest.json').write_text('{}', encoding='utf-8')
invoke('changed ownership manifest rejected', tampered)

external = fixture('external-path')
external_exe = BASE / 'external-RACE.exe'
external_exe.write_text('never remove', encoding='utf-8')
invoke('external selected executable refused', external, extra=['-ManifestSha256', external[3], '-Executable', str(external_exe)])
assert external_exe.read_text() == 'never remove'
invoke('build traversal refused', fixture('traversal'), extra=['-BuildId', '../outside', '-ManifestSha256', external[3]])
invoke('non-managed root refused', fixture('wrong-root'), extra=['-Root', str(BASE), '-ManifestSha256', external[3]])

locked = fixture('locked')
create = ctypes.windll.kernel32.CreateFileW
create.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p]
create.restype = ctypes.c_void_p
close = ctypes.windll.kernel32.CloseHandle
close.argtypes = [ctypes.c_void_p]
handle = create(str(locked[2] / 'data/core.bin'), 0x80000000, 1, None, 3, 0, None)
assert handle != ctypes.c_void_p(-1).value
try:
    invoke('locked file stops before deleting any owned file', locked)
finally:
    close(handle)
assert (locked[2] / 'data/core.bin').exists()
invoke('retry after file lock released', locked, True)

for part in ['data', 'build', 'root']:
    item = fixture('redirect-' + part)
    path = {'data': item[2] / 'data', 'build': item[1], 'root': item[0]}[part]
    saved = BASE / ('redirected-' + part)
    assert path.resolve().is_relative_to(BASE) and saved.resolve().is_relative_to(BASE)
    path.rename(saved)
    env = {**os.environ, 'RYHZE_QA_LINK': str(path), 'RYHZE_QA_TARGET': str(saved)}
    subprocess.run(['powershell.exe', '-NoProfile', '-Command', 'New-Item -ItemType Junction -Path $env:RYHZE_QA_LINK -Target $env:RYHZE_QA_TARGET | Out-Null'], env=env, check=True, capture_output=True)
    invoke('junction refused at ' + part, item)
    assert saved.exists()

legacy = fixture('legacy')
archive = BASE / 'legacy.zip'
with zipfile.ZipFile(archive, 'w') as zip_file:
    for file in legacy[2].rglob('*'):
        if file.is_file():
            zip_file.write(file, f'{BUILD}/{file.relative_to(legacy[2]).as_posix()}')
sha = hashlib.sha256(archive.read_bytes()).hexdigest()
invoke('legacy inventory authenticated by original archive', legacy, True, ['-Archive', str(archive), '-Sha256', sha])

output = Path(__file__).resolve().parents[3] / '.codex/ui-review/uninstall-native-results.json'
output.write_text(json.dumps({'fixtureRoot': str(BASE), 'tests': results}, indent=2), encoding='utf-8')
print(f'{len(results)} native uninstall checks passed. Receipt: {output}')
