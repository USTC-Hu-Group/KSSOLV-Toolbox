# User Getting Started

Welcome to **KSSOLV Toolbox**, a graphical user interface designed to simplify first-principles density functional theory (DFT) calculations based on the **Kohn–Sham Solver (KSSOLV)** package.

KSSOLV Toolbox is implemented in MATLAB and aims to eliminate the need for complex scripting by providing an intuitive, workflow-driven environment. Users can complete the entire simulation lifecycle—from structure import and calculation setup to execution and post-processing—through a unified graphical interface.

This document provides a concise guide to installation and basic usage for new users.

## 1. Installation

Before using KSSOLV Toolbox, please ensure that it is correctly installed on your system.

### 1.1 Using KSSOLV Toolbox inside MATLAB

If you already have **MATLAB R2024b or later** installed, you can use KSSOLV Toolbox as a MATLAB Add-On:

1. Download the toolbox installer `KSSOLV_Toolbox.mltbx` from the [Releases](https://github.com/yliu7949/KSSOLV-Toolbox/releases/latest) page.
2. Double-click the file to install it into MATLAB.
3. After installation, KSSOLV Toolbox will appear in the **MATLAB Add-Ons Manager**, where it can also be updated or uninstalled.

This mode is recommended for users who primarily work inside the MATLAB environment.

### 1.2 Installing as a Standalone Application

KSSOLV Toolbox is also available as a standalone application for **Windows**, **macOS**, and **Linux**, and does not require a full MATLAB installation. Instead, it relies on **MATLAB Runtime (MCR)**.

#### Windows and macOS

1. Download the platform-specific installer package.
2. On macOS, extract the package and double-click `KSSOLV_Toolbox.app`.
3. Follow the on-screen installer instructions:
   - Select the installation directory for KSSOLV Toolbox.
   - Specify the installation path for MATLAB Runtime.
4. Complete the installation.

After installation, you can launch KSSOLV Toolbox from the system application menu.

#### Linux

1. Extract the installer package. The installer file is named:

   ```bash
   KSSOLV_Toolbox.install
   ```

2. Make sure a graphical environment is available.

3. Run the installer from the terminal:

   ```bash
   ./KSSOLV_Toolbox.install
   ```

4. Follow the same installation steps as on Windows/macOS.

After installation, start the application using:

```bash
# Example paths
/home/ubuntu/Software/KSSOLV_Toolbox/application/run_KSSOLV_Toolbox.sh \
    /home/ubuntu/Software/MATLAB/MATLAB_Runtime/R2025b
```

## 2. Quick Start

### 2.1 User Interface Overview

After launching KSSOLV Toolbox, the main graphical interface is displayed:

- **Top**: Menu bar
- **Left**: Project Browser and Information Browser
- **Right**: Config Editor and Simulation Browser (collapsible)
- **Bottom**: Command Browser

All side panels can be collapsed or expanded to maximize workspace flexibility.

### 2.2 Importing and Viewing Crystal Structures

#### Preparation

Download a crystal structure file (e.g., Si) from the **Materials Project**, in either **CIF** or **POSCAR** format.

#### Import Steps

1. From the menu bar, select:
   **Home → Structure → Import Structure from File...**
2. Choose the downloaded `Si.cif` (or `POSCAR`) file.

The structure will:

- Appear in the **Project Browser**
- Open automatically in the 3D structure viewer
- Display metadata (import time, notes, structural details) in the **Information Browser**

Interaction tips:

- Left-click and drag: rotate the structure
- Mouse wheel: zoom in/out
- Right-click menu: reset view

Multiple structures can be opened and viewed simultaneously.

### 2.3 Creating a Computational Workflow

1. Double-click **Workflow** in the Project Browser.
2. A new default workflow is created and opened automatically.

The default workflow contains a minimal set of computation nodes. You can:

- Drag nodes freely on the canvas
- Add or remove nodes via the **Workflow** menu
- Add or remove input/output ports on nodes
- Connect nodes using edges

#### Useful Keyboard Shortcuts

- Copy / Paste: `Ctrl/Cmd + C`, `Ctrl/Cmd + V`
- Undo / Redo: `Ctrl/Cmd + Z`, `Ctrl/Cmd + Shift + Z`
- Select all: `Ctrl/Cmd + A`
- Auto fit view: `Space`
- Delete node: `Backspace`
- Toggle minimap: `Ctrl/Cmd + M`

### 2.4 Configuring and Running a Workflow

Double-click any workflow node to open the **Config Editor** on the right.

In the Config Editor, you can define:

- Node label and description
- Associated module
- Task type (e.g., SCF calculation)
- Detailed numerical and physical parameters

A typical **SCF workflow** for an Si structure may include:

1. Structure setup node
2. SCF calculation node
3. Result visualization node

Once configured, click **Run** in the menu bar to execute the workflow.

During execution, nodes run sequentially. Upon completion, result plots (e.g., energy convergence vs. iteration) are automatically displayed.

## 3. Project Files (.ks)

KSSOLV Toolbox uses the `.ks` extension for project files.

A `.ks` file stores:

- Imported structures
- Defined workflows
- Node configurations and parameters
- Saving results
- Figures

### Opening a Project

1. Ensure no project is currently open (or close the active one).
2. Click **Project → Open**.
3. Select a `.ks` file to load the project.

### Saving a Project

- An asterisk (`*`) in the window title indicates unsaved changes.
- Click **Save** to write changes to disk.
- If no save location exists, you will be prompted to choose one.

### Closing a Project

When closing a project or exiting the application, KSSOLV Toolbox will prompt you to save any unsaved changes.

## 4. Command Browser and LLM Integration

The **Command Browser** at the bottom of the interface serves two purposes:

1. Execute standard MATLAB commands
2. Interact with large language models (LLMs) using natural language

### LLM Modes

KSSOLV Toolbox supports two LLM deployment modes:

- **Local mode**: Based on the Ollama framework, suitable for offline use
- **Cloud API mode**: Connects to online LLM services via API

### Basic Interaction

Input text starting with `$` or `$$` in the Command Browser to send a prompt to the LLM. The model response is displayed directly in the interface.

### Tool Calling

For LLMs that support *function calling*, KSSOLV Toolbox exposes workflow-related tools that the model can invoke automatically, enabling assisted workflow creation and configuration.

## 5. Environment Variables

The following environment variables can be used to customize behavior:

```bash
KSSOLV_LOCALE="en_US"
KSSOLV_HOST_IN_BROWSER="false"

OPENAI_PROXY_URL="https://api.openai.com/v1/chat/completions"
OPENAI_API_KEY="sk-xxxxxxxxxxxxxxxx"
OPENAI_MODEL_LIST="o3-mini"
```

For additional details and advanced features, please refer to the full documentation and upcoming developer guides.
