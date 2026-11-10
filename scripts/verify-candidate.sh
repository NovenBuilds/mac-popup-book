#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
out=build/candidate-checks
mkdir -p "$out"
run_dir=$(mktemp -d "$out/run.XXXXXX")
rm -f "$out/result.json"
source_hash=$(python3 scripts/write-build-receipt.py --source-hash)
run_check() {
    local name=$1
    shift
    printf '%s\n' "运行 ${name}，记录在 $run_dir/$name.log"
    "$@" > "$run_dir/$name.log" 2>&1 || { tail -n 65 "$run_dir/$name.log"; return 1; }
}
run_check engineering bash scripts/check.sh
run_check isolation bash scripts/integration.sh
export POPUP_BOOK_CAPTURE_DIR="$PWD/$run_dir/frames"
run_check published bash scripts/integration.sh --published
test "$(python3 scripts/write-build-receipt.py --source-hash)" = "$source_hash"
python3 - "$out" "$source_hash" "$run_dir" <<'PY'
import json
import pathlib
import sys

out, source_hash = pathlib.Path(sys.argv[1]), sys.argv[2]
receipt = json.loads(pathlib.Path('build/build-receipt.json').read_text())
if receipt['source_manifest_sha256'] != source_hash:
    raise SystemExit('构建与验收源码不一致。')
result = {key: receipt[key] for key in ('git', 'source_manifest_sha256', 'application_manifest_sha256')}
result['evidence_dir'] = sys.argv[3]
result['checks'] = ['engineering', 'isolation', 'published']
temp = out / 'result.tmp'
temp.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
temp.replace(out / 'result.json')
print(f'候选自动验收通过，凭据位于 {out / "result.json"}。')
PY
