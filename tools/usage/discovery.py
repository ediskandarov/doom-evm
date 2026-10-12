"""Repository-aware rollout discovery. No transcript content is used for selection."""
import collections
import os
from pathlib import Path
import subprocess
from urllib.parse import urlsplit


def default_roots():
    homes = {Path.home() / '.codex'}
    if os.environ.get('CODEX_HOME'):
        homes.add(Path(os.environ['CODEX_HOME']).expanduser())
    return [h / name for h in sorted(homes) for name in ('sessions', 'archived_sessions')]


def git(project, *args):
    try:
        result = subprocess.run(['git', '-C', str(project), *args], capture_output=True,
                                text=True, timeout=10, check=False)
        return result.stdout.strip() if result.returncode == 0 else ''
    except (OSError, subprocess.TimeoutExpired):
        return ''


def repository_key(value):
    """Compare identity across HTTPS/SSH transports; discard credentials entirely."""
    if not isinstance(value, str) or not value:
        return None
    if '://' not in value and ':' in value and not value.startswith('/'):
        host, path = value.split(':', 1)
        host = host.rsplit('@', 1)[-1]
    else:
        parsed = urlsplit(value)
        host, path = parsed.hostname, parsed.path
    if not host:
        return None
    return host.lower() + '/' + path.strip('/').removesuffix('.git')


def repository(project):
    project = Path(project).resolve()
    common = git(project, 'rev-parse', '--path-format=absolute', '--git-common-dir')
    roots = {project}
    worktrees = []
    for block in git(project, 'worktree', 'list', '--porcelain').split('\n\n'):
        fields = dict(line.split(' ', 1) for line in block.splitlines() if ' ' in line)
        if fields.get('worktree'):
            root = Path(fields['worktree']).resolve()
            roots.add(root)
            worktrees.append({'path': root, 'branch': fields.get('branch'), 'head': fields.get('HEAD')})
    remotes = {repository_key(git(project, 'remote', 'get-url', name))
               for name in git(project, 'remote').splitlines()}
    return {'roots': roots, 'common': Path(common).resolve() if common else None,
            'remotes': remotes - {None}, 'worktrees': worktrees}


def beneath(path, root):
    return path == root or root in path.parents


def discover(roots, project):
    from collect import read_lines
    repo = repository(project)
    files, rejected = {}, []
    for location in roots:
        location = Path(location).expanduser()
        for path in ([location] if location.is_file() else sorted(location.rglob('*.jsonl'))):
            path = path.resolve()
            if path in files or path in rejected:
                continue
            for _, record in read_lines(path, collections.Counter()):
                if record.get('type') != 'session_meta':
                    continue
                p = record.get('payload') or {}
                if not isinstance(p, dict) or not isinstance(p.get('id'), str):
                    break
                source = p.get('source')
                sub = source.get('subagent', {}) if isinstance(source, dict) else {}
                spawn = sub.get('thread_spawn', {})
                parent = p.get('parent_thread_id') or spawn.get('parent_thread_id')
                guardian = sub.get('other') == 'guardian'
                files[path] = {
                    'thread_id': p['id'], 'session_id': p.get('session_id') or p['id'],
                    'parent_thread_id': parent,
                    'agent': p.get('agent_path') or spawn.get('agent_path') or
                             ('/guardian' if guardian else 'unknown-child' if parent or p.get('forked_from_id') else '/root'),
                    'cwd': p.get('cwd'), 'cli_version': p.get('cli_version'),
                    'fork_ordinal': p.get('subagent_history_start_ordinal'),
                    'forked': bool(p.get('forked_from_id') or parent or spawn),
                    'git': p.get('git') if isinstance(p.get('git'), dict) else {},
                    'created_at': p.get('timestamp') or record.get('timestamp'),
                    'selection_evidence': [],
                }
                break
            if path not in files:
                rejected.append(path)
    selected = set()
    for meta in files.values():
        evidence = meta['selection_evidence']
        if meta['cwd']:
            cwd = Path(meta['cwd']).expanduser().resolve()
            if any(beneath(cwd, root) for root in repo['roots']):
                evidence.append('registered_worktree_or_project_cwd')
            # Recognize an existing renamed/unregistered checkout by its Git directory.
            common = git(cwd, 'rev-parse', '--path-format=absolute', '--git-common-dir') if cwd.exists() else ''
            if common and repo['common'] == Path(common).resolve():
                evidence.append('shared_git_common_directory')
        if repository_key(meta['git'].get('repository_url')) in repo['remotes']:
            evidence.append('recorded_repository_identity')
        if evidence:
            selected.add(meta['thread_id'])
    while True:
        children = {m['thread_id'] for m in files.values() if m['parent_thread_id'] in selected}
        if children <= selected:
            break
        selected |= children
    for meta in files.values():
        if meta['parent_thread_id'] in selected:
            meta['selection_evidence'].append('explicit_parent_thread')
    return {p: m for p, m in files.items() if m['thread_id'] in selected}, files, rejected, repo
