# Getting Started with KSSOLV Toolbox

KSSOLV Toolbox provides a graphical environment for preparing, running, and
reviewing density functional theory calculations based on KSSOLV. This guide
covers installation and a first local workflow.

[简体中文](start.zh-CN.md)

## Install

### MATLAB toolbox

KSSOLV Toolbox requires MATLAB R2024b or later when it is used as an Add-On.

1. Download `KSSOLV_Toolbox.mltbx` from the
   [latest release](https://github.com/USTC-Hu-Group/KSSOLV-Toolbox/releases/latest).
2. Open the downloaded file in MATLAB and complete the installation.
3. Start KSSOLV Toolbox from MATLAB or the Add-On Manager.

### Standalone application

Standalone installers are provided for supported Windows, macOS, and Linux
systems. A full MATLAB installation is not required, but the matching MATLAB
Runtime is required.

1. Download the installer for your operating system from the latest release.
2. Run the installer and choose the application and MATLAB Runtime locations.
3. Launch KSSOLV Toolbox from the system application menu.

On Linux, make the installer executable if necessary and run it in a graphical
session:

```bash
chmod +x KSSOLV_Toolbox.install
./KSSOLV_Toolbox.install
```

The installer displays the launch command and Runtime path required by the
installed release.

## Learn the workspace

The main window is organized around a central document area:

- **Project Browser** stores structures, workflows, results, and figures.
- **Information Browser** shows details for the current project item.
- **Config Editor** edits the selected workflow node.
- **Simulation Browser** follows calculations and results.
- **Command Window** accepts MATLAB commands and, when configured, LLM prompts.

Panels can be collapsed when more document space is needed.

## Import a structure

1. Prepare a structure file such as CIF, POSCAR, or XYZ.
2. Choose **Home → Structure → Import Structure from File…**.
3. Select the file.

The structure is added to the Project Browser and opened in the 3D viewer.
Drag to rotate, use the mouse wheel to zoom, and use the context menu for view
and selection commands.

For structure editing, see the [Modeling User Guide](../modeling-user-guide.md).
For MATLAB import and export, see the
[Structure I/O API](../structure-io-api.md).

## Create and run a workflow

1. Double-click **Workflow** in the Project Browser to create a workflow.
2. Add the required calculation nodes from the **Workflow** tab.
3. Connect nodes in execution order.
4. Select each node and complete its settings in the Config Editor.
5. Save the project, then choose **Run**.

A basic self-consistent field calculation normally includes a structure input,
an SCF task, and one or more result or visualization steps. During execution,
the Simulation Browser shows progress and messages. Review warnings before
using a result in subsequent calculations.

## Save the project

KSSOLV Toolbox projects use the `.ks` extension. A project contains imported
data, workflows, settings, results, and figures.

- An asterisk in the window title indicates unsaved changes.
- Choose **Project → Save** regularly while preparing a workflow.
- When opening another project, close or save the current project first.

## Optional features

The Command Window can connect to a local Ollama service or an
OpenAI-compatible service. Remote calculations can use a configured cluster,
remote MATLAB installation, or supported MATLAB cluster profile. Both features
require additional setup:

- [Configuration](../configuration.md)
- [Remote Computing](../remote-computing-user-guide.md)

Start with a small local calculation before enabling either feature. This
makes it easier to separate workflow problems from service or cluster
configuration problems.

## Where to go next

- [Modeling User Guide](../modeling-user-guide.md)
- [Volume Viewer User Guide](../volume-viewer-user-guide.md)
- [Remote Computing User Guide](../remote-computing-user-guide.md)
- [Modeling API v1](../modeling-api.md)
