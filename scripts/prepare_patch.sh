#!/usr/bin/env bash
set -euo pipefail
CONTAINER="${1:-}"
OUT="${2:-./speculative_k5.py}"
SRC="/usr/local/lib/python3.12/dist-packages/vllm/config/speculative.py"
if [[ -z "$CONTAINER" ]]; then echo "usage: $0 <container-name> [output-file]" >&2; exit 2; fi
docker cp "$CONTAINER:$SRC" "$OUT"
python3 - "$OUT" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old = "        elif (\n            self.num_speculative_tokens > n_predict\n            and self.num_speculative_tokens % n_predict != 0\n        ):"
new = "        elif (\n            self.method != \"dspark\"\n            and self.num_speculative_tokens > n_predict\n            and self.num_speculative_tokens % n_predict != 0\n        ):"
n=s.count(old)
if n != 1: raise SystemExit(f"REFUSE: expected validator context exactly once; found {n}")
p.write_text(s.replace(old,new,1))
PY
grep -n -A3 -B2 'self.method != "dspark"' "$OUT"
sha256sum "$OUT"
echo "Prepared $OUT. Review it before bind-mounting."
