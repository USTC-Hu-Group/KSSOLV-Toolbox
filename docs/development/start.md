# Development Getting Started Guide

Welcome to the Technical Development Getting Started Guide for **KSSOLV Toolbox**. KSSOLV Toolbox is a MATLAB-based GUI toolbox designed to streamline **KSSOLV DFT workflows**, covering the full pipeline from structure import and calculation setup to post-processing, analysis, and visualization.

This guide introduces the core technical components of KSSOLV Toolbox and explains how to configure and use them in a local development environment.

## Technology Stack Overview

The core technology stack of KSSOLV Toolbox consists of the following components:

- **Application Framework**  
  This toolbox is built on **MATLAB AppContainer**, an advanced internal framework that provides essential GUI infrastructure, such as toolstrips, document windows, and browser panels.

- **UI Components**  
  The user interface is primarily constructed using standard MATLAB UI components. In addition, several advanced interactive components are implemented using **`uihtml`**, with frontend logic developed using the [Vue.js](https://vuejs.org/) framework.

## Project Directory Structure

The high-level directory structure of KSSOLV Toolbox is organized as follows:

```bash
(root)
├── +kssolv        # Main application package
│   ├── +api       # Public APIs for external interaction
│   ├── +core      # Core DFT computation engine, including the KSSOLV package
│   ├── +services  # Services for file I/O, workflow management, logging, etc.
│   └── +ui        # Reusable UI components
├── assets         # Screenshots and other static assets
├── resources      # MATLAB Project resource directory
└── scripts        # Utility scripts for building, signing, and packaging
```

## Local Development Environment Setup

This section describes how to set up a local development environment. Before proceeding, ensure that **MATLAB is installed** on your system.  The recommended version is **MATLAB R2025b or later**, as earlier releases may lack required AppContainer features.

### 1. Clone the Repository

Clone the KSSOLV Toolbox repository to your local machine:

```bash
git clone https://github.com/yliu7949/KSSOLV-Toolbox.git
```

### 2. Initialize and Update Submodules

Navigate to the project root directory and initialize all Git submodules:

```bash
git submodule update --init --recursive
git submodule update --remote --recursive
```

Ensure that all submodules are successfully checked out, as missing submodules will result in runtime errors.

### 3. Run and Debug the Application

Launch MATLAB, set the current working directory to the project root, and start the application by running:

```matlab
kssolv
```

This command starts the main GUI window.

## Installer and Package Compilation

### Build MATLAB Toolbox (`.mltbx`)

To compile the project into a MATLAB Toolbox (`.mltbx`) package:

1. Open MATLAB.
2. Set the current directory to the project root.
3. Execute the following command:

```matlab
% Build the MATLAB Toolbox using the buildtool framework
buildtool
```

After completion, the generated file `KSSOLV_Toolbox_Vx.y.z.mltbx` will be located in the `Release` directory.

### Build Standalone Desktop Application Installer

To compile the standalone desktop application installer:

1. Open MATLAB.
2. Set the current directory to the project root.
3. Execute the following function:

```matlab
buildInstaller
```

Warnings may appear during the build process and can typically be ignored unless they indicate missing dependencies.

Once the process completes, the installer will be generated in:

```
Release/StandaloneDesktopApp
```

### macOS Notarization (Required for Distribution)

On macOS, additional notarization is required to allow installation on other machines.

> \[!IMPORTANT]\
> Before running the script below, you must first modify the information inside the `sign_and_notarize_app.sh` and `package_dmg.sh` files to match your specific configuration (e.g., your Apple Developer ID and app-specific password).

Once you have updated the scripts, execute them from the project root:

```bash
./scripts/sign_and_notarize_app.sh
./scripts/package_dmg.sh
```

After notarization completes successfully, a signed and notarized `.dmg` archive will be produced. This file can be safely distributed and installed on other macOS systems.

## Notes

- Ensure that the MATLAB Runtime version bundled with the standalone installer matches the MATLAB version used for compilation.
- Missing submodules, incorrect MATLAB versions, or unsigned binaries are common causes of build or installation failures.
