#!/usr/bin/env python3
"""Install a hash-verified Ryhze update after the app explicitly exits."""
import argparse
import hashlib
import importlib.util
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tarfile
import tempfile
import time


def unpack(archive, sha256, destination):
    with archive.open('rb') as stream:
        digest = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
        if digest.hexdigest() != sha256:
            raise RuntimeError('The update checksum does not match.')
    with tarfile.open(archive, 'r:gz') as tar:
        members = tar.getmembers()
        if len(members) > 30000 or sum(m.size for m in members) > 3 * 1024**3:
            raise RuntimeError('Update archive is too large.')
        seen = set()
        for member in members:
            path = PurePosixPath(member.name)
            if (not path.parts or path.is_absolute() or '..' in path.parts or '\\' in member.name or ':' in member.name
                    or path.parts[0] != 'ryhze-steamdeck' or not (member.isfile() or member.isdir())
                    or member.name in seen):
                raise RuntimeError('Update archive contains an unsafe entry.')
            seen.add(member.name)
        for member in members:
            output = destination.joinpath(*PurePosixPath(member.name).parts)
            if member.isdir():
                output.mkdir(parents=True, exist_ok=True)
            else:
                output.parent.mkdir(parents=True, exist_ok=True)
                with tar.extractfile(member) as source, output.open('wb') as stream:
                    shutil.copyfileobj(source, stream)
                output.chmod(member.mode & 0o755)
    root = destination / 'ryhze-steamdeck'
    for name in ['install.py', 'launch.py', 'boot_settings.py', 'bundle/ryhze']:
        if not (root / name).is_file():
            raise RuntimeError('Update archive is incomplete.')
    return root


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--sha256', required=True)
    parser.add_argument('--target', type=Path, required=True)
    parser.add_argument('--parent-pid', type=int, required=True)
    parser.add_argument('--ready-file', type=Path, required=True)
    args = parser.parse_args()
    target = args.target.resolve()
    expected = Path(os.environ.get('XDG_DATA_HOME') or Path.home() / '.local/share') / 'ryhze'
    if target != expected.resolve() or not (target / 'ryhze-steamdeck-install-v1').is_file():
        raise RuntimeError('Updates require a recognized per-user Ryhze installation.')
    parent = Path('/proc') / str(args.parent_pid)
    if (parent / 'exe').resolve() != (target / 'bundle/ryhze').resolve():
        raise RuntimeError('The update request did not come from this Ryhze installation.')
    stage = Path(tempfile.mkdtemp(prefix='.ryhze-update-', dir=target.parent))
    handed_off = False
    try:
        source = unpack(args.archive, args.sha256, stage)
        args.ready_file.write_text('ready')
        for _ in range(1200):
            if not parent.exists():
                break
            time.sleep(.1)
        else:
            raise RuntimeError('Ryhze did not close. Close it before installing this update.')
        handed_off = True
        spec = importlib.util.spec_from_file_location('ryhze_installer', source / 'install.py')
        installer = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(installer)
        installed, _, _ = installer.install(source / 'bundle', Path.home(), os.environ)
        subprocess.Popen(['/usr/bin/python3', str(installed / 'launch.py')], start_new_session=True)
    except Exception as error:
        if not handed_off:
            args.ready_file.write_text('error: ' + str(error))
        if shutil.which('zenity'):
            subprocess.run(['zenity', '--error', '--title=Ryhze update', '--text=' + str(error)])
        if handed_off and (target / 'launch.py').is_file():
            subprocess.Popen(['/usr/bin/python3', str(target / 'launch.py')], start_new_session=True)
        raise
    finally:
        shutil.rmtree(stage)


if __name__ == '__main__':
    main()
