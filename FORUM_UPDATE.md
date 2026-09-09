## Reproducibility update

I published a small reproducibility repository for the DSpark K=5 workaround used in this 2× DGX Spark test:

https://github.com/hxfhd/deepseek-v4-dspark-k5-workaround

It includes the minimal validator diff, sanitized host/worker Compose files derived from the tested deployment, a helper that copies and patches the exact `speculative.py` from the running image, verification steps, and rollback instructions.

One correction from the source-level review in this thread: on the stock tested code, K=4 hits the same generic `n_predict=3` divisibility rule before the older DSpark block-size guard. K=6 passes that old rule only because `6 % 3 == 0`; I do not treat that as evidence that K=6 is the intended depth.

The related upstream vLLM PR #54631 takes a cleaner approach by deriving `n_predict` from `dspark_block_size` for DeepSeek V4 DSpark. As of 2026-09-09 it is still open/unmerged, so this repository keeps the workaround explicitly scoped to the tested image and makes rollback trivial.
