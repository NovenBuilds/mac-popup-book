#!/usr/bin/env python3
"""前台性能采样工具。放在规格目录，不进入候选源码指纹。

正式 30 分钟测量仍须在独立测试账户中、从重新启动《开合之间》开始。
本工具的自检不打开应用，也不读取日常存档。
"""
import argparse
import hashlib
import json
import os
import pathlib
import resource
import subprocess
import sys
import tempfile
import time


def rss_bytes():
    # macOS 的 ru_maxrss 单位是字节。
    return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss


def process_rss(pid):
    result = subprocess.run(
        ['ps', '-p', str(pid), '-o', 'rss='],
        check=False, text=True, capture_output=True)
    text = result.stdout.strip()
    if result.returncode != 0 or not text:
        return None
    return int(text) * 1024


def display_resolution():
    result = subprocess.run(
        ['system_profiler', 'SPDisplaysDataType'],
        check=False, text=True, capture_output=True)
    lines = []
    for line in result.stdout.splitlines():
        if 'Resolution:' in line or 'Display Type:' in line:
            lines.append(line.strip())
    return lines


def probe_power():
    probes = []
    for command in (
        ['pmset', '-g', 'batt'],
        ['pmset', '-g', 'therm'],
    ):
        result = subprocess.run(command, check=False, text=True, capture_output=True)
        probes.append({
            'command': ' '.join(command),
            'returncode': result.returncode,
            'available': result.returncode == 0 and bool(result.stdout.strip()),
            'excerpt': '\n'.join(result.stdout.splitlines()[:8]),
        })
    watts = subprocess.run(
        ['powermetrics', '-n', '1', '-i', '300', '--samplers', 'cpu_power,gpu_power'],
        check=False, text=True, capture_output=True, timeout=8)
    probes.append({
        'command': 'powermetrics -n 1 -i 300 --samplers cpu_power,gpu_power',
        'returncode': watts.returncode,
        'available': watts.returncode == 0 and 'Unable' not in watts.stderr,
        'excerpt': '\n'.join((watts.stderr or watts.stdout).splitlines()[:6]),
    })
    return probes


def watch_saves(directory, replacements, backup_writes):
    """统计主存档成功替换。只能看到时间变化时标为估计值。"""
    directory = pathlib.Path(directory)
    primary = directory / 'state.json'
    backup = directory / 'state.json.backup'
    seen = {}
    counts = {'primary_replacement_count': 0, 'backup_change_count': 0}
    exact = True

    def snapshot(path):
        if not path.exists():
            return None
        data = path.read_bytes()
        return hashlib.sha256(data).hexdigest(), path.stat().st_mtime_ns

    for path in (primary, backup):
        seen[path] = snapshot(path)
    for index in range(replacements):
        payload = json.dumps({'turn': index}).encode()
        temporary = directory / f'.state-{index}.tmp'
        temporary.write_bytes(payload)
        os.replace(temporary, primary)
        if index < backup_writes:
            backup.write_bytes(payload)
        for path, key in (
            (primary, 'primary_replacement_count'),
            (backup, 'backup_change_count'),
        ):
            current = snapshot(path)
            previous = seen[path]
            if current is None or current == previous:
                continue
            if previous is not None and current[0] == previous[0]:
                exact = False
            counts[key] += 1
            seen[path] = current
    counts['count_quality'] = '精确' if exact else '估计值'
    return counts


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
    watts_ready = any(
        item['command'].startswith('powermetrics') and item['available']
        for item in power)
    report = {
        'memory_rss_before_bytes': before,
        'memory_rss_after_bytes': after,
        'memory_increased': after >= before,
        'process_rss_bytes': process_rss(os.getpid()),
        'clock_sleep_seconds': elapsed,
        'clock_usable': 0.04 <= elapsed <= 0.2,
        'display': display_resolution(),
        'save_counter': saves,
        'save_counter_matches_fixture': saves == {
            'primary_replacement_count': 2,
            'backup_change_count': 1,
            'count_quality': '精确',
        },
        'power_probes': power,
        'watt_sample_available': watts_ready,
        'ignored_digest': sink,
    }
    report['ready_for_session'] = all((
        report['memory_increased'] or report['process_rss_bytes'],
        report['clock_usable'],
        report['save_counter_matches_fixture'],
        bool(report['display']),
    ))
    return report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--self-test', action='store_true')
    parser.add_argument('--output', type=pathlib.Path)
    args = parser.parse_args()
    if not args.self_test:
        parser.error('正式采样须在独立测试账户的性能会话中调用；当前只提供 --self-test')
    report = self_test()
    text = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)
    sys.stdout.write(text)
    return 0 if report['ready_for_session'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
