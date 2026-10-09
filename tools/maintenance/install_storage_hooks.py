"""Install repository-wide commit/push guards on macOS, Linux or Git for Windows.
Run once per clone with Python 3. Preserves unrelated custom hooks.
"""
from pathlib import Path
import shlex
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
MARKER = '# TheLastMonsoon regular-Git storage guard'


def main():
    custom = subprocess.run(['git', 'config', '--get', 'core.hooksPath'], cwd=ROOT,
                            capture_output=True, text=True)
    if custom.returncode == 0:
        raise SystemExit('Existing core.hooksPath preserved; add check_push_sizes.py to your custom hooks.')
    raw = subprocess.check_output(['git', 'rev-parse', '--git-path', 'hooks'], cwd=ROOT, text=True).strip()
    folder = Path(raw)
    if not folder.is_absolute():
        folder = ROOT / folder
    hooks = {'pre-commit': '--index', 'pre-push': '--pre-push "$1"'}
    legacy = '#!/bin/sh\nrepo_root=$(git rev-parse --show-toplevel) || exit 1\nexec python3 "$repo_root/tools/maintenance/check_push_sizes.py" --index\n'
    for name in hooks:
        path = folder / name
        if path.exists() and MARKER not in path.read_text() and path.read_text() != legacy:
            raise SystemExit('Custom ' + name + ' preserved; integrate the checker manually.')
    folder.mkdir(parents=True, exist_ok=True)
    interpreter = shlex.quote(Path(sys.executable).as_posix())
    for name, argument in hooks.items():
        path = folder / name
        path.write_text('#!/bin/sh\n' + MARKER + '\n'
                        'repo_root=$(git rev-parse --show-toplevel) || exit 1\n'
                        'exec ' + interpreter + ' "$repo_root/tools/maintenance/check_push_sizes.py" '
                        + argument + '\n', newline='\n')
        path.chmod(0o755)
    print('Installed commit and push guards. Run this command once per fresh clone.')


if __name__ == '__main__':
    main()
