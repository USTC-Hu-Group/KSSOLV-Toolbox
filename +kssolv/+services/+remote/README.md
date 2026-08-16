# Remote computing service layout

The implementation is grouped by responsibility:

- `+config/`: configuration schema and persistent selection/configuration
  stores.
- `+job/`: durable job records, storage, and lifecycle orchestration.
- `+backend/`: Standard, Bridge, Mirror, and Cloud execution backends.
- `+cloud/`: cloud-provider discovery and validation adapters.
- `+cluster/`: MATLAB cluster construction, Slurm arguments, validation, and
  routed cluster access.
- `+transport/`: SSH, OpenSSH, command routing, and access factories.
- `+security/`: encrypted credentials, TOTP, MFA context, and SSH callbacks.
- `+bridge/`: remote MATLAB bridge protocol and entrypoint.
- `+execution/`: workflow snapshots/runners, code bundles, and bootstrap code.
- `+diagnostics/`: connection-test sessions and environment/worker probes.
- `+internal/`: package-private persistence utilities.
- `+test/`: unit, transport, workflow, and scientific regression tests.
