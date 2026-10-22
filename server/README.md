# Online services

Production Python services and their web assets live here:

- `runtime/`: one MATLAB Runtime session, its local HTTP worker, and resource sampling.
- `portal/`: account authentication, tenant lifecycle, Kubernetes access, and the user portal.
- `admin/`: host administration, resource accounting, and the Shell executor.

Build and deployment entry points remain in `scripts/docker/` and `scripts/k8s/`.
Their staging helpers copy only the required service files into each image or host installation.
The installed Runtime, portal, and systemd entry paths retain their existing layout.

Python tests live in `scripts/docker/tests/` and `scripts/k8s/tests/`.
Browser-only regression tests live under `scripts/ui/tests/` and `scripts/k8s/tests/`.
All services use the Python standard library and require no JVM or native compilation.
See [Development layout](../docs/development-layout.md) for the repository-wide ownership boundaries.
