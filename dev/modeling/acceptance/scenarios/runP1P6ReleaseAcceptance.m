function report = runP1P6ReleaseAcceptance(outputDirectory, closureEvidencePath)
%RUNP1P6RELEASEACCEPTANCE Run every automated P1-P6 production gate.
%
% `passed` means that all automated gates passed against the current worktree.
% `releaseReady` remains false until the separately recorded physical-pointer,
% 200% display, remaining real-pointer and independent-user gates are complete.

arguments
    outputDirectory string = ""
    closureEvidencePath string = ""
end
root = string(workingTreeRoot());
addpath(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(root, "+kssolv", "+core", "kssolv-3o"));
KSSOLV.startup();
if outputDirectory == ""
    stamp = string(datetime("now", "TimeZone", "local", ...
        "Format", "yyyyMMdd-HHmmss"));
    outputDirectory = fullfile(root, "dev", "modeling", ...
        "acceptance", "reports", "p1-p6-release-" + stamp);
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end

definitions = gateDefinitions();
gateResults = repmat(struct( ...
    "id", "", "phase", "", "passed", false, ...
    "durationSeconds", NaN, "reportPath", "", ...
    "outputDirectory", "", "error", ""), numel(definitions), 1);

for index = 1:numel(definitions)
    definition = definitions(index);
    gateDirectory = fullfile(outputDirectory, ...
        compose("%02d-%s", index, definition.id));
    started = tic;
    gate = gateResults(index);
    gate.id = definition.id;
    gate.phase = definition.phase;
    gate.outputDirectory = gateDirectory;
    gate.reportPath = fullfile(gateDirectory, "report.json");
    try
        nested = definition.runner(gateDirectory);
        gate.passed = isfield(nested, "passed") && nested.passed;
        if ~gate.passed
            gate.error = "Scenario returned passed=false.";
        end
    catch exception
        gate.error = string(getReport(exception, "extended", ...
            "hyperlinks", "off"));
        if isfile(gate.reportPath)
            persisted = jsondecode(fileread(gate.reportPath));
            if isfield(persisted, "error") && strlength(persisted.error) > 0
                gate.error = string(persisted.error);
            end
        end
    end
    gate.durationSeconds = toc(started);
    gateResults(index) = gate;
    drawnow;
end

manifestPath = fullfile(root, "+kssolv", "+ui", "+components", ...
    "+figuredocument", "@MoleculeDisplay", "CrystalViewer", ...
    "build-manifest.json");
manifest = jsondecode(fileread(manifestPath));
if closureEvidencePath == ""
    physicalEvidence = fullfile(root, "dev", "modeling", "acceptance", ...
        "reports", "p6-right-drag-20260812-160115", ...
        "physical-right-drag.json");
    if isfile(physicalEvidence)
        closureEvidencePath = physicalEvidence;
    else
        closureEvidencePath = fullfile(root, "dev", "modeling", ...
            "acceptance", "P1-P6-external-closure-template.json");
    end
end
externalClosure = auditP1P6ExternalClosure(closureEvidencePath);
openGates = strings(0, 1);
if ~externalClosure.checks.p1SignedAudit
    openGates(end+1, 1) = ...
        "P1: signed P1-P6 A1-A5, B1-B5, and C1-C5 audit";
end
if ~(externalClosure.checks.p6PhysicalRightDrag && ...
        externalClosure.checks.p6CoordinateGeometry && ...
        externalClosure.checks.p6ScreenshotEvidence)
    openGates(end+1, 1) = ...
        "P6: verified physical mouse-button-2 host-axis drag evidence";
end
if ~externalClosure.checks.p6VisualSignoff
    openGates(end+1, 1) = "P6: independent visual sign-off";
end
if ~(externalClosure.checks.schema && externalClosure.checks.runtime && ...
        externalClosure.checks.environment)
    openGates(end+1, 1) = ...
        "P1-P6: signed closure evidence must match the current runtime and environment";
end
automatedPassed = all([gateResults.passed]);
releaseReady = automatedPassed && externalClosure.passed;
report = struct( ...
    "phase", "P1-P6-release", ...
    "generatedAtUtc", string(datetime("now", "TimeZone", "UTC", ...
        "Format", "yyyy-MM-dd'T'HH:mm:ss'Z'")), ...
    "matlabRelease", string(version("-release")), ...
    "platform", string(computer), ...
    "runtimeRevision", string(manifest.sourceRevision), ...
    "runtimeSha256", string(manifest.entrySha256), ...
    "automatedGateCount", numel(gateResults), ...
    "automatedPassedCount", sum([gateResults.passed]), ...
    "automatedPassed", automatedPassed, ...
    "gates", gateResults, ...
    "externalClosure", externalClosure, ...
    "openClosureGates", openGates, ...
    "releaseReady", releaseReady, ...
    "passed", automatedPassed, ...
    "outputDirectory", outputDirectory);

writeText(fullfile(outputDirectory, "report.json"), ...
    jsonencode(report, PrettyPrint = true));
writeSummary(fullfile(outputDirectory, "summary.md"), report);
if ~report.passed
    failed = string({gateResults(~[gateResults.passed]).id});
    error("KSSOLV:Modeling:P1P6ReleaseAcceptance", ...
        "Automated P1-P6 gates failed: %s", strjoin(failed, ", "));
end
end

function definitions = gateDefinitions()
definitions = [ ...
    gate("p1-production", "P1", @runP1ProductionParityAcceptance)
    gate("p1-shortcuts", "P1", @runP1ShortcutLayoutAcceptance)
    gate("p1-molecule-editing", "P1", @runP1MoleculeEditingAcceptance)
    gate("p2-direct-manipulation", "P2", @runP2DirectManipulationAcceptance)
    gate("p2-pointer-evidence", "P2", ...
        @runP2ReferenceMoleculePointerEvidenceAcceptance)
    gate("p3-fragments", "P3", @runP3FragmentSketcherAcceptance)
    gate("p3-p4-molecule-builder", "P3-P4", ...
        @runP3P4MoleculeBuilderAcceptance)
    gate("p4-force-field", "P4", @runP4ForceFieldAcceptance)
    gate("p4-standard-molecules", "P4", ...
        @runP4StandardMoleculeOracleAcceptance)
    gate("p5-exact-geometry", "P5", @runP5ExactGeometryAcceptance)
    gate("p5-pointer-evidence", "P5", @runP5PointerEvidenceAcceptance)
    gate("p5-p6-crystal-surface", "P5-P6", ...
        @runP5P6CrystalSurfaceAcceptance)
    gate("p6-generic-adsorbate", "P6", ...
        @runP6GenericAdsorbateAcceptance)
    gate("p6-adsorption-locator", "P6", ...
        @runP6AdsorptionLocatorAcceptance)
    gate("p6-predictive-adsorption", "P6", ...
        @runP6PredictiveAdsorptionAcceptance)
    gate("modeling-icons", "P1-P6", @runModelingIconVisualAcceptance)];
end

function value = gate(id, phase, runner)
value = struct("id", id, "phase", phase, "runner", runner);
end

function writeSummary(path, report)
lines = [ ...
    "# P1–P6 automated release acceptance";
    "";
    "- MATLAB: " + report.matlabRelease + " / " + report.platform;
    "- Runtime SHA-256: `" + report.runtimeSha256 + "`";
    "- Automated gates: " + report.automatedPassedCount + "/" + ...
        report.automatedGateCount;
    "- Release ready: **" + lower(string(report.releaseReady)) + "**";
    "";
    "| Gate | Phase | Result | Seconds | Report |";
    "| --- | --- | --- | ---: | --- |"];
tableLines = strings(numel(report.gates), 1);
for index = 1:numel(report.gates)
    gateResult = report.gates(index);
    if gateResult.passed, result = "pass"; else, result = "fail"; end
    relativeReport = erase(gateResult.reportPath, report.outputDirectory + filesep);
    tableLines(index) = "| " + gateResult.id + " | " + ...
        gateResult.phase + " | " + result + " | " + ...
        compose("%.2f", gateResult.durationSeconds) + " | `" + ...
        relativeReport + "` |";
end
lines = [lines; tableLines; ""; "## Open closure gates"; ""; ...
    "- " + report.openClosureGates];
writeText(path, strjoin(lines, newline));
end

function writeText(path, value)
file = fopen(path, "w", "n", "UTF-8");
if file < 0
    error("KSSOLV:Modeling:AcceptanceWrite", ...
        "Cannot write acceptance report: %s", path);
end
cleanup = onCleanup(@()fclose(file));
fwrite(file, char(value), "char");
clear cleanup
end
