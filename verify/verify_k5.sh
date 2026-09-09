#!/usr/bin/env bash
set -euo pipefail
C="${1:-}"
if [[ -z "$C" ]]; then echo "usage: $0 <container-name>" >&2; exit 2; fi
echo '== container =='; docker inspect "$C" --format 'name={{.Name}} image={{.Config.Image}} status={{.State.Status}}'
echo '== loaded vLLM file =='; docker exec "$C" python3 -c 'import vllm.config.speculative as s; print(s.__file__)'
echo '== K=5 workaround =='; docker exec "$C" grep -n -A3 -B2 'self.method != "dspark"' /usr/local/lib/python3.12/dist-packages/vllm/config/speculative.py
echo '== bind mount =='; docker inspect "$C" --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}' | grep 'vllm/config/speculative.py' || true
echo '== recent relevant logs =='; docker logs --tail 500 "$C" 2>&1 | grep -Ei 'speculat|dspark|n_predict|accept|depth' | tail -n 100 || true
printf '%s
' 'Manual checks: K=5 reported; five positions if metrics emit them; real completion succeeds; representative long workload has no K=5-attributable shape/CUDA/KV/output failure.'
