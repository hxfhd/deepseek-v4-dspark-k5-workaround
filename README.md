# DeepSeek V4 DSpark K=5 workaround on 2× DGX Spark

Reproducible documentation for a **DeepSeek-V4-Flash-Vision-Exp + DSpark K=5** validation workaround tested on **2× NVIDIA DGX Spark (GB10)** with TP=2.

## Tested configuration
- 2 × NVIDIA DGX Spark (GB10), TP=2
- Model: `DeepSeek-V4-Flash-Vision-Exp`
- Runtime image: `aidendle94/sparkrun-vllm-ds4-gb10:production-3.73-vision`
- `MAX_MODEL_LEN=393216`, `MAX_NUM_SEQS=6`, `MAX_NUM_BATCHED_TOKENS=8192`
- `GPU_MEMORY_UTILIZATION=0.85`
- DSpark K=5, `B12X_MLA_SPARSE`, prefix caching enabled

> **Scope warning:** `production-3.73-vision` is not an upstream vLLM release. Match surrounding source before applying this workaround. Do not patch by line number alone or assume it applies to another image/version/checkpoint.

## Why K=5 is rejected in the tested image
The DeepSeek-V4 DSpark draft inherits `n_predict=3` from `num_nextn_predict_layers`, while its DSpark block size is 5. The generic MTP reuse validator rejects K=5 because `5 > 3` and `5 % 3 != 0`.

K=6 happens to pass the old divisibility rule because `6 % 3 == 0`; that is not evidence that K=6 is intended. On stock code K=4 also fails this generic rule first (`4 % 3 != 0`) before the older block-size guard.

## Upstream context
Related upstream PR: [vllm-project/vllm#54631](https://github.com/vllm-project/vllm/pull/54631), **“[Bugfix][Spec Decode] Use DeepSeek V4 DSpark block size.”** As of **2026-09-09**, it is open and unmerged. It takes the cleaner route of setting `n_predict = dspark_block_size` in the DeepSeek-V4 DSpark branch.

This repo is therefore a **local, reversible workaround**, not an upstream fix. Retire it and revalidate when an equivalent fix is shipped in the runtime you use.

## Local change
See [`patches/speculative_k5.patch`](patches/speculative_k5.patch). The local condition adds `self.method != "dspark"` to the generic divisibility check. This bypasses only that check for DSpark; the tested image's existing block-size guard is deliberately left unchanged.

## Prepare the patched file
Do not redistribute or copy a complete `speculative.py` across unrelated vLLM builds. Copy it from the exact container and transform that copy:

```bash
chmod +x scripts/prepare_patch.sh verify/verify_k5.sh
./scripts/prepare_patch.sh <container-name>
```

The helper refuses to patch unless the expected source context occurs exactly once. It produces `./speculative_k5.py`, which the Compose examples bind-mount read-only over `/usr/local/lib/python3.12/dist-packages/vllm/config/speculative.py`.

## Tested Compose examples
[`examples/compose.host.example.yaml`](examples/compose.host.example.yaml) and [`examples/compose.worker.example.yaml`](examples/compose.worker.example.yaml) are **sanitized from the actual host/worker Compose files used in the successful TP=2 deployment**, not newly invented configurations.

Generalized values are model path, host/worker IPs (`10.0.0.10` / `10.0.0.20` placeholders), data interface (`YOUR_DATA_IFACE`), and RoCE HCA (`YOUR_ROCE_HCA`). Replace them with your topology. Tested runtime parameters are otherwise preserved.

The `3.73-vision` image already launches vLLM from its entrypoint; do **not** add another `vllm serve /model` command unless your image requires one.

## Verify
```bash
./verify/verify_k5.sh <container-name>
```
Then confirm a real completion and a representative longer workload. Successful config parsing alone is not sufficient.

## Observed result
Original TP=2 field observations:
- pure decode average ~47.5 tok/s; median ~44.5; P90 ~60; peak ~65.6
- mean accepted length 2.54 / acceptance 30.8% / ~36.8 tok/s
- 4.20 / 64.1% / ~59.7 tok/s
- 4.75 / 75.1% / ~65.6 tok/s

The runtime reported speculative depth 5 and exposed five speculative positions in acceptance metrics. These are environment-specific observations, not upstream benchmark results.

## Rollback
Remove the `speculative_k5.py` bind mount, restore the previous speculative-token setting, and recreate the containers. The Docker image itself remains unchanged.

## Discussion
[NVIDIA Developer Forum: 2× DGX Spark DeepSeek-V4-Flash-Vision-Exp: TP=2, RoCE, DSpark K=5 experiment, and CodeWhale long-agent observations](https://forums.developer.nvidia.com/t/2x-dgx-spark-deepseek-v4-flash-vision-exp-tp-2-roce-dspark-k-5-experiment-and-codewhale-long-agent-observations/382675)

## License
MIT. See [`LICENSE`](LICENSE).
