"""Compile the nonshipping LM98 candidate with explicit local compiler/symbol inputs.

No downloads, deployments, credentials, CI changes, or live calls are performed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', required=True, type=Path, help='Folder containing alc.dll and analyzer DLLs')
    parser.add_argument('--dotnet', default='dotnet')
    parser.add_argument('--symbols', required=True, type=Path, help='Owned writable symbol cache with deployed dependency versions')
    parser.add_argument('--output', required=True, type=Path, help='Evidence/artifact directory outside the checkout')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    if output == repo or repo in output.parents:
        parser.error('Keep evidence outside the source checkout.')
    def git(*command):
        return subprocess.check_output(['git', *command], cwd=repo, text=True).strip()
    if git('status', '--porcelain'):
        parser.error('Commit the candidate first; exact-tip compilation requires a clean checkout.')
    sha = git('rev-parse', 'HEAD')
    output.mkdir(parents=True, exist_ok=True)
    args.symbols.mkdir(parents=True, exist_ok=True)
    projects = [('app', 'app'), ('test', 'test'), ('tools/lm98-live', 'native-harness')]
    for _, name in projects:
        (output / (name + '.app')).unlink(missing_ok=True)
    summary = {'candidateSha': sha, 'results': [], 'runtimeExecuted': 0, 'runtimePassed': 0}
    for folder, name in projects:
        project = repo / folder
        # AppSourceCop's mandatory Cloud target does not apply to an unshipped OnPrem HTTP handler.
        analyzers = ['CodeCop', 'UICop'] if name == 'native-harness' else ['CodeCop', 'UICop', 'AppSourceCop']
        command = [args.dotnet, str(args.compiler / 'alc.dll'), '/project:' + str(project),
                   '/packagecachepath:' + str(args.symbols), '/out:' + str(output / (name + '.app')),
                   '/errorlog:' + str(output / (name + '-diagnostics.json')), '/SourceCommit:' + sha]
        if (project / 'ruleset.json').exists():
            command.append('/ruleset:' + str(project / 'ruleset.json'))
        command += ['/analyzer:' + str(args.compiler / ('Microsoft.Dynamics.Nav.' + a + '.dll')) for a in analyzers]
        result = subprocess.run(command, capture_output=True, text=True)
        log = result.stdout + result.stderr
        (output / (name + '-compile.log')).write_text(log, encoding='utf-8')
        row = {'project': folder, 'sourceSha': sha, 'exitCode': result.returncode, 'analyzers': analyzers,
               'errors': len(re.findall(r'\berror [A-Z]+\d+', log)),
               'warnings': len(re.findall(r'\bwarning [A-Z]+\d+', log))}
        artifact = output / (name + '.app')
        if artifact.exists():
            row['packageSha256'] = hashlib.sha256(artifact.read_bytes()).hexdigest()
        summary['results'].append(row)
        (output / 'compile-summary.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
        print(json.dumps(row), flush=True)
        if result.returncode or row['errors'] or row['warnings']:
            return 1
        if name in ['app', 'test']:
            manifest = json.loads((project / 'app.json').read_text(encoding='utf-8'))
            destination = args.symbols / (manifest['publisher'] + '_' + manifest['name'] + '_' + manifest['version'] + '.app')
            shutil.copy2(artifact, destination)
    if git('status', '--porcelain') or git('rev-parse', 'HEAD') != sha:
        raise RuntimeError('Source changed during compilation; do not publish these artifacts.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
