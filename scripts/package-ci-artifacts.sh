#!/bin/bash
# 整理 GitHub Actions 候选产物：验收日志、构建凭据和可下载的应用压缩包。
# 失败时仍尽量收集已有日志，不把缺失的应用写成成功。
set -euo pipefail
cd "$(dirname "$0")/.."
out=build/ci-artifacts
evidence="$out/evidence"
rm -rf "$out"
mkdir -p "$evidence/logs"

sha=$(git rev-parse HEAD)
short=$(git rev-parse --short=12 HEAD)
dirty=$(git status --porcelain || true)
version=$(python3 - <<'PY'
import pathlib
import plistlib

info = plistlib.loads(pathlib.Path('Apps/BookHost/Packaging/Info.plist').read_bytes())
app_info = pathlib.Path('build/开合之间.app/Contents/Info.plist')
if app_info.is_file():
    info = plistlib.loads(app_info.read_bytes())
print(f'{info["CFBundleShortVersionString"]}-{info["CFBundleVersion"]}')
PY
)

app=build/开合之间.app
archive_name=
archive_sha=
if [[ -d $app ]]; then
    archive_name="KaiHe-${version}-${short}-macOS.zip"
    ditto -c -k --keepParent "$app" "$out/$archive_name"
    archive_sha=$(python3 - <<PY
import hashlib, pathlib
print(hashlib.sha256(pathlib.Path("$out/$archive_name").read_bytes()).hexdigest())
PY
)
fi

if [[ -f build/build-receipt.json ]]; then
    cp build/build-receipt.json "$evidence/build-receipt.json"
fi
if [[ -f build/candidate-checks/result.json ]]; then
    cp build/candidate-checks/result.json "$evidence/result.json"
fi
if [[ -d build/candidate-checks ]]; then
    python3 - <<'PY'
import pathlib
import shutil
root = pathlib.Path('build/candidate-checks')
dest = pathlib.Path('build/ci-artifacts/evidence/logs')
for path in sorted(root.rglob('*.log')):
    name = '__'.join(path.relative_to(root).parts)
    shutil.copy2(path, dest / name)
PY
fi

python3 - "$sha" "$short" "$version" "${archive_name}" "${archive_sha}" "${GITHUB_SERVER_URL:-}" "${GITHUB_REPOSITORY:-}" "${GITHUB_RUN_ID:-}" "${GITHUB_SHA:-}" <<'PY'
import json
import os
import pathlib
import sys

sha, short, version, archive_name, archive_sha = sys.argv[1:6]
server, repo, run_id, github_sha = sys.argv[6:10]
receipt = {}
receipt_path = pathlib.Path('build/ci-artifacts/evidence/build-receipt.json')
if receipt_path.is_file():
    receipt = json.loads(receipt_path.read_text())
result = {}
result_path = pathlib.Path('build/ci-artifacts/evidence/result.json')
if result_path.is_file():
    result = json.loads(result_path.read_text())
run_url = ''
if server and repo and run_id:
    run_url = f'{server}/{repo}/actions/runs/{run_id}'
summary = {
    'git_revision': sha,
    'git_revision_short': short,
    'github_sha': github_sha or sha,
    'application_version': version,
    'application_archive': archive_name or None,
    'application_archive_sha256': archive_sha or None,
    'source_manifest_sha256': receipt.get('source_manifest_sha256'),
    'application_manifest_sha256': receipt.get('application_manifest_sha256'),
    'executable_sha256': receipt.get('executable_sha256'),
    'receipt_git': receipt.get('git'),
    'auto_checks': result.get('checks'),
    'workflow_run': run_url or None,
    'signing': '本地临时签名（codesign --sign -）。不是 Developer ID，也未经公证。',
    'scope': '证明工程检查、后台隔离和五页离屏集成，以及与该提交对应的可下载应用。不代表前台实测、物理开合、试听或对外试用通过。',
}
path = pathlib.Path('build/ci-artifacts/evidence/summary.json')
path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
lines = [
    f'# 候选产物摘要',
    '',
    f'- 提交：`{sha}`',
    f'- 版本：{version}',
    f'- 应用包：{archive_name or "未生成"}',
]
if archive_sha:
    lines.append(f'- 应用包 SHA-256：`{archive_sha}`')
if summary['source_manifest_sha256']:
    lines.append(f'- 源码清单 SHA-256：`{summary["source_manifest_sha256"]}`')
if summary['application_manifest_sha256']:
    lines.append(f'- 应用清单 SHA-256：`{summary["application_manifest_sha256"]}`')
if run_url:
    lines.append(f'- Actions 运行：{run_url}')
lines.append(f'- 签名：{summary["signing"]}')
lines.append(f'- 范围：{summary["scope"]}')
path.with_suffix('.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(f'已整理候选产物：{path}')
PY
