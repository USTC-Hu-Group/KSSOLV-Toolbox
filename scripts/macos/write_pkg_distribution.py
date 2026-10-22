"""Write the native Installer choices and localized installation guidance."""
import html
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import sys
import xml.etree.ElementTree as ET
import zipfile


def runtime_license(resources, requirements):
    """Copy the vendor agreement verbatim; never substitute application terms."""
    release = requirements['RuntimeRelease']
    override = os.environ.get('MATLAB_RUNTIME_LICENSE')
    candidates = [Path(override)] if override else []
    candidates += [Path(f'/Applications/MATLAB/MATLAB_Runtime/{release}/matlabruntime_license_agreement.pdf')]
    destination = resources / 'RuntimeLicense.pdf'
    for candidate in candidates:
        if candidate.is_file():
            shutil.copyfile(candidate, destination)
            break
    else:
        cache = Path.home() / 'Library/Application Support/MathWorks/MatlabRuntimeCache' / (
            'MCRInstaller' + requirements['RuntimeVersion']) / f'MATLAB_Runtime_{release}_maca64.zip'
        if not cache.is_file():
            raise ValueError('The matching Runtime license is required. Set MATLAB_RUNTIME_LICENSE to the official PDF or download Runtime with compiler.runtime.download.')
        with zipfile.ZipFile(cache) as archive:
            destination.write_bytes(archive.read('matlabruntime_license_agreement.pdf'))
    assets = Path(__file__).parent / 'pkg'
    record = json.loads((assets / 'RuntimeLicense.json').read_text())
    text = assets / 'RuntimeLicense.txt'
    if (hashlib.sha256(destination.read_bytes()).hexdigest() != record['PDFSHA256'] or
            hashlib.sha256(text.read_bytes()).hexdigest() != record['TextSHA256']):
        raise ValueError('Runtime license changed; regenerate and verify the complete Installer text from the official PDF.')
    shutil.copyfile(text, resources / 'RuntimeLicense.txt')


def write(resources, output, requirements, version, application_license):
    mode, release = requirements["RuntimeDelivery"], requirements["RuntimeRelease"]
    root = ET.Element("installer-gui-script", minSpecVersion="2")
    ET.SubElement(root, "title").text = "KSSOLV Toolbox"
    ET.SubElement(root, "options", customize="always", rootVolumeOnly="true", hostArchitectures="arm64", **{"require-scripts": "true"})
    ET.SubElement(root, "domains", enable_anywhere="false", enable_currentUserHome="false", enable_localSystem="true")
    ET.SubElement(root, "welcome", file="welcome.html", **{"mime-type": "text/html"})
    ET.SubElement(root, "readme", file="readme.html", **{"mime-type": "text/html"})
    license_file = "ApplicationLicense.txt"
    shutil.copyfile(application_license, resources / license_file)
    if mode != "none":
        runtime_license(resources, requirements)
        # PackageKit has one agreement page. Keep the application terms first,
        # and disclose the vendor terms before prepare-runtime's silent install.
        license_file = "InstallerLicense.txt"
        (resources / license_file).write_text(
            "KSSOLV TOOLBOX LICENSE\n\n"
            + application_license.read_text(encoding="utf-8")
            + "\n\n" + "=" * 72 + "\n"
            + "THIRD-PARTY MATLAB RUNTIME LICENSE\n\n"
            + "The following terms apply to MATLAB Runtime. This package installs "
            "Runtime only if a compatible installation is not already available. "
            "These terms do not replace the KSSOLV Toolbox license above.\n\n"
            + (resources / "RuntimeLicense.txt").read_text(encoding="utf-8"),
            encoding="utf-8")
    ET.SubElement(root, "license", file=license_file, **{"mime-type": "text/plain"})
    outline = ET.SubElement(root, "choices-outline")
    components = []
    if mode == "none":
        ET.SubElement(outline, "line", choice="runtime-existing")
        existing = ET.SubElement(root, "choice", id="runtime-existing", title="EXISTING_RUNTIME_TITLE", description="EXISTING_RUNTIME_DESCRIPTION", selected="true", customLocation="/", customLocationAllowAlternateVolumes="true")
        ET.SubElement(existing, "pkg-ref", id="com.pwdft.kssolv.runtime-selection")
        components.append(("com.pwdft.kssolv.runtime-selection", "KSSOLVRuntime.pkg"))
    ET.SubElement(outline, "line", choice="runtime-support")
    ET.SubElement(outline, "line", choice="application")
    support = ET.SubElement(root, "choice", id="runtime-support", title="RUNTIME_TITLE", description="RUNTIME_DESCRIPTION", visible="false", selected="true")
    ET.SubElement(support, "pkg-ref", id="com.pwdft.kssolv.support")
    # Native Installer otherwise rejects folders on the startup disk's APFS Data volume.
    # The application is movable; system support keeps its fixed path.
    app = ET.SubElement(root, "choice", id="application", title="APP_TITLE", description="APP_DESCRIPTION", selected="true", customLocation="/Applications", customLocationAllowAlternateVolumes="true")
    ET.SubElement(app, "pkg-ref", id="com.pwdft.kssolv")
    components += [("com.pwdft.kssolv.support", "KSSOLVSupport.pkg"), ("com.pwdft.kssolv", "KSSOLVApplication.pkg")]
    for identifier, filename in components:
        ET.SubElement(root, "pkg-ref", id=identifier, version=version).text = filename
    ET.ElementTree(root).write(output, encoding="utf-8", xml_declaration=True)

    for language in ("en", "zh_CN", "zh-Hans"):
        directory = resources / (language + ".lproj")
        directory.mkdir(parents=True, exist_ok=True)
        chinese = language != "en"
        label = {"none": "仅应用 / 需要已有 Runtime", "web": "联网下载 Runtime", "installer": "离线 Runtime 随包提供"}[mode] if chinese else {
            "none": "Application only / existing Runtime required", "web": "Online Runtime download", "installer": "Offline Runtime included"}[mode]
        texts = {
            "APP_TITLE": "KSSOLV Toolbox",
            "APP_DESCRIPTION": (("选择应用安装目录。需已有兼容的 Runtime。" if chinese else "Choose the application folder. An existing compatible Runtime is required.") if mode == "none" else
                                ("选择应用安装目录。Runtime 自动检测，缺少时安装到默认位置。" if chinese else "Choose the application folder. Runtime is detected automatically and prepared at its default location when needed.")),
            "RUNTIME_TITLE": "MATLAB Runtime",
            "RUNTIME_DESCRIPTION": label,
            "EXISTING_RUNTIME_TITLE": "已有 MATLAB Runtime" if chinese else "Existing MATLAB Runtime",
            "EXISTING_RUNTIME_DESCRIPTION": (f"自动查找已安装的 MATLAB Runtime。未找到时，请点击“位置”→“其他…”，选择 {release} 文件夹。检查通过后才会替换旧版应用。" if chinese else
                                             f"Finds MATLAB Runtime automatically. If needed, choose Location > Other and select your {release} folder. Your current Toolbox is kept if Runtime checks fail."),
        }
        (directory / "Localizable.strings").write_text("\n".join(f'"{key}" = "{value}";' for key, value in texts.items()) + "\n", encoding="utf-8")
        heading = "安装 KSSOLV Toolbox" if chinese else "Install KSSOLV Toolbox"
        intro = f"版本 {version} · Apple silicon · MATLAB Runtime {release}" if chinese else f"Version {version} · Apple silicon · MATLAB Runtime {release}"
        steps = [
            "先检查已有 Runtime。版本、架构和所需组件匹配时直接复用。",
            (f"本安装包需要已有的 MATLAB Runtime {release}。未找到时，在“安装类型”页面选中“已有 MATLAB Runtime”，点击“位置”→“其他…”选择 {release} 文件夹。" if mode == "none" else
             "缺少 Runtime 时，从 MathWorks 下载并安装到默认位置。" if mode == "web" else "缺少 Runtime 时，从包内载荷离线安装到默认位置，无需联网。"),
            "Runtime 准备成功后，才卸载旧版 Toolbox 并安装新应用。",
            "安装类型页面中，选中 KSSOLV Toolbox 并使用位置控件选择应用目录。默认目录为 /Applications。",
            "最后在后台完成预热；不会打开 Toolbox 主窗口。",
        ] if chinese else [
            "Reuse an existing Runtime only when its release, architecture and required components match.",
            (f"This package requires an existing MATLAB Runtime {release}. If it is not found, select Existing MATLAB Runtime on Installation Type, choose Location > Other, and select the {release} folder." if mode == "none" else
             "If needed, download Runtime from MathWorks and install it at the default location." if mode == "web" else "If needed, install Runtime from the included offline payload without a network connection."),
            "Only after Runtime is ready, remove the previous Toolbox and install the new application.",
            "On Installation Type, select KSSOLV Toolbox and use its location control to choose the application folder. The default is /Applications.",
            "Complete application prewarm in the background without opening the Toolbox window.",
        ]
        body = f"<h1>{heading}</h1><p>{intro}</p><p>{html.escape(label)}</p>"
        details = body + "<ol>" + "".join("<li>" + html.escape(step) + "</li>" for step in steps) + "</ol>"
        details += f"<p>Runtime: /Applications/MATLAB/MATLAB_Runtime/{release}</p>"
        details += "<p>保留共享 Runtime、用户配置和项目；开始前请关闭正在运行的 Toolbox。</p>" if chinese else "<p>Shared Runtime, user settings and projects are retained. Close a running Toolbox before starting.</p>"
        template = '<!doctype html><meta charset="utf-8"><style>body{font:14px -apple-system;padding:16px;color:#173049}li{margin:9px 0}</style>'
        (directory / "welcome.html").write_text(template + body, encoding="utf-8")
        (directory / "readme.html").write_text(template + details, encoding="utf-8")


if __name__ == "__main__":
    resources, output, requirements, version, license_file = sys.argv[1:]
    write(Path(resources), Path(output), plistlib.loads(Path(requirements).read_bytes()), version, Path(license_file))
