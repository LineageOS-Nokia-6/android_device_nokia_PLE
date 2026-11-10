#!/usr/bin/env python3
# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
"""Preflight the complete pinned PLE series before changing platform sources."""
import argparse
import hashlib
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tempfile

ENV = {key: value for key, value in os.environ.items() if not key.startswith('GIT_')}
ENV.update(GIT_OPTIONAL_LOCKS='0', GIT_TERMINAL_PROMPT='0', GIT_NO_LAZY_FETCH='1')

class PatchError(Exception):
    pass

def git(root, *arguments, data=None, check=True, git_dir=None, work_tree=None):
    command = ['git', '-C', str(root), '-c', 'core.hooksPath=/dev/null']
    if git_dir is not None:
        command += ['--git-dir=' + str(git_dir), '--work-tree=' + str(work_tree)]
    result = subprocess.run(command + list(arguments), input=data,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=ENV)
    if check and result.returncode:
        raise PatchError(f'{root}: git {arguments[0]} failed: '
                         + result.stderr.decode(errors='replace').strip())
    return result

def value(root, *arguments):
    return git(root, *arguments).stdout.decode().strip()

def relative(text):
    path = PurePosixPath(text)
    if not text or path.is_absolute() or any(p in {'', '.', '..'} for p in text.split('/')):
        raise PatchError('unsafe relative path: ' + text)
    return path

def load_series(kit, manifest):
    projects = {}
    seen = set()
    for line in manifest.decode().splitlines():
        if not line or line.startswith('#'):
            continue
        fields = line.split('\t')
        if len(fields) != 5:
            raise PatchError('series.tsv requires project, patch, strip, base, SHA256')
        project, name, strip, base, digest = fields
        relative(project)
        relative(name)
        if not re.fullmatch(r'\d{4}-[a-z0-9.-]+\.patch', name) or name in seen:
            raise PatchError('invalid or duplicate patch: ' + name)
        if strip not in {'1', '3'} or not re.fullmatch('[0-9a-f]{40}', base):
            raise PatchError('invalid strip level or pinned base: ' + name)
        patch = kit / name
        if not patch.is_file() or not patch.resolve().is_relative_to(kit):
            raise PatchError('missing or external patch: ' + name)
        if not re.fullmatch('[0-9a-f]{64}', digest) or hashlib.sha256(patch.read_bytes()).hexdigest() != digest:
            raise PatchError('patch SHA256 mismatch: ' + name)
        group = projects.setdefault(project, {'base': base, 'patches': [], 'digests': {}})
        if group['base'] != base:
            raise PatchError('inconsistent base for ' + project)
        group['patches'].append((patch, strip))
        group['digests'][name] = digest
        seen.add(name)
    if not projects or seen != {p.name for p in kit.glob('*.patch')}:
        raise PatchError('series.tsv does not describe the complete patch directory')
    return projects

def inputs_unchanged(kit, digest, groups):
    if hashlib.sha256((kit / 'series.tsv').read_bytes()).hexdigest() != digest:
        raise PatchError('series.tsv changed after preflight')
    for group in groups.values():
        for name, expected in group['digests'].items():
            if hashlib.sha256((kit / name).read_bytes()).hexdigest() != expected:
                raise PatchError('patch changed after preflight: ' + name)

def source_guard(project):
    if value(project, 'rev-parse', '--show-toplevel') != str(project):
        raise PatchError('not an independent Git project: ' + str(project))
    for marker in ('rebase-apply', 'rebase-merge', 'MERGE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD'):
        path = Path(value(project, 'rev-parse', '--git-path', marker))
        if not path.is_absolute():
            path = project / path
        if path.exists():
            raise PatchError('unfinished Git operation: ' + str(project))
    if git(project, 'diff', '--cached', '--quiet', check=False).returncode:
        raise PatchError('staged changes: ' + str(project))

def snapshot(project, scratch):
    """Read the live worktree using a private index/object store, never its index."""
    source_guard(project)
    head = value(project, 'rev-parse', 'HEAD')
    git(scratch, 'read-tree', head)
    # Preserve sparse-checkout omissions, but do not trust assume-unchanged bits.
    skipped = [row[2:] for row in git(project, 'ls-files', '-v', '-z').stdout.split(b'\0')
               if row[:1] in {b'S', b's'}]
    if skipped:
        git(scratch, 'update-index', '--skip-worktree', '-z', '--stdin', data=b'\0'.join(skipped) + b'\0')
    git(project, 'add', '-A', '--', '.', git_dir=scratch / '.git', work_tree=project)
    return head, value(scratch, 'write-tree')

def preflight(source, kit, groups, temporary):
    states = []
    locked_patches = temporary / 'patches'
    locked_patches.mkdir()
    for number, (name, group) in enumerate(groups.items()):
        project = (source / name).resolve()
        if not project.is_relative_to(source) or not project.is_dir():
            raise PatchError('missing or external project: ' + name)
        source_guard(project)
        scratch = temporary / str(number)
        git(source, 'clone', '--quiet', '--shared', '--no-checkout', '--no-hardlinks',
            str(project), str(scratch))
        git(scratch, 'cat-file', '-e', group['base'] + '^{commit}')
        git(scratch, 'read-tree', group['base'])
        prefixes = [value(scratch, 'write-tree')]
        locked = []
        for patch, strip in group['patches']:
            data = patch.read_bytes()
            if hashlib.sha256(data).hexdigest() != group['digests'][patch.name]:
                raise PatchError('patch changed after manifest validation: ' + patch.name)
            frozen = locked_patches / patch.name
            frozen.write_bytes(data)
            frozen.chmod(0o444)
            locked.append((frozen, strip))
            git(scratch, 'apply', '--cached', '--check', '--whitespace=error', '-p' + strip, str(frozen))
            git(scratch, 'apply', '--cached', '--whitespace=error', '-p' + strip, str(frozen))
            prefixes.append(value(scratch, 'write-tree'))
        head, current = snapshot(project, scratch)
        if current not in prefixes:
            raise PatchError('unrelated work or unsupported source revision: ' + name)
        prefix = prefixes.index(current)
        # A sparse checkout still needs every existing preimage materialized.
        old_paths, added_paths = set(), set()
        for patch, strip in group['patches'][prefix:]:
            text = patch.read_text()
            old_paths.update('/'.join(p.split('/')[int(strip):]) for p in
                             re.findall(r'(?m)^--- (a/[^\t\n]+)', text))
            added_paths.update('/'.join(p.split('/')[int(strip):]) for p in
                               re.findall(r'(?m)^--- /dev/null\n\+\+\+ (b/[^\t\n]+)', text))
        for name_in_project in old_paths - added_paths:
            relative(name_in_project)
            if not (project / name_in_project).is_file():
                raise PatchError('required source is not materialized: ' + name + '/' + name_in_project)
        states.append(dict(group, name=name, project=project, scratch=scratch, head=head,
                           prefix=prefix, current=current, prefixes=prefixes, patches=locked))
        print(('already applied: ' if prefix == len(group['patches']) else
               f'applicable ({prefix}/{len(group["patches"])} present): ') + name, flush=True)
    return states

def main():
    parser = argparse.ArgumentParser(prog='apply.sh', description=__doc__)
    parser.add_argument('--source', type=Path, default=Path.cwd(), help='LineageOS Android source root')
    parser.add_argument('--check', action='store_true', help='validate without modifying platform sources')
    args = parser.parse_args()
    source, kit = args.source.resolve(), Path(__file__).resolve().parent
    if not (source / '.repo').is_dir() or not (source / 'build/envsetup.sh').is_file():
        raise PatchError('not an Android repo checkout: ' + str(source))
    manifest = (kit / 'series.tsv').read_bytes()
    manifest_digest = hashlib.sha256(manifest).hexdigest()
    groups = load_series(kit, manifest)
    with tempfile.TemporaryDirectory(prefix='ple-platform-preflight-') as directory:
        states = preflight(source, kit, groups, Path(directory))
        # Revalidate every project before the first write, then again per patch.
        inputs_unchanged(kit, manifest_digest, groups)
        for state in states:
            if snapshot(state['project'], state['scratch']) != (state['head'], state['current']):
                raise PatchError('project changed after preflight: ' + state['name'])
        if args.check:
            print('CHECK PASSED: no platform source/index/HEAD changes')
            return
        for state in states:
            for index in range(state['prefix'], len(state['patches'])):
                if snapshot(state['project'], state['scratch']) != (state['head'], state['prefixes'][index]):
                    raise PatchError('project changed before patch: ' + state['name'])
                patch, strip = state['patches'][index]
                inputs_unchanged(kit, manifest_digest, groups)
                git(state['project'], 'apply', '--check', '--whitespace=error', '-p' + strip, str(patch))
                git(state['project'], 'apply', '--whitespace=error', '-p' + strip, str(patch))
                if snapshot(state['project'], state['scratch']) != (state['head'], state['prefixes'][index + 1]):
                    raise PatchError('unexpected result after ' + patch.name)
                print('applied: ' + patch.name, flush=True)
        print('DONE: platform patches present; no commits, builds or device operations')

if __name__ == '__main__':
    try:
        main()
    except (PatchError, OSError, ValueError) as error:
        print('error: ' + str(error), file=sys.stderr)
        print('Stopped without reset/clean/commit. Exact completed patch prefixes can be resumed.', file=sys.stderr)
        sys.exit(1)
