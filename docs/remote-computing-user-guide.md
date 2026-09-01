# Remote Computing User Guide

KSSOLV Toolbox can submit a workflow to a remote MATLAB environment and import
the result into the current project. Remote computing requires access to a
working cluster or remote MATLAB installation; KSSOLV Toolbox does not create
accounts, install a scheduler, or start cloud resources without user action.

[简体中文](remote-computing-user-guide.zh-CN.md)

## Choose an execution mode

| Mode | Use it when | Main requirement |
| --- | --- | --- |
| **Standard** | Local MATLAB submits through MATLAB Parallel Server and Slurm | Local MATLAB, Parallel Server, and workers use the same release |
| **Bridge** | A remote MATLAB session submits to its cluster profile | Remote MATLAB and its workers use the same release |
| **Mirror** | A single remote node can run ordinary MATLAB | Remote MATLAB and the required licenses are available; Parallel Server is not required |
| **Cloud** | An existing cloud-backed MATLAB cluster profile is available | The selected profile is already configured and usable |

All modes require Parallel Computing Toolbox on the local MATLAB installation.
Standalone deployments must include the products required by the selected
workflow and remote mode.

Start with the simplest mode supported by the environment. Use Standard when
the releases already match, Bridge when submission must happen from a remote
MATLAB, and Mirror for a single remote MATLAB process.

## Prepare the environment

Before creating a configuration, collect:

- the SSH host and user name, if direct SSH is used;
- the authentication method and private-key path, if applicable;
- the remote MATLAB root and a writable job-storage directory;
- the cluster profile name for Bridge, Standard profile, or Cloud modes;
- Slurm partition, account, QoS, and time limits when managed Slurm is used;
- the KSSOLV deployment choice for the remote environment.

For Standard, confirm that local MATLAB, MATLAB Parallel Server, and all
workers use the same release. For Bridge, only remote MATLAB and its workers
must match. The login node, target node, and workers must be able to access any
directory used as shared remote job storage.

## Create a configuration

1. Open **Remote Computing → Configure Remote Clusters…**.
2. Choose **New**, enter a descriptive name, and select the execution mode.
3. On **Connection**, enter SSH and authentication settings, any login script,
   and prompt rules required by the site.
4. On **Computation**, enter the MATLAB, profile, scheduler, storage, worker,
   and KSSOLV deployment settings relevant to that mode.
5. Test the connection, probe resources when available, review the discovered
   values, and save.

Fields marked optional can be left empty when the selected mode can discover
them. Resource probing updates the form but does not save it automatically.

### Authentication

Direct SSH configurations support SSH Agent, identity file, password, and
multifactor authentication. Prefer SSH Agent or a protected identity file when
the site supports them.

Saved passwords and retained TOTP secrets are encrypted for the current local
installation. They are not written to job records or logs. This storage does
not protect against someone who already controls the same operating-system
account. Do not share configuration or credential directories, and remove
saved credentials when unattended access is no longer required.

If a TOTP secret is not retained, the application asks for a one-time code when
a new authenticated session is required.

## Route commands after login

Use the login script for shell initialization, for example:

```bash
source /etc/profile
module load matlab/R2026b
export TMPDIR=/scratch/$USER/tmp
```

The script must finish successfully before remote work can continue.

Use the computation command template only when a command must be routed to
another node or shell. The template must contain `{command}` exactly once. For
example:

```bash
exec ssh compute01 -- {command}
```

Prompt rules can answer an expected `sudo`, `su`, or second-hop prompt. Add
only prompts required by the site, keep them in the expected order, and test
the route with a non-destructive command. Unknown or repeated prompts fail
rather than receiving a guessed credential.

Avoid complex routing when an administrator can provide a normal SSH path or
cluster profile. Never place passwords, OTPs, or TOTP secrets in login scripts,
command templates, paths, scheduler arguments, or environment variables.

## Test and probe

**Test Connection** checks the selected connection and login route. For an
existing MATLAB profile or Cloud configuration, it may also submit a minimal
worker-reachability job. It does not discover or overwrite computation values.

**Probe Resources** reaches the final computation environment and can discover
the MATLAB release and root, worker limits, a suggested pool size, and storage
location. Review all values before saving, especially on shared systems where
policy limits may be lower than detected hardware limits.

Connection testing and resource probing can be canceled independently. A
successful connection test does not guarantee that a full scientific workflow
has the required products, licenses, memory, or scheduler allocation.

## Select a deployment

Use **Attach Current Toolbox** when the remote environment does not already
provide a compatible KSSOLV Toolbox installation. The first job for a given
toolbox version may take longer while code is transferred.

Use **Cluster Installed** when an administrator maintains KSSOLV Toolbox on the
remote system. Confirm that the configured path and version match the workflow
before submitting.

## Submit and manage work

1. Save the project and complete the workflow locally.
2. From **Use Remote Computing**, select a saved configuration.
3. Submit the workflow and note the job shown by KSSOLV Toolbox.
4. Open **Remote Jobs and Results…** to refresh status, inspect the diary,
   cancel work, or retrieve a completed result.

Each job keeps the non-sensitive configuration needed to identify its original
execution environment. Editing a configuration later does not silently move an
existing job to another backend.

Retrieved results are identified by their remote job ID, so retrying retrieval
does not normally duplicate a result already imported into the project. Check
the diary and result metadata before accepting a calculation as successful.

## Remote Command Window

**Run Command Window Commands Remotely** starts a persistent MATLAB session
through a selected direct SSH configuration. Commands share one base workspace
until the target changes, remote command execution is disabled, or the Command
Window closes.

This feature is separate from workflow submission and requires direct SSH,
remote MATLAB, and a writable remote job directory. Profile-only configurations
without direct connection settings cannot use it. Remote input and output are
marked `[remote]`.

Avoid leaving important work only in the remote base workspace. Save data to an
appropriate remote path or use a workflow when reproducibility matters.

## Cloud profiles

Cloud mode uses an existing MATLAB cluster profile created or imported through
the appropriate MathWorks or site tooling. Provider and region fields describe
the profile; actual networking, licenses, quotas, and charges remain controlled
by the cloud account and cluster configuration.

Confirm authorization and budget before starting or expanding paid resources.
After testing, check for running instances, clusters, storage volumes, and
other billable resources in the provider console.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Connection requires authentication again | Network state, SSH Agent, key permissions, password, or current one-time code |
| Job status is unknown | Retry after confirming the network and scheduler; `Unknown` does not by itself mean failure |
| Standard release mismatch | Use matching local MATLAB, Parallel Server, and worker releases, or choose Bridge |
| Bridge worker mismatch | Make the remote MATLAB and remote profile workers use the same release |
| Mirror process disappeared | Remote MATLAB license, job-directory permissions, and `standalone.log` |
| Login route waits for input | Login script, command template, prompt order, and required site tools |
| Slurm submission fails | Partition, account, QoS, walltime, and allowed scheduler arguments |
| Cloud profile fails | Repair and validate the profile with the provider or cluster management tool before resubmitting |

If a job remains ambiguous, preserve its diary and identifiers before cleaning
local transfer files. Never paste long-lived passwords or TOTP secrets into an
issue, chat, or log; rotate any credential that has been exposed.
