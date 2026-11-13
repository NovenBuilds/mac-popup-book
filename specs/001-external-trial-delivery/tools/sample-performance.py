#!/usr/bin/env python3
"""前台性能采样工具。放在规格目录，不进入候选源码指纹。

正式 30 分钟测量须在独立测试账户中、从重新启动《开合之间》开始，
与 US1 分开，不要接在同一轮开合后面继续计时。
本工具不启动应用。未获得账户声明或日常存档同意时，不读取存档目录。
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import platform
import resource
import signal
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone


BUNDLE_ID = 'local.ssr.forestbook'
APP_NAME = '开合之间'
HOST_EXEC = 'ForestBook'
SAVE_RELATIVE = (
    'Library/Application Support/local.ssr.forestbook/'
    'pages/mechanical-planetarium/state.json'
)
DEFAULT_DURATION = 30 * 60
DEFAULT_INTERVAL = 15
DEFAULT_OUTPUT = pathlib.Path('build/candidate-checks/manual/performance-session.json')
SLEEP_SLACK_SECONDS = 2.0
DURATION_SLACK_SECONDS = 1.0

USAGE_EPILOG = f"""
正式 30 分钟会话须先完全退出应用，再重新打开验收包里的《开合之间》
（不要用场景预览）。不要接在 US1 开合同一轮后面计时。优先使用独立
macOS 测试账户。应用标识 {BUNDLE_ID}，界面语言简体中文（zh-Hans-CN）。
远程 CI 的临时签名包不是公证试用包，核对 SHA-256 后可用右键打开。

从仓库根目录复制执行：

  python3 specs/001-external-trial-delivery/tools/sample-performance.py \\
    --session --account independent \\
    --output build/candidate-checks/manual/performance-session.json

工具自检（不打开应用，不读存档）：

  python3 specs/001-external-trial-delivery/tools/sample-performance.py --self-test \\
    --output build/candidate-checks/manual/tool-self-test.json

不要用 sudo 运行本脚本，以免看错主目录。没有超级用户授权时，本工具
采不到瓦特数，只记录电池或电源状态（若可读）。若要另采瓦特，请在
静置阶段于另一终端运行 powermetrics，把输出放到同一证据目录。
""".strip()


def run_command(command, timeout=8):
    try:
        return subprocess.run(
            command, check=False, text=True, capture_output=True, timeout=timeout)
    except FileNotFoundError:
        return subprocess.CompletedProcess(command, 127, '', f'找不到命令：{command[0]}')
    except subprocess.TimeoutExpired as error:
        stdout = error.stdout.decode() if isinstance(error.stdout, bytes) else (error.stdout or '')
        stderr = error.stderr.decode() if isinstance(error.stderr, bytes) else (error.stderr or '')
        return subprocess.CompletedProcess(command, 124, stdout, stderr or '命令超时')


def rss_bytes():
    value = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    # Linux 为千字节，macOS 为字节。
    if sys.platform == 'darwin':
        return value
    return value * 1024


def process_rss(pid):
    result = run_command(['ps', '-p', str(pid), '-o', 'rss='])
    text = result.stdout.strip()
    if result.returncode != 0 or not text:
        return None
    try:
        return int(text.split()[0]) * 1024
    except ValueError:
        return None


def display_resolution():
    result = run_command(['system_profiler', 'SPDisplaysDataType'], timeout=30)
    if result.returncode != 0:
        return []
    lines = []
    for line in result.stdout.splitlines():
        if 'Resolution:' in line or 'Display Type:' in line:
            lines.append(line.strip())
    return lines


def probe_pmset():
    probes = []
    for command in (
        ['pmset', '-g', 'batt'],
        ['pmset', '-g', 'therm'],
    ):
        result = run_command(command)
        probes.append({
            'command': ' '.join(command),
            'returncode': result.returncode,
            'available': result.returncode == 0 and bool(result.stdout.strip()),
            'excerpt': '\n'.join(result.stdout.splitlines()[:8]),
        })
    return probes


def probe_watts():
    watts = run_command(
        ['powermetrics', '-n', '1', '-i', '300', '--samplers', 'cpu_power,gpu_power'],
        timeout=8)
    return {
        'command': 'powermetrics -n 1 -i 300 --samplers cpu_power,gpu_power',
        'returncode': watts.returncode,
        'available': watts.returncode == 0 and 'Unable' not in (watts.stderr or '')
        and 'must be invoked as the superuser' not in (watts.stderr or ''),
        'excerpt': '\n'.join(((watts.stderr or '') or watts.stdout).splitlines()[:6]),
    }


def probe_power(include_watts=True):
    probes = probe_pmset()
    if include_watts:
        probes.append(probe_watts())
    return probes


def watts_available(probes):
    return any(
        item['command'].startswith('powermetrics') and item['available']
        for item in probes)


def snapshot_file(path):
    path = pathlib.Path(path)
    if not path.exists() or not path.is_file():
        return None
    data = path.read_bytes()
    return hashlib.sha256(data).hexdigest(), path.stat().st_mtime_ns


class SaveWatcher:
    """统计主存档成功替换。只能看到时间变化时标为估计值。"""

    def __init__(self, directory):
        directory = pathlib.Path(directory)
        self.primary = directory / 'state.json'
        self.backup = directory / 'state.json.backup'
        self.seen = {
            self.primary: snapshot_file(self.primary),
            self.backup: snapshot_file(self.backup),
        }
        self.counts = {
            'primary_replacement_count': 0,
            'backup_change_count': 0,
            'count_quality': '精确',
        }

    def poll(self):
        for path, key in (
            (self.primary, 'primary_replacement_count'),
            (self.backup, 'backup_change_count'),
        ):
            current = snapshot_file(path)
            previous = self.seen[path]
            if current is None or current == previous:
                continue
            if previous is not None and current[0] == previous[0]:
                self.counts['count_quality'] = '估计值'
                self.seen[path] = current
                continue
            self.counts[key] += 1
            self.seen[path] = current
        return dict(self.counts)


def watch_saves(directory, replacements, backup_writes):
    watcher = SaveWatcher(directory)
    directory = pathlib.Path(directory)
    primary = directory / 'state.json'
    backup = directory / 'state.json.backup'
    for index in range(replacements):
        payload = json.dumps({'turn': index}).encode()
        temporary = directory / f'.state-{index}.tmp'
        temporary.write_bytes(payload)
        os.replace(temporary, primary)
        if index < backup_writes:
            backup.write_bytes(payload)
        watcher.poll()
    return watcher.counts


def wall_clock_text():
    return datetime.now().astimezone().isoformat(timespec='seconds')


def sleep_detected(wall_start, mono_start, wall_now, mono_now, slack=SLEEP_SLACK_SECONDS):
    return (wall_now - wall_start) - (mono_now - mono_start) > slack


def lid_closed():
    result = run_command(['ioreg', '-r', '-k', 'AppleClamshellState'], timeout=8)
    if result.returncode != 0 or 'AppleClamshellState' not in result.stdout:
        return None
    for line in result.stdout.splitlines():
        if 'AppleClamshellState' not in line:
            continue
        if 'Yes' in line:
            return True
        if 'No' in line:
            return False
    return None


def machine_info():
    info = {
        'platform': sys.platform,
        'platform_version': platform.version(),
        'python': sys.version.split()[0],
    }
    sw = run_command(['sw_vers'])
    if sw.returncode == 0 and sw.stdout.strip():
        info['sw_vers'] = sw.stdout.strip()
    model = run_command(['sysctl', '-n', 'hw.model'])
    if model.returncode == 0 and model.stdout.strip():
        info['model'] = model.stdout.strip()
    languages = run_command(['defaults', 'read', '-g', 'AppleLanguages'])
    if languages.returncode == 0 and languages.stdout.strip():
        info['apple_languages'] = languages.stdout.strip()
    locale = run_command(['defaults', 'read', '-g', 'AppleLocale'])
    if locale.returncode == 0 and locale.stdout.strip():
        info['apple_locale'] = locale.stdout.strip()
    return info


def parse_ps(text):
    rows = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        parts = stripped.split(None, 3)
        if len(parts) < 4:
            continue
        try:
            rows.append({
                'pid': int(parts[0]),
                'ppid': int(parts[1]),
                'rss_bytes': int(parts[2]) * 1024,
                'command': parts[3],
            })
        except ValueError:
            continue
    return rows


def bundle_from_command(command):
    marker = f'{APP_NAME}.app'
    index = command.find(marker)
    if index < 0:
        return None
    return command[:index + len(marker)]


def read_bundle_id(bundle):
    plist = pathlib.Path(bundle) / 'Contents' / 'Info.plist'
    try:
        info = plistlib_load(plist)
    except (OSError, ValueError, TypeError):
        return None
    return info.get('CFBundleIdentifier')


def plistlib_load(path):
    import plistlib
    return plistlib.loads(pathlib.Path(path).read_bytes())


def list_processes():
    result = run_command(['ps', '-ax', '-o', 'pid=,ppid=,rss=,command='], timeout=8)
    if result.returncode != 0:
        return []
    return parse_ps(result.stdout)


def official_host_command(command, bundle=None):
    if f'{APP_NAME}.app/Contents/MacOS/{HOST_EXEC}' not in command:
        return False
    found = bundle_from_command(command)
    if bundle and found and os.path.realpath(found) != os.path.realpath(bundle):
        return False
    return True


def find_official_targets(preferred_bundle=None, extra_pid=None):
    rows = list_processes()
    hosts = []
    for row in rows:
        if not official_host_command(row['command'], preferred_bundle):
            continue
        bundle = bundle_from_command(row['command'])
        identifier = read_bundle_id(bundle) if bundle else None
        if identifier != BUNDLE_ID:
            continue
        hosts.append({**row, 'bundle': bundle, 'bundle_id': identifier, 'role': 'host'})
    if preferred_bundle:
        wanted = os.path.realpath(preferred_bundle)
        hosts = [item for item in hosts if item.get('bundle') and os.path.realpath(item['bundle']) == wanted]
    if not hosts and extra_pid is not None:
        return None, [], 'dry-run 或测试进程'
    if len(hosts) > 1:
        bundles = sorted({item['bundle'] for item in hosts})
        if len(bundles) > 1:
            return None, [], f'找到多个正式应用，请用 --app 指定：{bundles}'
    if not hosts:
        return None, [], f'没有正在运行的正式应用 {APP_NAME}（{BUNDLE_ID}）'
    host = hosts[0]
    bundle = host['bundle']
    workers = []
    marker = f'{APP_NAME}.app/Contents/XPCServices/'
    real_bundle = os.path.realpath(bundle)
    for row in rows:
        found = bundle_from_command(row['command'])
        if marker not in row['command'] or not found:
            continue
        if os.path.realpath(found) != real_bundle:
            continue
        workers.append({**row, 'bundle': found, 'role': 'worker'})
    return host, workers, None


def sample_memory(host, workers):
    processes = []
    total = 0
    missing = []
    targets = [host] + workers if host else list(workers)
    for item in targets:
        rss = process_rss(item['pid'])
        entry = {
            'pid': item['pid'],
            'role': item.get('role', 'process'),
            'command': item.get('command'),
            'rss_bytes': rss,
        }
        processes.append(entry)
        if rss is None:
            missing.append(item['pid'])
        else:
            total += rss
    return {
        'total_rss_bytes': total if not missing or total else None,
        'missing_pids': missing,
        'processes': processes,
    }


def planetarium_directory():
    return pathlib.Path.home() / SAVE_RELATIVE.rsplit('/state.json', 1)[0]


def classify_session(report):
    reasons = list(report.get('invalidation_reasons') or [])
    scheduled = report.get('duration_scheduled_seconds') or 0
    observed = report.get('duration_observed_seconds') or 0
    is_official_duration = scheduled + DURATION_SLACK_SECONDS >= DEFAULT_DURATION
    if report.get('dry_run'):
        reasons = _append_reason(reasons, '这是短时演练，不能当作 30 分钟结果')
    if not is_official_duration:
        reasons = _append_reason(reasons, '不足 30 分钟，不能当作 30 分钟结果')
    elif observed + DURATION_SLACK_SECONDS < scheduled:
        reasons = _append_reason(reasons, '记录被提前结束，不能当作 30 分钟结果')
    complete = (
        not reasons
        and is_official_duration
        and observed + DURATION_SLACK_SECONDS >= scheduled
        and report.get('official_app_confirmed') is True
    )
    return complete, reasons


def _append_reason(reasons, item):
    if item not in reasons:
        reasons.append(item)
    return reasons


def summarize_memory(samples):
    totals = [item['memory']['total_rss_bytes'] for item in samples
              if item.get('memory') and item['memory'].get('total_rss_bytes') is not None]
    if not totals:
        return None
    mid = totals[len(totals) // 2]
    return {
        'start_bytes': totals[0],
        'mid_bytes': mid,
        'end_bytes': totals[-1],
        'min_bytes': min(totals),
        'max_bytes': max(totals),
        'sample_count': len(totals),
    }


def write_report(path, report):
    text = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
    if path:
        path = pathlib.Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        summary = path.with_name(path.stem + '-summary.md')
        summary.write_text(render_summary(report), encoding='utf-8')
    return text


def render_summary(report):
    memory = report.get('memory_trend') or {}
    saves = report.get('save_counter')
    power = report.get('watt_sample_available')
    lines = [
        '# 前台性能采样摘要',
        '',
        f"- 开始：{report.get('started_at')}",
        f"- 结束：{report.get('ended_at')}",
        f"- 计划时长：{report.get('duration_scheduled_seconds')} 秒",
        f"- 实际时长：{round(report.get('duration_observed_seconds') or 0, 1)} 秒",
        f"- 会话完整：{'是' if report.get('session_complete') else '否'}",
    ]
    if report.get('invalidation_reasons'):
        lines.append('- 无效或未完成原因：' + '；'.join(report['invalidation_reasons']))
    if report.get('bundle_id'):
        lines.append(f"- 应用标识：{report['bundle_id']}")
    if report.get('app_bundle'):
        lines.append(f"- 应用包：{report['app_bundle']}")
    if report.get('display_start') is not None:
        lines.append('- 起始分辨率：' + (', '.join(report['display_start']) or '未读到'))
        lines.append('- 结束分辨率：' + (', '.join(report.get('display_end') or []) or '未读到'))
    if memory:
        lines.append(
            '- 内存（字节）：起始 {start_bytes}，中间 {mid_bytes}，结束 {end_bytes}，'
            '最低 {min_bytes}，最高 {max_bytes}，样本 {sample_count}'.format(**memory))
    if saves is None:
        skipped = report.get('save_watch_skipped') or '未监视存档'
        lines.append(f'- 天文馆存档：本次未监视（{skipped}）')
    else:
        lines.append(
            f"- 天文馆主存档成功替换：{saves.get('primary_replacement_count')}，"
            f"备份变化：{saves.get('backup_change_count')}，计数质量：{saves.get('count_quality')}")
    lines.append('- 瓦特功耗：' + ('已采到' if power else '未采到，本项保持待验收'))
    lines.append('- 首次翻页耗时和前台画面更新耗时需人工计时，本工具不代填。')
    lines.append('- 原始证据不要提交到仓库。观察结论回写 performance-session.md。')
    lines.append('')
    return '\n'.join(lines)


def logic_tests():
    results = {}
    with tempfile.TemporaryDirectory(prefix='popup-save-self-test-') as temporary:
        saves = watch_saves(temporary, replacements=2, backup_writes=1)
    results['save_counter_matches_fixture'] = saves == {
        'primary_replacement_count': 2,
        'backup_change_count': 1,
        'count_quality': '精确',
    }
    with tempfile.TemporaryDirectory(prefix='popup-save-mtime-') as temporary:
        watcher = SaveWatcher(temporary)
        path = pathlib.Path(temporary) / 'state.json'
        path.write_bytes(b'{"a":1}')
        watcher.poll()
        os.utime(path, ns=(path.stat().st_mtime_ns + 1_000_000, path.stat().st_mtime_ns + 1_000_000))
        watcher.poll()
        results['mtime_only_is_estimate'] = watcher.counts['primary_replacement_count'] == 1 \
            and watcher.counts['count_quality'] == '估计值'

    short = {
        'duration_scheduled_seconds': 8,
        'duration_observed_seconds': 8,
        'invalidation_reasons': [],
        'official_app_confirmed': True,
        'dry_run': True,
    }
    complete, reasons = classify_session(short)
    results['short_dry_run_not_complete'] = complete is False and any('不能当作 30 分钟' in item for item in reasons)

    official = {
        'duration_scheduled_seconds': DEFAULT_DURATION,
        'duration_observed_seconds': DEFAULT_DURATION,
        'invalidation_reasons': [],
        'official_app_confirmed': True,
        'dry_run': False,
    }
    complete, reasons = classify_session(official)
    results['full_session_complete'] = complete is True and not reasons

    interrupted = dict(official, duration_observed_seconds=600,
                       invalidation_reasons=['会话被中断'])
    complete, reasons = classify_session(interrupted)
    results['interrupted_not_complete'] = complete is False and '会话被中断' in reasons

    slept = dict(official, invalidation_reasons=['检测到睡眠或合盖，会话作废'])
    complete, _ = classify_session(slept)
    results['sleep_not_complete'] = complete is False

    resolved = dict(official, invalidation_reasons=['分辨率在会话中发生变化'])
    complete, _ = classify_session(resolved)
    results['resolution_change_not_complete'] = complete is False

    results['sleep_detector_flags_wall_jump'] = sleep_detected(0, 0, 10, 3) is True
    results['sleep_detector_accepts_aligned_clocks'] = sleep_detected(0, 0, 10, 10) is False
    return results


def self_test():
    before = rss_bytes()
    blob = b'x' * (2 * 1024 * 1024)
    sink = hashlib.sha256(blob).hexdigest()
    after = rss_bytes()
    clock_started = time.perf_counter()
    time.sleep(0.05)
    elapsed = time.perf_counter() - clock_started
    with tempfile.TemporaryDirectory(prefix='popup-save-self-test-') as temporary:
        saves = watch_saves(temporary, replacements=2, backup_writes=1)
    power = probe_power()
    watts_ready = watts_available(power)
    logic = logic_tests()
    profiler_exists = run_command(['bash', '-lc', 'command -v system_profiler']).returncode == 0
    display = display_resolution()
    report = {
        'memory_rss_before_bytes': before,
        'memory_rss_after_bytes': after,
        'memory_increased': after >= before,
        'process_rss_bytes': process_rss(os.getpid()),
        'clock_sleep_seconds': elapsed,
        'clock_usable': 0.04 <= elapsed <= 0.2,
        'display': display,
        'display_probe_present': profiler_exists,
        'save_counter': saves,
        'save_counter_matches_fixture': logic['save_counter_matches_fixture'],
        'power_probes': power,
        'watt_sample_available': watts_ready,
        'logic_tests': logic,
        'logic_tests_passed': all(logic.values()),
        'ignored_digest': sink,
    }
    report['ready_for_session'] = all((
        report['memory_increased'] or report['process_rss_bytes'],
        report['clock_usable'],
        report['save_counter_matches_fixture'],
        report['logic_tests_passed'],
        bool(report['display']) if profiler_exists else True,
    ))
    report['self_test_passed'] = report['logic_tests_passed'] and (
        report['ready_for_session'] if sys.platform == 'darwin' else True)
    return report


class SessionStop(Exception):
    def __init__(self, reason):
        super().__init__(reason)
        self.reason = reason


def run_session(args):
    dry_run = args.dry_run
    duration = args.duration if args.duration is not None else (8 if dry_run else DEFAULT_DURATION)
    interval = args.interval if args.interval is not None else (2 if dry_run else DEFAULT_INTERVAL)
    if interval <= 0 or duration <= 0:
        raise SystemExit('时长和间隔必须大于 0')
    if not dry_run and duration + DURATION_SLACK_SECONDS < DEFAULT_DURATION:
        print('警告：本次计划时长不足 30 分钟，结果不能当作正式 US2 记录。', file=sys.stderr)

    preferred_bundle = str(args.app.resolve()) if args.app else None
    extra_pid = args.pid
    if dry_run and extra_pid is None:
        extra_pid = os.getpid()

    host, workers, error = (None, [], None)
    official = False
    if not dry_run:
        host, workers, error = wait_for_app(preferred_bundle, args.wait_for_app)
        if error:
            raise SystemExit(error)
        official = True
    else:
        found, found_workers, found_error = find_official_targets(preferred_bundle)
        if found:
            host, workers, error = found, found_workers, found_error
            official = True
        else:
            rss = process_rss(extra_pid)
            if rss is None:
                raise SystemExit(f'找不到用于演练的进程 {extra_pid}')
            command = f'python3 (dry-run pid {extra_pid})'
            host = {
                'pid': extra_pid,
                'ppid': os.getppid(),
                'rss_bytes': rss,
                'command': command,
                'bundle': None,
                'bundle_id': None,
                'role': 'host',
            }
            workers = []

    watch_saves_allowed = False
    save_skip_reason = None
    if dry_run and not args.account:
        save_skip_reason = '短时演练默认不监视存档'
    elif args.account == 'independent':
        watch_saves_allowed = True
    elif args.account == 'daily':
        if args.consent_daily_store:
            watch_saves_allowed = True
        else:
            save_skip_reason = '日常账户未给出 --consent-daily-store，不读取存档目录'
    else:
        save_skip_reason = '未声明 --account independent 或 daily，不读取存档目录'

    watcher = SaveWatcher(planetarium_directory()) if watch_saves_allowed else None
    output = args.output or DEFAULT_OUTPUT
    invalidation = []
    if dry_run:
        invalidation.append('这是短时演练，不能当作 30 分钟结果')

    def request_stop(signum, _frame):
        raise SessionStop('会话被中断')

    display_start = display_resolution()
    last_display = display_start
    info = machine_info()
    power_marks = [power_mark('start', include_watts=False)]
    mid_power_taken = False
    samples = []
    started_wall = time.time()
    started_mono = time.monotonic()
    report = {
        'tool': 'specs/001-external-trial-delivery/tools/sample-performance.py',
        'mode': 'dry-run' if dry_run else 'session',
        'dry_run': dry_run,
        'bundle_id': host.get('bundle_id') if host else None,
        'app_bundle': host.get('bundle') if host else None,
        'official_app_confirmed': official and host is not None and host.get('bundle_id') == BUNDLE_ID,
        'account_kind': args.account,
        'daily_store_consent': bool(args.consent_daily_store) if args.account == 'daily' else (
            '不适用' if args.account == 'independent' else False),
        'machine': info,
        'display_start': display_start,
        'duration_scheduled_seconds': duration,
        'interval_seconds': interval,
        'started_at': wall_clock_text(),
        'invalidation_reasons': invalidation,
        'manual_fields': {
            'first_page_turn_seconds': None,
            'foreground_frame_update_seconds': None,
            'note': '这两项需人工计时，本工具只采样内存、可选功耗和天文馆存档次数。',
        },
        'save_watch_path': str(planetarium_directory() / 'state.json') if watcher else None,
        'save_watch_skipped': save_skip_reason,
    }
    if report['official_app_confirmed'] is False and not dry_run:
        raise SystemExit('未确认正式应用，已停止。不要对场景预览采样。')

    previous_handler_int = signal.signal(signal.SIGINT, request_stop)
    previous_handler_term = signal.signal(signal.SIGTERM, request_stop)
    next_sample = started_mono
    display_every = max(interval, 60)
    next_display = started_mono
    try:
        while True:
            now_mono = time.monotonic()
            now_wall = time.time()
            if sleep_detected(started_wall, started_mono, now_wall, now_mono):
                _append_reason(invalidation, '检测到睡眠或合盖，会话作废')
                raise SessionStop('检测到睡眠或合盖，会话作废')
            closed = lid_closed()
            if closed is True:
                _append_reason(invalidation, '检测到睡眠或合盖，会话作废')
                raise SessionStop('检测到睡眠或合盖，会话作废')
            if now_mono + 0.05 >= next_sample:
                if official:
                    current_host, current_workers, current_error = find_official_targets(
                        host.get('bundle') if host else preferred_bundle)
                    if current_error or current_host is None:
                        _append_reason(invalidation, '正式应用在会话中退出')
                        raise SessionStop('正式应用在会话中退出')
                    host, workers = current_host, current_workers
                memory = sample_memory(host, workers)
                if watcher:
                    saves_now = watcher.poll()
                else:
                    saves_now = None
                elapsed = now_mono - started_mono
                sample = {
                    'elapsed_seconds': round(elapsed, 3),
                    'timestamp': wall_clock_text(),
                    'memory': memory,
                    'save_counter': saves_now,
                    'lid_closed': closed,
                }
                if now_mono >= next_display:
                    current_display = display_resolution()
                    if current_display and display_start and current_display != display_start:
                        _append_reason(invalidation, '分辨率在会话中发生变化')
                        sample['display'] = current_display
                        last_display = current_display
                        samples.append(sample)
                        raise SessionStop('分辨率在会话中发生变化')
                    sample['display'] = current_display
                    last_display = current_display or last_display
                    next_display = now_mono + display_every
                samples.append(sample)
                if not mid_power_taken and elapsed >= duration / 2:
                    power_marks.append(power_mark('mid', include_watts=False))
                    mid_power_taken = True
                host_rss = memory['processes'][0]['rss_bytes'] if memory['processes'] else None
                print(
                    f"[{sample['timestamp']}] 已采样 {len(samples)} 次，"
                    f"已过 {elapsed:.0f}/{duration} 秒，"
                    f"内存 {memory['total_rss_bytes']} 字节"
                    + (f'（主进程 {host_rss}）' if host_rss is not None else ''),
                    flush=True)
                next_sample = started_mono + len(samples) * interval
            remaining = min(duration - (time.monotonic() - started_mono), next_sample - time.monotonic())
            if time.monotonic() - started_mono >= duration:
                break
            if remaining > 0:
                time.sleep(min(remaining, 0.5))
        # 结束时再采一次电源和分辨率
    except SessionStop as stop:
        _append_reason(invalidation, stop.reason)
    finally:
        signal.signal(signal.SIGINT, previous_handler_int)
        signal.signal(signal.SIGTERM, previous_handler_term)

    ended_mono = time.monotonic()
    ended_wall = time.time()
    if sleep_detected(started_wall, started_mono, ended_wall, ended_mono):
        _append_reason(invalidation, '检测到睡眠或合盖，会话作废')
    display_end = last_display if last_display is not None else display_resolution()
    if display_start and display_end and display_end != display_start:
        _append_reason(invalidation, '分辨率在会话中发生变化')
    if not mid_power_taken:
        power_marks.append(power_mark('mid', include_watts=False))
    power_marks.append(power_mark('end', include_watts=True))
    report.update({
        'ended_at': wall_clock_text(),
        'duration_observed_seconds': ended_mono - started_mono,
        'display_end': display_end,
        'samples': samples,
        'memory_trend': summarize_memory(samples),
        'save_counter': watcher.poll() if watcher else None,
        'power_marks': power_marks,
        'watt_sample_available': any(watts_available(item['probes']) for item in power_marks),
        'invalidation_reasons': invalidation,
        'power_note': '开始和中间只读 pmset；结束时尝试一次 powermetrics。无超级用户时通常没有瓦特数，不要用 sudo 运行本脚本。',
    })
    complete, reasons = classify_session(report)
    report['invalidation_reasons'] = reasons
    report['session_complete'] = complete
    text = write_report(output, report)
    sys.stdout.write(text)
    if output:
        print(f'已写入 {output} 和 {pathlib.Path(output).with_name(pathlib.Path(output).stem + "-summary.md")}',
              file=sys.stderr)
    return 0 if complete or dry_run else 1


def wait_for_app(preferred_bundle, wait_seconds):
    deadline = time.monotonic() + max(0, wait_seconds or 0)
    last_error = None
    while True:
        host, workers, error = find_official_targets(preferred_bundle)
        if host is not None:
            return host, workers, None
        last_error = error
        if time.monotonic() >= deadline:
            hint = last_error or '没有正在运行的正式应用'
            if wait_seconds:
                hint += f'（已等待 {wait_seconds} 秒）'
            hint += '。请先重新打开验收包中的《开合之间》，再运行本工具。'
            return None, [], hint
        print('尚未看到正式应用，等待启动…', flush=True)
        time.sleep(2)


def power_mark(label, include_watts=False):
    return {
        'label': label,
        'timestamp': wall_clock_text(),
        'probes': probe_power(include_watts=include_watts),
    }


def main():
    parser = argparse.ArgumentParser(
        description='《开合之间》前台 30 分钟性能采样工具。',
        epilog=USAGE_EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--self-test', action='store_true', help='运行自检，不打开应用，不读存档')
    parser.add_argument('--session', action='store_true', help='对正在运行的正式应用做前台会话采样')
    parser.add_argument('--dry-run', action='store_true', help='短时演练采样流程，不能当作 30 分钟结果')
    parser.add_argument('--account', choices=['independent', 'daily'],
                        help='independent：独立测试账户；daily：日常账户，须同时给出同意')
    parser.add_argument('--consent-daily-store', action='store_true',
                        help='仅当 --account daily 且你明确同意时，才监视日常账户的天文馆存档')
    parser.add_argument('--duration', type=int, help=f'会话秒数，正式测量为 {DEFAULT_DURATION}')
    parser.add_argument('--interval', type=int, help=f'内存采样间隔秒数，默认 {DEFAULT_INTERVAL}')
    parser.add_argument('--output', type=pathlib.Path, help='JSON 输出路径')
    parser.add_argument('--app', type=pathlib.Path, help='正式应用包路径，用于排除预览包')
    parser.add_argument('--pid', type=int, help='仅短时演练使用的进程号')
    parser.add_argument('--wait-for-app', type=int, default=60,
                        help='等待正式应用出现的秒数，默认 60；0 表示不等待')
    args = parser.parse_args()
    selected = sum(bool(item) for item in (args.self_test, args.session, args.dry_run))
    if selected != 1:
        parser.error('请指定 --session、--self-test 或 --dry-run 之一。正式测量用 --session。')
    if args.account == 'daily' and not args.consent_daily_store:
        parser.error('使用日常账户时必须同时给出 --consent-daily-store；否则请改用独立测试账户。')
    if args.consent_daily_store and args.account != 'daily':
        parser.error('--consent-daily-store 只能与 --account daily 一起使用')
    if args.self_test:
        report = self_test()
        text = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(text)
        sys.stdout.write(text)
        return 0 if report['self_test_passed'] else 1
    if args.session and not args.account and not args.dry_run:
        parser.error('正式会话须声明 --account independent，或在明确同意后使用 --account daily --consent-daily-store')
    return run_session(args)


if __name__ == '__main__':
    raise SystemExit(main())
