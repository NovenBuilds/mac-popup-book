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
import select
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

首次翻页和前台画面更新请按 records/performance-tools.md 的起止点计时。
推荐在 30 分钟会话进行时另开终端打点（--output 须与会话相同）：

  python3 specs/001-external-trial-delivery/tools/sample-performance.py \
    --mark-prompt \
    --output build/candidate-checks/manual/performance-session.json

也可一次写入一个点：--mark first-page-turn-start / first-page-turn-end，
或 --mark foreground-update-start / foreground-update-end。会话窗口若在
前台，也可输入 F 或 U 后回车打点。也可用秒表按同一口径记录。

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


def wall_clock_text():
    return datetime.now().astimezone().isoformat(timespec='seconds')


SAVE_POLL_QUALITY_REASON = (
    '本工具用定期轮询观察主存档和备份文件变化，不能逐次记录每一次成功写入，'
    '两次轮询之间的连续替换也可能被算成一次，因此计数一律为估计值。'
)

class SaveWatcher:
    """用定期轮询观察存档变化。只要走 poll()，计数一律为估计值。"""

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
            'count_quality': '估计值',
            'count_quality_reason': SAVE_POLL_QUALITY_REASON,
            'observation_method': 'poll',
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
            self.seen[path] = current
            self.counts['count_quality'] = '估计值'
            if previous is not None and current[0] == previous[0]:
                continue
            self.counts[key] += 1
        return dict(self.counts)


FOREGROUND_UPDATE_SAMPLE_COUNT = 5
MARK_KINDS = (
    'first-page-turn-start',
    'first-page-turn-end',
    'foreground-update-start',
    'foreground-update-end',
    'cancel-open',
)
MARK_KIND_ALIASES = {
    'f': 'first-page-turn-toggle',
    'F': 'first-page-turn-toggle',
    'u': 'foreground-update-toggle',
    'U': 'foreground-update-toggle',
    'c': 'cancel-open',
    'C': 'cancel-open',
    'q': 'quit',
    'Q': 'quit',
}
TIMING_PROTOCOL = {
    'first_page_turn': {
        'name': '首次翻页',
        'preparation': (
            'US2 须先完全退出再重新打开验收包，不要接在 US1 后面计时。'
            '等到顶部控制条左侧页名已是五页之一（林间小屋、口袋小镇、窗边小屋、'
            '海底剧场、机械天文馆），且「上一页」「下一页」可点，该页才算开场页就绪。'
            '若该账户刚做过 US1，开场页会恢复为上次所在页；否则是目录第一页「林间小屋」。'
            '启动后若短暂显示「开合之间」，等到变成五页之一再开始。'
            '计时前把书打开到半开或全开：底部「展开」百分比至少 20%，推荐 50% 或更高。'
            '低于约 12% 时翻页动画会停住。若开着「跟随屏幕」，铰链也须保持半开或全开；'
            '合盖会让整段 30 分钟会话作废。'
        ),
        'start': (
            '开场页已就绪后，按下底部控制条「下一页」的瞬间。'
            '若开场页已是最后一页「机械天文馆」，改按「上一页」。'
            '起点是按下按钮的那一刻，不是应用启动，也不是纸面开始翻动的那一刻。'
        ),
        'end': (
            '目标页纸面已重新摊平（不再处于翻页旋转中），顶部页名已换成目标页名称，'
            '底部说明已换成该页内容，「上一页」「下一页」以及该页核心操作按钮重新可点，'
            '且没有出现「此页暂不可用」。'
        ),
        'equivalent_actions': (
            '菜单「目录」中的「下一页」或「上一页」、画布焦点下的右或左方向键、'
            '触控板左右轻扫，或打开「目录」后点击目标页名，起点同样是发出该操作的瞬间。'
            '复测时推荐固定用底部控制条，并在记录中写明开场页和目标页名称。'
        ),
        'invalid': (
            '若出现「此页暂不可用」，或画面回到开场页，这次计时作废，须把书恢复到可操作后再打一组起止点。'
        ),
    },
    'foreground_update': {
        'name': '前台画面更新',
        'method': '手动展开滑块定点拨动',
        'not': '不是离屏管线帧率，也不是 BookIntegrationCheck 的消费速率',
        'sample_count': FOREGROUND_UPDATE_SAMPLE_COUNT,
        'aggregation': '记下全部样本秒数，并给出中位数。规格没有合格线。',
        'preparation': (
            '控制条可见。关闭「跟随屏幕」，顶部应变为「手动预览」，「展开」滑块可拖。'
            '当前页须已完全可操作。每次计时前先把滑块拨到 50%，等到立体结构停在半开轮廓、'
            '百分比显示 50% 且不再明显移动；这段准备不计时。'
        ),
        'start': (
            '开始把「展开」滑块一次性拖向 100% 的瞬间，或点击滑块轨道靠近 100% 一端、'
            '滑块开始移动的瞬间。'
        ),
        'end': (
            '底部百分比已稳定显示 100%，并且画面中的纸艺结构已完全停在全开轮廓、不再继续展开。'
        ),
        'between_samples': (
            '两次样本之间先把滑块拨回 50% 并等到停稳，这段回程不计时。按同一方向做满 '
            f'{FOREGROUND_UPDATE_SAMPLE_COUNT} 次。'
        ),
    },
}


def marks_path_for(output):
    output = pathlib.Path(output or DEFAULT_OUTPUT)
    return output.with_name(output.stem + '-marks.jsonl')


def append_mark(output, kind, source='mark-command', mono=None):
    if kind not in MARK_KINDS:
        raise ValueError(f'未知打点类型：{kind}')
    path = marks_path_for(output)
    path.parent.mkdir(parents=True, exist_ok=True)
    record = {
        'kind': kind,
        'timestamp': wall_clock_text(),
        'monotonic': time.monotonic() if mono is None else mono,
        'source': source,
    }
    with path.open('a', encoding='utf-8') as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + '\n')
    return record, path


def load_marks(output):
    path = marks_path_for(output)
    if not path.is_file():
        return []
    events = []
    for line in path.read_text(encoding='utf-8').splitlines():
        if not line.strip():
            continue
        events.append(json.loads(line))
    return events


def median_seconds(values):
    if not values:
        return None
    ordered = sorted(values)
    mid = len(ordered) // 2
    if len(ordered) % 2:
        return ordered[mid]
    return (ordered[mid - 1] + ordered[mid]) / 2


def _duration(start, end):
    if start is None or end is None:
        return None
    if 'monotonic' in start and 'monotonic' in end:
        return round(end['monotonic'] - start['monotonic'], 3)
    return None


def compile_timing_marks(events, protocol=None):
    warnings = []
    first_start = None
    first_result = None
    update_start = None
    samples = []
    for event in events:
        kind = event.get('kind')
        if kind == 'cancel-open':
            if first_start is not None and first_result is None:
                first_start = None
                warnings.append('已取消未完成的首次翻页起点')
            elif update_start is not None:
                update_start = None
                warnings.append('已取消未完成的前台画面更新起点')
            else:
                warnings.append('没有可取消的未完成起点')
            continue
        if kind == 'first-page-turn-start':
            if first_start is not None and first_result is None:
                warnings.append('首次翻页起点被新的起点覆盖')
            first_start = event
            continue
        if kind == 'first-page-turn-end':
            if first_start is None:
                warnings.append('首次翻页终点没有对应起点，已忽略')
                continue
            duration = _duration(first_start, event)
            if duration is None or duration < 0:
                warnings.append('首次翻页起止点无法计算耗时，已忽略')
                first_start = None
                continue
            if first_result is not None:
                warnings.append('首次翻页已有一次完整记录，后一次已覆盖前一次')
            first_result = {
                'seconds': duration,
                'start_at': first_start.get('timestamp'),
                'end_at': event.get('timestamp'),
            }
            first_start = None
            continue
        if kind == 'foreground-update-start':
            if update_start is not None:
                warnings.append('前一次画面更新没有打终点，已丢弃该起点')
            update_start = event
            continue
        if kind == 'foreground-update-end':
            if update_start is None:
                warnings.append('前台画面更新终点没有对应起点，已忽略')
                continue
            duration = _duration(update_start, event)
            if duration is None or duration < 0:
                warnings.append('前台画面更新起止点无法计算耗时，已忽略')
                update_start = None
                continue
            samples.append({
                'seconds': duration,
                'start_at': update_start.get('timestamp'),
                'end_at': event.get('timestamp'),
            })
            update_start = None
            continue
    if first_start is not None and first_result is None:
        warnings.append('首次翻页只有起点，没有终点')
    if update_start is not None:
        warnings.append('最后一次前台画面更新只有起点，没有终点')
    sample_seconds = [item['seconds'] for item in samples]
    expected = FOREGROUND_UPDATE_SAMPLE_COUNT
    return {
        'protocol': protocol or TIMING_PROTOCOL,
        'events': events,
        'first_page_turn_seconds': None if first_result is None else first_result['seconds'],
        'first_page_turn': first_result,
        'foreground_update_samples': samples,
        'foreground_update_samples_seconds': sample_seconds,
        'foreground_update_sample_count': len(samples),
        'foreground_update_median_seconds': median_seconds(sample_seconds),
        'foreground_update_expected_samples': expected,
        'warnings': warnings,
        'first_page_turn_recorded': first_result is not None,
        'foreground_update_recorded': len(samples) >= expected,
    }


def describe_mark(kind):
    labels = {
        'first-page-turn-start': '首次翻页起点',
        'first-page-turn-end': '首次翻页终点',
        'foreground-update-start': '前台画面更新起点',
        'foreground-update-end': '前台画面更新终点',
        'cancel-open': '取消未完成的起点',
    }
    return labels.get(kind, kind)


def next_toggle_kind(events, family):
    open_kind = f'{family}-start'
    close_kind = f'{family}-end'
    pending = None
    for event in events:
        if event.get('kind') == 'cancel-open':
            pending = None
        elif event.get('kind') == open_kind:
            pending = open_kind
        elif event.get('kind') == close_kind:
            pending = None
    return close_kind if pending == open_kind else open_kind


def resolve_mark_token(token, events):
    token = (token or '').strip()
    if not token:
        return None
    if token in MARK_KIND_ALIASES:
        alias = MARK_KIND_ALIASES[token]
        if alias == 'quit':
            return 'quit'
        if alias == 'cancel-open':
            return 'cancel-open'
        if alias == 'first-page-turn-toggle':
            return next_toggle_kind(events, 'first-page-turn')
        if alias == 'foreground-update-toggle':
            return next_toggle_kind(events, 'foreground-update')
    if token in MARK_KINDS:
        return token
    return None


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
    if saves is not None:
        reason = saves.get('count_quality_reason')
        if reason:
            lines.append(f'- 存档计数说明：{reason}')
    timing = report.get('timing') or {}
    first = timing.get('first_page_turn_seconds')
    if first is None:
        lines.append('- 首次翻页耗时：未打点。请按 performance-tools.md 的起止点补记。')
    else:
        lines.append(f'- 首次翻页耗时：{first} 秒')
    samples = timing.get('foreground_update_samples_seconds') or []
    median = timing.get('foreground_update_median_seconds')
    expected = timing.get('foreground_update_expected_samples') or FOREGROUND_UPDATE_SAMPLE_COUNT
    if not samples:
        lines.append('- 前台画面更新耗时：未打点。请按 performance-tools.md 的手动展开滑块方法补记。')
    else:
        listed = '、'.join(str(item) for item in samples)
        median_text = '未计算' if median is None else f'{median} 秒'
        lines.append(
            f'- 前台画面更新耗时：{len(samples)}/{expected} 个样本（{listed}），中位数 {median_text}')
        if len(samples) < expected:
            lines.append(f'- 前台画面更新样本不足 {expected} 次，复测时需补齐。')
    for warning in timing.get('warnings') or []:
        lines.append(f'- 计时打点提示：{warning}')
    lines.append('- 计时口径见 performance-tools.md。离屏帧率不是前台画面更新依据。')
    lines.append('- 原始证据不要提交到仓库。观察结论回写 performance-session.md。')
    lines.append('')
    return '\n'.join(lines)


def logic_tests():
    results = {}
    with tempfile.TemporaryDirectory(prefix='popup-save-self-test-') as temporary:
        saves = watch_saves(temporary, replacements=2, backup_writes=1)
    results['save_counter_matches_fixture'] = (
        saves.get('primary_replacement_count') == 2
        and saves.get('backup_change_count') == 1
        and saves.get('count_quality') == '估计值'
        and saves.get('observation_method') == 'poll'
    )
    with tempfile.TemporaryDirectory(prefix='popup-save-mtime-') as temporary:
        watcher = SaveWatcher(temporary)
        path = pathlib.Path(temporary) / 'state.json'
        path.write_bytes(b'{"a":1}')
        watcher.poll()
        os.utime(path, ns=(path.stat().st_mtime_ns + 1_000_000, path.stat().st_mtime_ns + 1_000_000))
        watcher.poll()
        results['mtime_only_is_estimate'] = watcher.counts['primary_replacement_count'] == 1 \
            and watcher.counts['count_quality'] == '估计值'
    with tempfile.TemporaryDirectory(prefix='popup-save-hash-poll-') as temporary:
        watcher = SaveWatcher(temporary)
        path = pathlib.Path(temporary) / 'state.json'
        temporary_path = pathlib.Path(temporary) / '.state.tmp'
        temporary_path.write_bytes(b'{"turn":1}')
        os.replace(temporary_path, path)
        watcher.poll()
        results['hash_change_during_poll_is_estimate'] = (
            watcher.counts['primary_replacement_count'] == 1
            and watcher.counts['count_quality'] == '估计值'
        )
    with tempfile.TemporaryDirectory(prefix='popup-save-rapid-') as temporary:
        watcher = SaveWatcher(temporary)
        path = pathlib.Path(temporary) / 'state.json'
        for index in range(2):
            temporary_path = pathlib.Path(temporary) / f'.state-{index}.tmp'
            temporary_path.write_bytes(json.dumps({'turn': index}).encode())
            os.replace(temporary_path, path)
        watcher.poll()
        results['rapid_writes_between_polls_under_count'] = (
            watcher.counts['primary_replacement_count'] == 1
            and watcher.counts['count_quality'] == '估计值'
        )

    first_start = {'kind': 'first-page-turn-start', 'timestamp': 't0', 'monotonic': 1.0}
    first_end = {'kind': 'first-page-turn-end', 'timestamp': 't1', 'monotonic': 2.25}
    update_events = []
    for index in range(FOREGROUND_UPDATE_SAMPLE_COUNT):
        update_events.append({
            'kind': 'foreground-update-start',
            'timestamp': f's{index}',
            'monotonic': 10 + index * 2,
        })
        update_events.append({
            'kind': 'foreground-update-end',
            'timestamp': f'e{index}',
            'monotonic': 10 + index * 2 + 0.4 + index * 0.1,
        })
    compiled = compile_timing_marks([first_start, first_end] + update_events)
    results['timing_marks_compile'] = (
        compiled['first_page_turn_seconds'] == 1.25
        and compiled['foreground_update_sample_count'] == FOREGROUND_UPDATE_SAMPLE_COUNT
        and compiled['foreground_update_median_seconds'] == 0.6
        and compiled['first_page_turn_recorded'] is True
        and compiled['foreground_update_recorded'] is True
        and not compiled['warnings']
    )
    unmatched = compile_timing_marks([{'kind': 'first-page-turn-end', 'timestamp': 'x', 'monotonic': 3}])
    results['timing_unmatched_end_ignored'] = (
        unmatched['first_page_turn_seconds'] is None
        and '首次翻页终点没有对应起点，已忽略' in unmatched['warnings']
    )

    with tempfile.TemporaryDirectory(prefix='popup-marks-') as temporary:
        output = pathlib.Path(temporary) / 'performance-session.json'
        append_mark(output, 'first-page-turn-start', source='self-test', mono=100.0)
        append_mark(output, 'first-page-turn-end', source='self-test', mono=101.5)
        report = {'manual_fields': {}}
        timing = apply_timing_to_report(report, output)
        results['mark_file_roundtrip'] = (
            timing['first_page_turn_seconds'] == 1.5
            and report['manual_fields']['first_page_turn_seconds'] == 1.5
            and report['manual_fields']['source'] == 'marks'
        )

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
            'foreground_update_samples_seconds': [],
            'note': '按 performance-tools.md 的起止点计时。可用 --mark-prompt 或 --mark 写入本报告；也可用秒表按同一口径补记。',
        },
        'timing_protocol': TIMING_PROTOCOL,
        'save_watch_path': str(planetarium_directory() / 'state.json') if watcher else None,
        'save_watch_skipped': save_skip_reason,
    }
    if report['official_app_confirmed'] is False and not dry_run:
        raise SystemExit('未确认正式应用，已停止。不要对场景预览采样。')

    print_session_timing_help(output)
    mark_interactive = sys.stdin.isatty()

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
                wait_with_marks(output, min(remaining, 0.5), mark_interactive)
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
    apply_timing_to_report(report, output)
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


def apply_timing_to_report(report, output):
    timing = compile_timing_marks(load_marks(output))
    report['timing'] = timing
    report['marks_path'] = str(marks_path_for(output))
    manual = report.setdefault('manual_fields', {})
    manual['first_page_turn_seconds'] = timing['first_page_turn_seconds']
    manual['foreground_frame_update_seconds'] = timing['foreground_update_median_seconds']
    manual['foreground_update_samples_seconds'] = list(timing['foreground_update_samples_seconds'])
    if timing['first_page_turn_recorded'] or timing['foreground_update_samples']:
        manual['source'] = 'marks'
    else:
        manual['source'] = 'unrecorded'
    return timing


def print_session_timing_help(output):
    path = marks_path_for(output)
    print('首次翻页和前台画面更新请按 performance-tools.md 的起止点计时。', flush=True)
    print(f'推荐另开终端打点（--output 须指向 {output}）：', flush=True)
    print(
        '  python3 specs/001-external-trial-delivery/tools/sample-performance.py '
        f'--mark-prompt --output {output}',
        flush=True)
    print('本窗口也可输入 F 或 U 后回车打点；C 取消尚未结束的起点。', flush=True)
    print(f'打点文件：{path}', flush=True)


def wait_with_marks(output, timeout, interactive):
    if timeout <= 0:
        return
    if not interactive:
        time.sleep(timeout)
        return
    deadline = time.monotonic() + timeout
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return
        ready, _, _ = select.select([sys.stdin], [], [], remaining)
        if not ready:
            return
        line = sys.stdin.readline()
        if not line:
            return
        token = line.strip()
        if not token:
            continue
        kind = resolve_mark_token(token, load_marks(output))
        if kind == 'quit':
            print('打点输入已忽略退出指令，采样会话继续。', flush=True)
            continue
        if kind is None:
            print('未识别的打点。请输入 F（首次翻页）、U（画面更新）或 C（取消）。', flush=True)
            continue
        record, _path = append_mark(output, kind, source='session-stdin')
        print(f"已记录{describe_mark(kind)}：{record['timestamp']}", flush=True)


def run_mark(args):
    output = args.output or DEFAULT_OUTPUT
    record, path = append_mark(output, args.mark, source='mark-command')
    print(f"已记录{describe_mark(args.mark)}：{record['timestamp']}", flush=True)
    print(f'写入 {path}', flush=True)
    return 0


def run_mark_prompt(args):
    output = args.output or DEFAULT_OUTPUT
    path = marks_path_for(output)
    print(f'计时打点已连接到 {path}', flush=True)
    print('按键后立即打点（不必再按回车）：', flush=True)
    print('  F  首次翻页：第一次为起点，第二次为终点', flush=True)
    print(
        f'  U  前台画面更新：第一次为起点，第二次为终点，做满 {FOREGROUND_UPDATE_SAMPLE_COUNT} 次',
        flush=True)
    print('  C  取消尚未结束的起点', flush=True)
    print('  Q  结束打点（不影响 30 分钟采样）', flush=True)
    raw = None
    if sys.stdin.isatty():
        try:
            import termios
            import tty
            raw = termios.tcgetattr(sys.stdin.fileno())
            tty.setcbreak(sys.stdin.fileno())
        except (ImportError, OSError, termios.error):
            raw = None
    try:
        while True:
            if raw is not None:
                ready, _, _ = select.select([sys.stdin], [], [])
                if not ready:
                    continue
                token = sys.stdin.read(1)
            else:
                line = sys.stdin.readline()
                if not line:
                    break
                token = line.strip()
            if token in ('', '\n', '\r'):
                continue
            kind = resolve_mark_token(token, load_marks(output))
            if kind == 'quit':
                print('已结束打点。', flush=True)
                return 0
            if kind is None:
                print('未识别的按键。请用 F、U、C 或 Q。', flush=True)
                continue
            record, _path = append_mark(output, kind, source='mark-prompt')
            compiled = compile_timing_marks(load_marks(output))
            extra = ''
            if kind == 'first-page-turn-end' and compiled['first_page_turn_seconds'] is not None:
                extra = f"，耗时 {compiled['first_page_turn_seconds']} 秒"
            elif kind == 'foreground-update-end' and compiled['foreground_update_samples_seconds']:
                extra = (
                    f"，本样本 {compiled['foreground_update_samples_seconds'][-1]} 秒"
                    f"（{compiled['foreground_update_sample_count']}/{FOREGROUND_UPDATE_SAMPLE_COUNT}）"
                )
            print(f"已记录{describe_mark(kind)}：{record['timestamp']}{extra}", flush=True)
    except KeyboardInterrupt:
        print('\n已结束打点。', flush=True)
        return 0
    finally:
        if raw is not None:
            import termios
            termios.tcsetattr(sys.stdin.fileno(), termios.TCSADRAIN, raw)
    return 0


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
    parser.add_argument('--mark', choices=list(MARK_KINDS),
                        help='向会话打点文件写入一个计时点，须与 --output 指向同一份会话结果')
    parser.add_argument('--mark-prompt', action='store_true',
                        help='在另一终端按 F/U 打点，须与会话使用同一 --output')
    args = parser.parse_args()
    selected = sum(bool(item) for item in (
        args.self_test, args.session, args.dry_run, args.mark, args.mark_prompt))
    if selected != 1:
        parser.error('请指定 --session、--self-test、--dry-run、--mark 或 --mark-prompt 之一。正式测量用 --session。')
    if args.account == 'daily' and not args.consent_daily_store:
        parser.error('使用日常账户时必须同时给出 --consent-daily-store；否则请改用独立测试账户。')
    if args.consent_daily_store and args.account != 'daily':
        parser.error('--consent-daily-store 只能与 --account daily 一起使用')
    if args.mark or args.mark_prompt:
        if args.account or args.consent_daily_store:
            parser.error('打点命令不读取存档，无需 --account。')
        return run_mark_prompt(args) if args.mark_prompt else run_mark(args)
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
