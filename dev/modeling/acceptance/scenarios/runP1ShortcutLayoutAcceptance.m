function report = runP1ShortcutLayoutAcceptance(outputDirectory)
%RUNP1SHORTCUTLAYOUTACCEPTANCE Capture the production shortcut dialog matrix.

arguments
    outputDirectory string = ""
end
root = workingTreeRoot();
addpath(fullfile(root, "+kssolv", "+core", "kssolv-3o"));
KSSOLV.startup();
if outputDirectory == ""
    stamp = string(datetime("now", "TimeZone", "local", ...
        "Format", "yyyyMMdd-HHmmss"));
    outputDirectory = fullfile(root, "dev", "modeling", ...
        "acceptance", "reports", "p1-shortcut-layout-" + stamp);
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end

manifestPath = fullfile(root, "+kssolv", "+ui", "+components", ...
    "+figuredocument", "@MoleculeDisplay", "CrystalViewer", ...
    "build-manifest.json");
manifest = jsondecode(fileread(manifestPath));
localizer = kssolv.ui.util.Localizer.getInstance();
originalLocale = string(localizer.currentLocale);
locales = ["en_US", "zh_CN"];
sizes = [1200, 800; 1440, 900; 1920, 1080];
tiers = ["common", "advanced"];
captures = repmat(struct( ...
    "locale", "", "tier", "", "requestedWindowPixels", zeros(1, 2), ...
    "actualWindowPixels", zeros(1, 2), ...
    "contentZoomPercent", 100, ...
    "actualImagePixels", zeros(1, 2), "path", "", "bytes", 0, ...
    "passed", false), numel(locales) * size(sizes, 1) * numel(tiers), 1);
report = struct( ...
    "phase", "P1", ...
    "gate", "production-shortcut-layout", ...
    "matlabRelease", string(version("-release")), ...
    "platform", string(computer), ...
    "startedAt", timestamp(), ...
    "outputDirectory", outputDirectory, ...
    "productionShell", false, ...
    "runtimeEntrySha256", string(manifest.entrySha256), ...
    "runtimeSourceRevision", string(manifest.sourceRevision), ...
    "captureCount", 0, ...
    "captures", captures, ...
    "passed", false, ...
    "error", "");

existing = kssolv.ui.util.DataStorage.getData("KSSOLVToolbox");
if isa(existing, "kssolv.KSSOLVToolbox") && isvalid(existing)
    error("KSSOLV:Modeling:ProductionQARequiresCleanSession", ...
        "Close the existing KSSOLV application before production QA.");
end
toolbox = kssolv();
cleanup = onCleanup(@()cleanupScenario(toolbox, originalLocale));
try
    app = toolbox.getAppContainer();
    app.Visible = true;
    app.WindowBounds = [40, 40, sizes(1, :)];
    report.productionShell = true;
    drawnow

    molecule = kssolv.analysis.matgenlab.core.Molecule( ...
        ["C", "C", "O", "H", "H", "H", "H", "H", "H"], ...
        [0, 0, 0; 1.50, 0, 0; 2.86, 0.35, 0; ...
        -0.40, 0.95, 0; -0.40, -0.48, 0.82; -0.40, -0.48, -0.82; ...
        1.85, -0.52, 0.88; 1.85, -0.52, -0.88; 3.42, -0.43, 0]);
    molecule.properties.topology = struct( ...
        "bonds", [1, 2, 1; 2, 3, 1; 1, 4, 1; 1, 5, 1; 1, 6, 1; ...
        2, 7, 1; 2, 8, 1; 3, 9, 1], "origin", "source");
    project = kssolv.ui.util.DataStorage.getData("Project");
    folder = project.findChildrenItem("Structure");
    item = folder.createBlankMolecule(false);
    item.label = "P1 Shortcut Layout";
    item.data = kssolv.services.fileparser.ModeledStructureData( ...
        molecule, item.label);
    item.showMoleculeDisplay();
    drawnow
    display = kssolv.ui.features.modeling.SessionRegistry. ...
        getInstance().getCurrentDisplay();
    assert(~isempty(display));

    captureIndex = 0;
    display.setContentZoom(100);
    for locale = locales
        kssolv.ui.util.Localizer.setLocale(locale);
        for sizeIndex = 1:size(sizes, 1)
            requestedSize = sizes(sizeIndex, :);
            app.WindowBounds = [40, 40, requestedSize];
            drawnow
            pause(0.25)
            actualBounds = app.WindowBounds;
            for tier = tiers
                captureIndex = captureIndex + 1;
                display.showShortcutHelp(tier);
                drawnow
                pause(0.45)
                localeSlug = replace(locale, "_", "-");
                filename = sprintf("shortcut-%s-%dx%d-%s.png", ...
                    localeSlug, requestedSize(1), requestedSize(2), tier);
                screenshot = fullfile(outputDirectory, filename);
                exportapp(display.Document.Figure, screenshot);
                imageInfo = imfinfo(screenshot);
                fileInfo = dir(screenshot);
                captures(captureIndex) = struct( ...
                    "locale", locale, ...
                    "tier", tier, ...
                    "requestedWindowPixels", requestedSize, ...
                    "actualWindowPixels", actualBounds(3:4), ...
                    "contentZoomPercent", 100, ...
                    "actualImagePixels", [imageInfo.Width, imageInfo.Height], ...
                    "path", string(screenshot), ...
                    "bytes", double(fileInfo.bytes), ...
                    "passed", imageInfo.Width >= 800 && ...
                    imageInfo.Height >= 500 && fileInfo.bytes > 10000);
            end
        end
    end
    zoomCaptures = repmat(captures(1), numel(locales)*numel(tiers), 1);
    display.setContentZoom(200);
    app.WindowBounds = [40, 40, sizes(1, :)];
    drawnow
    pause(0.35)
    for locale = locales
        kssolv.ui.util.Localizer.setLocale(locale);
        for tier = tiers
            index = (find(locales == locale, 1)-1)*numel(tiers) + ...
                find(tiers == tier, 1);
            display.showShortcutHelp(tier);
            drawnow
            pause(0.45)
            localeSlug = replace(locale, "_", "-");
            filename = sprintf("shortcut-%s-1200x800-%s-200-percent.png", ...
                localeSlug, tier);
            screenshot = fullfile(outputDirectory, filename);
            exportapp(display.Document.Figure, screenshot);
            imageInfo = imfinfo(screenshot); fileInfo = dir(screenshot);
            zoomCaptures(index) = struct( ...
                "locale", locale, "tier", tier, ...
                "requestedWindowPixels", sizes(1, :), ...
                "actualWindowPixels", app.WindowBounds(3:4), ...
                "contentZoomPercent", 200, ...
                "actualImagePixels", [imageInfo.Width, imageInfo.Height], ...
                "path", string(screenshot), "bytes", double(fileInfo.bytes), ...
                "passed", imageInfo.Width >= 800 && ...
                    imageInfo.Height >= 500 && fileInfo.bytes > 10000);
        end
    end
    captures = [captures; zoomCaptures];
    display.setContentZoom(100);
    report.captureCount = captureIndex;
    report.captures = captures;
    report.captureCount = numel(captures);
    report.passed = report.productionShell && report.captureCount == 16 && ...
        all([captures.passed]);
catch exception
    report.error = string(getReport(exception, "extended", ...
        "hyperlinks", "off"));
end
report.finishedAt = timestamp();
writeText(fullfile(outputDirectory, "report.json"), ...
    jsonencode(report, PrettyPrint = true));
if ~report.passed
    error("KSSOLV:Modeling:AcceptanceP1ShortcutLayout", "%s", report.error);
end
clear cleanup
drawnow
pause(1)
drawnow
end

function value = timestamp()
value = string(datetime("now", "TimeZone", "local", ...
    "Format", "yyyy-MM-dd'T'HH:mm:ssXXX"));
end

function writeText(path, value)
file = fopen(path, "w", "n", "UTF-8");
if file < 0
    error("KSSOLV:Modeling:AcceptanceWrite", ...
        "Unable to create acceptance report '%s'.", path);
end
cleanup = onCleanup(@()fclose(file));
fwrite(file, char(value), "char");
clear cleanup
end

function cleanupScenario(toolbox, originalLocale)
kssolv.ui.util.Localizer.setLocale(originalLocale);
registry = kssolv.ui.util.DataStorage.getData("ModelingSessionRegistry");
if ~isempty(registry) && isvalid(registry), delete(registry); end
if ~isempty(toolbox) && isvalid(toolbox), delete(toolbox); end
kssolv.ui.util.DataStorage.removeData("Project");
kssolv.ui.util.DataStorage.removeData("ProjectFilename");
end
