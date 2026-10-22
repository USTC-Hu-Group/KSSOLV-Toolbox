# Source directories and compatibility

MATLAB packages group code by responsibility. Browser sessions, reconnect logic,
sidebars and online UI helpers live in `+kssolv/+ui/+browser/`. Their HTML and
JavaScript assets live in `+kssolv/+ui/resources/browser/`; MATLAB resolves them
through `kssolv.ui.browser.resourcePath`.

HTTP transport lives in `+kssolv/+services/+http/`. Online LLM transport adapters
live in `+kssolv/+services/+llm/+online/+internal/`. Legacy workflow resource
migration belongs to `+kssolv/+services/+filemanager/+internal/`, and runs when
loading projects and workflows.

Former public MATLAB names remain as compatibility adapters in `+ui/+util/`,
`+util/HTTPJSONRequest.m`, and the former online LLM entry points. New code uses
the implementation packages. Keep the adapters when maintaining saved objects or
function handles. The persistent Project, Workflow, Task, TaskUI and Crystal class
names stay unchanged so existing `.ks` and `.wf` files retain their data.

Python services and their web pages live under `server/`:

| Directory | Responsibility |
| --- | --- |
| `server/runtime/` | Runtime gateway, HTTP worker and resource metrics |
| `server/portal/` | Portal API, Kubernetes workspace control and account pages |
| `server/admin/` | Admin API, cloud and host operations, scripts and admin pages |
| `scripts/docker/` | Container builds, validation tools and runtime tests |
| `scripts/k8s/` | Deployment, installation, operations and deployment tests |
| `scripts/ui/tests/` | MATLAB browser client regression tests |

Build and installation scripts stage the services explicitly from `server/`.
Container paths and the installed admin layout remain unchanged. MATLAB Toolbox
packages exclude `server/` and `scripts/`; both Toolbox and standalone manifests
include the relocated browser resources and MATLAB compatibility adapters. Final
payload validation checks every browser resource.

Run browser and service regressions from the repository root:

```sh
node --test scripts/ui/tests/*.cjs scripts/k8s/tests/*.cjs
python3 -m unittest discover -s scripts/docker/tests -p 'test_*.py'
python3 -m unittest discover -s scripts/k8s/tests -p 'test_*.py'
```

Run MATLAB non-graphical regressions with `matlab -nojvm -batch`. The namespace,
saved-file compatibility and packaging tests are
`kssolv.ui.test.BrowserNamespaceCompatibilityTest`,
`kssolv.services.filemanager.test.LegacyWorkflowResourcesTest`, and
`kssolv.util.test.PackagingTestFileTest`. Transport integration tests also use the
local fixtures documented in the service test sources. Graphical integration and
real container/deployment tests require their corresponding runtime environments.

All source changes and validation must comply with the repository's Java/JVM ban
and the requirement for explicit developer permission before adding compiled
sources.
