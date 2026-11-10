#!/usr/bin/env python3
"""Package and notarize the verified five-page build for invited testers."""
import hashlib
import json
import os
import pathlib
import plistlib
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]


def run(*args, capture=False):
    return subprocess.run(args, cwd=ROOT, check=True, text=True,
                          stdout=subprocess.PIPE if capture else None).stdout


def main():
    profile = os.environ.get('POPUP_BOOK_NOTARY_PROFILE')
    if not profile or not os.environ.get('POPUP_BOOK_SIGNING_IDENTITY'):
        raise SystemExit('请配置 POPUP_BOOK_SIGNING_IDENTITY 和 POPUP_BOOK_NOTARY_PROFILE。')
    revision = run('git', 'rev-parse', 'HEAD', capture=True).strip()
    if run('git', 'status', '--porcelain', capture=True).strip():
        raise SystemExit('请从干净的候选源码提交打包。')
    source_hash = run('python3', 'scripts/write-build-receipt.py', '--source-hash', capture=True).strip()
    verification = ROOT / 'build/candidate-checks/result.json'
    if not verification.is_file():
        raise SystemExit('请先运行 bash scripts/verify-candidate.sh。')
    proof = json.loads(verification.read_text())
    if (proof['source_manifest_sha256'] != source_hash
            or proof['git'] != {'base_revision': revision, 'has_worktree_changes': False}
            or proof['checks'] != ['engineering', 'isolation', 'published']):
        raise SystemExit('验收凭据与当前干净提交不一致，请重新运行候选验收。')

    with (ROOT / 'Apps/BookHost/Packaging/Info.plist').open('rb') as info_file:
        info = plistlib.load(info_file)
    version = f'{info["CFBundleShortVersionString"]}-{info["CFBundleVersion"]}'
    output = ROOT / 'build/external-beta' / version
    if output.exists():
        raise SystemExit(f'候选版本已存在：{output}')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='candidate-', dir=output.parent) as temporary:
        staging = pathlib.Path(temporary) / 'deliverable'
        run('python3', 'scripts/book-build.py', '--distribution-dir', str(staging))
        app = staging / '开合之间.app'
        submission = pathlib.Path(temporary) / 'notarization.zip'
        run('ditto', '-c', '-k', '--keepParent', str(app), str(submission))
        result = json.loads(run(
            'xcrun', 'notarytool', 'submit', str(submission), '--keychain-profile', profile,
            '--wait', '--output-format', 'json', capture=True))
        if result.get('status') != 'Accepted':
            raise SystemExit(f'候选包公证未通过，状态为 {result.get("status", "未知")}。')
        run('xcrun', 'stapler', 'staple', str(app))
        run('xcrun', 'stapler', 'validate', str(app))
        run('codesign', '--verify', '--deep', '--strict', str(app))
        run('spctl', '--assess', '--type', 'execute', str(app))
        archive = staging / f'KaiHe-{version}-macOS.zip'
        run('ditto', '-c', '-k', '--keepParent', str(app), str(archive))
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        archive.with_suffix('.zip.sha256').write_text(f'{digest}  {archive.name}\n')
        run('python3', 'scripts/write-build-receipt.py', '--app', str(app),
            '--output', str(staging / 'build-receipt.json'))
        receipt = json.loads((staging / 'build-receipt.json').read_text())
        if (receipt['source_manifest_sha256'] != source_hash
                or receipt['git'] != proof['git']):
            raise SystemExit('打包过程中源码发生变化，候选未发布。')
        shutil.copy2(verification, staging / 'verification.json')
        (staging / '试用说明.md').write_text(
            '# 《开合之间》五页试用\n\n'
            '适用于搭载 Apple 芯片、运行 macOS 14 或更新版本的 Mac。'
            '解压后将《开合之间》拖入「应用程序」，双击打开。\n\n'
            '缓慢抬起屏幕，或点「改用手动」后拖动展开滑块。'
            '在林间小屋试着轻抚纸猫，再从目录打开另一页。\n\n'
            '请记录你的机型、系统版本、首次成功互动用时、误点和阻断。'
            '可在窗口中关闭声音。\n', encoding='utf-8')
        shutil.rmtree(app)
        staging.rename(output)
    print(f'已生成受邀试用候选包：{output}')


if __name__ == '__main__':
    main()
