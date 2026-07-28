classdef StructureIOTest < matlab.unittest.TestCase
    properties
        StructureDirectory
    end

    methods (TestClassSetup)
        function configureTestPaths(testCase)
            addpath(fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "+kssolv", "+core", "kssolv-3o"));
            KSSOLV.startup();
            fixtureRoot = fileparts(mfilename("fullpath"));
            testCase.StructureDirectory = ...
                fullfile(fixtureRoot, "Structure");
        end
    end

    methods (Test)
        function readsCifAsCrystal(testCase)
            source = fullfile(testCase.StructureDirectory, "Si.cif");
            warningID = "KSSOLV:Matgenlab:CifParser:ParseWarning";
            warningState = warning("query", warningID);
            cleanup = onCleanup(@() warning(warningState));
            warning("error", warningID);
            reader = kssolv.services.fileparser.StructureIO(source);
            factor = kssolv.analysis.matgenlab.core.UnitConstants. ...
                ang_to_bohr;

            testCase.verifyClass(reader.MatgenlabObject, ...
                "kssolv.analysis.matgenlab.core.Structure");
            testCase.verifyClass(reader.KSSOLVObject, "Crystal");
            testCase.verifyEqual(reader.MatgenlabObject.lattice.a, ...
                5.46872807, AbsTol = 1e-12);
            testCase.verifyEqual(reader.KSSOLVSetupObject.C, ...
                reader.MatgenlabObject.lattice.matrix * factor, ...
                AbsTol = 1e-12);
            testCase.verifyEqual(reader.KSSOLVSetupObject.xyzList, ...
                reader.MatgenlabObject.cart_coords * factor, ...
                AbsTol = 1e-12);
            clear cleanup
        end

        function readsAndRoundTripsPoscar(testCase)
            source = fullfile(testCase.StructureDirectory, "Si.vasp");
            target = string(tempname) + ".vasp";
            cleanup = onCleanup(@() cleanupFiles(target));
            reader = kssolv.services.fileparser.StructureIO(source);

            kssolv.services.fileparser.StructureIO.write( ...
                reader.KSSOLVObject, target, "poscar");
            restored = ...
                kssolv.services.fileparser.StructureIO.read(target);

            testCase.verifyClass(reader.KSSOLVObject, "Crystal");
            testCase.verifyEqual(restored.supercell, ...
                reader.KSSOLVObject.supercell, RelTol = 1e-8);
            testCase.verifyEqual(restored.xyzlist, ...
                reader.KSSOLVObject.xyzlist, AbsTol = 1e-7);
            clear cleanup
        end

        function readsMoleculeFormatsAndExportsCif(testCase)
            source = fullfile(testCase.StructureDirectory, "water.xyz");
            target = string(tempname) + ".cif";
            cleanup = onCleanup(@() cleanupFiles(target));

            reader = kssolv.services.fileparser.StructureIO(source);
            testCase.verifyClass(reader.MatgenlabObject, ...
                "kssolv.analysis.matgenlab.core.Molecule");
            testCase.verifyClass(reader.KSSOLVObject, "Molecule");
            testCase.verifyFalse(isa(reader.KSSOLVObject, "Crystal"));

            kssolv.services.fileparser.StructureIO.write( ...
                reader.KSSOLVObject, target, "cif");
            periodic = ...
                kssolv.services.fileparser.StructureIO.read(target);
            testCase.verifyClass(periodic, "Crystal");
            testCase.verifyEqual(numel(periodic.atomlist), 3);
            clear cleanup
        end

        function readsGeneralCifSyntaxThroughMatgenlab(testCase)
            source = string(tempname) + ".cif";
            compressed = source + ".gz";
            cleanup = onCleanup(@() cleanupFiles([source, compressed]));
            writeText(source, strjoin([ ...
                "data_general"
                "_cell_length_a 3.10(2)"
                "_cell_length_b 3.10(2)"
                "_cell_length_c 5.20(3)"
                "_cell_angle_alpha 90"
                "_cell_angle_beta 90"
                "_cell_angle_gamma 120"
                "_space_group_symop_operation_xyz 'x,y,z'"
                "loop_"
                "_atom_site_type_symbol"
                "_atom_site_label"
                "_atom_site_fract_x"
                "_atom_site_fract_y"
                "_atom_site_fract_z"
                "Si Si1 0 0 0"
                "Si Si2 0.33333333 0.66666667 0.5"
                ], newline));

            reader = kssolv.services.fileparser.StructureIO(source);

            testCase.verifyClass(reader.KSSOLVObject, "Crystal");
            testCase.verifyEqual(reader.MatgenlabObject.lattice.a, 3.1, ...
                AbsTol = 1e-12);
            testCase.verifyEqual(numel(reader.KSSOLVObject.atomlist), 2);

            gzip(source);
            compressedReader = ...
                kssolv.services.fileparser.StructureIO(compressed);
            testCase.verifyEqual( ...
                compressedReader.MatgenlabObject.lattice.a, 3.1, ...
                AbsTol = 1e-12);
            testCase.verifyEqual(compressedReader.rawFileContent, "");
            clear cleanup
        end

        function mapsDisorderedSitesDeterministically(testCase)
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                4 * eye(3), {struct("Si", 0.7, "C", 0.3)}, ...
                [0, 0, 0]);
            warning("off", ...
                "KSSOLV:FileParser:StructureIO:DisorderedSites");
            cleanup = onCleanup(@() warning("on", ...
                "KSSOLV:FileParser:StructureIO:DisorderedSites"));

            crystal = kssolv.services.fileparser.StructureIO. ...
                fromMatgenlab(structure);

            testCase.verifyClass(crystal, "Crystal");
            testCase.verifyEqual(string(crystal.atomlist.symbol), "Si");
            clear cleanup
        end

        function encodesInfoBrowserProjectionWithoutParserGraph(testCase)
            source = fullfile(testCase.StructureDirectory, "Si.vasp");
            reader = kssolv.services.fileparser.StructureIO(source);
            item = kssolv.services.filemanager.Structure("Si");
            item.data = reader;

            value = jsondecode(item.encode());

            testCase.verifyEqual(string(value.data.filePath), ...
                string(source));
            testCase.verifyTrue(isfield(value.data, ...
                "KSSOLVSetupObject"));
            testCase.verifyTrue(isfield(value.data, "rawFileContent"));
            testCase.verifyFalse(isfield(value.data, "MatgenlabObject"));
            testCase.verifyFalse(isfield(value.data, "KSSOLVObject"));
        end

        function materializesKssolvObjectOnDemand(testCase)
            source = fullfile(testCase.StructureDirectory, "water.xyz");

            reader = kssolv.services.fileparser.StructureIO(source);

            testCase.verifyEmpty(reader.KSSOLVObjectCache);
            testCase.verifyEqual(reader.KSSOLVSetupObject.atomList, ...
                {'O', 'H', 'H'});
            object = reader.KSSOLVObject;
            testCase.verifyClass(object, "Molecule");
            testCase.verifyNotEmpty(reader.KSSOLVObjectCache);
        end

        function fixturesCoverEveryRegisteredFormat(testCase)
            formats = ...
                kssolv.services.fileparser.StructureIO.supportedFormats();
            registered = unique([ ...
                formats.structureRead, formats.structureWrite, ...
                formats.moleculeRead, formats.moleculeWrite]);
            fixtures = fixtureManifest();

            testCase.verifyEqual(sort(fixtures.Format), ...
                sort(registered(:)));
            testCase.verifyEqual(numel(unique(fixtures.Format)), ...
                height(fixtures), ...
                "Each registered format must have exactly one fixture.");
            for index = 1:height(fixtures)
                path = fullfile(testCase.StructureDirectory, ...
                    fixtures.FileName(index));
                testCase.verifyTrue(isfile(path), ...
                    sprintf("Missing %s fixture: %s", ...
                    fixtures.Format(index), path));
            end
        end

        function readsEveryReadableFormatFixture(testCase)
            fixtures = fixtureManifest();
            fixtures = fixtures(fixtures.Readable, :);
            for index = 1:height(fixtures)
                fixture = fixtures(index, :);
                path = fullfile(testCase.StructureDirectory, ...
                    fixture.FileName);
                [object, matgenlabObject, detectedFormat] = ...
                    kssolv.services.fileparser.StructureIO.read( ...
                        path, fixture.Format);

                testCase.verifyEqual(detectedFormat, fixture.Format);
                if fixture.Kind == "structure"
                    testCase.verifyClass(object, "Crystal");
                    testCase.verifyTrue(isa(matgenlabObject, ...
                        "kssolv.analysis.matgenlab.core.IStructure"));
                else
                    testCase.verifyClass(object, "Molecule");
                    testCase.verifyFalse(isa(object, "Crystal"));
                    testCase.verifyTrue(isa(matgenlabObject, ...
                        "kssolv.analysis.matgenlab.core.IMolecule"));
                end
            end
        end
    end
end

function fixtures = fixtureManifest()
structureFormats = [ ...
    "cif", "config", "cssr", "exciting", "json", "lmto", "mcsqs", ...
    "mson", "poscar", "prismatic", "pwmat", "vasp", "yaml", "yml"];
structureFiles = [ ...
    "Si.cif", "Si.config", "Si.cssr", "Si.exciting.xml", "Si.json", ...
    "Si.lmto", "Si.mcsqs", "Si.mson", "Si.poscar", "Si.prismatic", ...
    "Si.pwmat", "Si.vasp", "Si.yaml", "Si.yml"];
moleculeFormats = [ ...
    "cml", "com", "g03", "g09", "gaussian", "gaussian-out", "gjf", ...
    "inp", "mdl", "ml2", "mol", "mol2", "mrv", "pdb", "sd", "sdf", ...
    "sy2", "xyz"];
moleculeFiles = [ ...
    "water.cml", "water.com", "water.g03", "water.g09", ...
    "water.gaussian", "water.gaussian-out", "water.gjf", "water.inp", ...
    "water.mdl", "water.ml2", "water.mol", "water.mol2", "water.mrv", ...
    "water.pdb", "water.sd", "water.sdf", "water.sy2", "water.xyz"];

formats = [structureFormats, moleculeFormats].';
files = [structureFiles, moleculeFiles].';
kinds = [repmat("structure", size(structureFormats)), ...
    repmat("molecule", size(moleculeFormats))].';
readable = formats ~= "prismatic";
fixtures = table(formats, files, kinds, readable, VariableNames = ...
    ["Format", "FileName", "Kind", "Readable"]);
end

function writeText(filePath, value)
file = fopen(filePath, "w", "n", "UTF-8");
if file < 0, error("Unable to create test file."); end
cleanup = onCleanup(@() fclose(file));
fwrite(file, char(value), "char");
clear cleanup
end

function cleanupFiles(paths)
for path = paths
    if isfile(path), delete(path); end
end
end
