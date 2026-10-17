"""Stage an official Runtime-only installer and its exact build requirements."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import xml.etree.ElementTree as ET
import zipfile


def stage(build, base, requested, output):
    metadata = json.loads((build / "runtime-metadata.json").read_text())
    dependency_file = build / "buildresult.json"
    dependencies = json.loads(dependency_file.read_text())["RuntimeDependencies"]
    digest = hashlib.sha256(dependency_file.read_bytes()).hexdigest()
    if metadata["Architecture"] != "maca64" or metadata.get("JVMEnabled") is not False:
        raise ValueError("A maca64 no-JVM application build is required.")
    with zipfile.ZipFile(base / "Contents/Resources/bundle.zip") as archive:
        manifest = ET.fromstring(archive.read("ApplicationInstallerManifest.xml"))
    source_mode = metadata.get("RuntimeDelivery")
    if not source_mode:
        products = manifest.findall("MCRProducts/MCRProduct")
        source_mode = "none" if not products else "web" if (base / "Contents/Resources/installAgentURL.txt").is_file() else "installer"
    delivery = source_mode if requested == "auto" else requested
    if delivery not in ("web", "installer", "none"):
        raise ValueError("Invalid Runtime delivery mode.")
    output.mkdir(parents=True, exist_ok=True)
    requirements = {key: metadata[key] for key in ("RuntimeRelease", "RuntimeVersion", "Architecture")}
    requirements["RuntimeDelivery"] = delivery
    requirements["RuntimeBuildVersion"] = metadata.get("RuntimeBuildVersion", "")
    requirements["RequiredProductFiles"] = [
        f"{item['DisplayName']} {metadata['RuntimeVersion']} {platform}.xml"
        for item in dependencies for platform in ("common", "maca64")
    ]
    if delivery != "none":
        directory = build / "runtime-installers" / delivery
        info = json.loads((directory / "runtime-installer.json").read_text())
        for key in ("RuntimeRelease", "RuntimeVersion", "Architecture"):
            if info[key] != metadata[key]:
                raise ValueError(f"Runtime installer {key} does not match the application.")
        if info["RuntimeDelivery"] != delivery or info["BuildResultSHA256"] != digest:
            raise ValueError("Runtime-only installer is stale or has the wrong delivery mode.")
        installer = directory / info["Installer"]
        with zipfile.ZipFile(installer / "Contents/Resources/bundle.zip") as archive:
            runtime_manifest = ET.fromstring(archive.read("ApplicationInstallerManifest.xml"))
        expected = {str(item["ID"]) for item in dependencies}
        actual = {node.text for node in runtime_manifest.findall("MCRProducts/MCRProduct/ExternalProductIdentifier")}
        if expected != actual or list(runtime_manifest) == [] or any(node.tag != "MCRProducts" for node in runtime_manifest):
            raise ValueError("Runtime installer must contain exactly the application's Runtime products and no application payload.")
        resources = installer / "Contents/Resources"
        online = (resources / "installAgentURL.txt").is_file()
        if online != (delivery == "web"):
            raise ValueError("Runtime installer resources disagree with their delivery metadata.")
        if delivery == "installer":
            local_payload = next((resources / name for name in ("InstallerForMac", "InstallAgent.zip")
                                  if (resources / name).is_file()), None)
            if local_payload is None or not zipfile.is_zipfile(local_payload):
                raise ValueError("Offline Runtime payload must include the official InstallerForMac or InstallAgent.zip archive.")
        plist = plistlib.loads((installer / "Contents/Info.plist").read_bytes())
        executable = plist["CFBundleExecutable"]
        if not executable or Path(executable).name != executable or not (installer / "Contents/MacOS" / executable).is_file():
            raise ValueError("Invalid Runtime installer entry point.")
        shutil.copytree(installer, output / "RuntimeSetup.app", symlinks=True)
        requirements["InstallerExecutable"] = executable
        requirements["RuntimeBuildVersion"] = info["RuntimeBuildVersion"]
    # 'none' can still require the same minimum build level recorded by an
    # independently generated official installer for this exact dependency set.
    if not requirements["RuntimeBuildVersion"]:
        info_file = build / "runtime-installers/web/runtime-installer.json"
        if info_file.is_file():
            info = json.loads(info_file.read_text())
            if info["BuildResultSHA256"] == digest:
                requirements["RuntimeBuildVersion"] = info["RuntimeBuildVersion"]
    (output / "runtime-requirements.plist").write_bytes(plistlib.dumps(requirements))
    return requirements


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("build", type=Path)
    parser.add_argument("base", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--delivery", choices=("auto", "web", "installer", "none"), default="auto")
    args = parser.parse_args()
    try:
        result = stage(args.build, args.base, args.delivery, args.output)
        print(json.dumps(result))
    except (OSError, KeyError, ValueError, zipfile.BadZipFile) as error:
        parser.exit(1, f"Runtime staging failed: {error}\n")
