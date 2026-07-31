classdef VolumeIOTest < matlab.unittest.TestCase
    properties
        VolumeDirectory
    end

    methods (TestClassSetup)
        function configureTestPaths(testCase)
            addpath(fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "+kssolv", "+core", "kssolv-3o"));
            KSSOLV.startup();
            fixtureRoot = fileparts(mfilename("fullpath"));
            testCase.VolumeDirectory = fullfile(fixtureRoot, "Volume");
        end
    end

    methods (Test)
        function registryDetectsCompressedAndExplicitFormats(testCase)
            registry = ...
                kssolv.services.fileparser.volume.VolumeFormatRegistry;

            testCase.verifyEqual(registry.detect("CHGCAR.spin.gz"), ...
                "chgcar");
            testCase.verifyEqual(registry.detect("density.cube.gz"), ...
                "cube");
            testCase.verifyEqual(registry.detect("density.cube.bz2"), ...
                "cube");
            testCase.verifyEqual(registry.detect("density.xsf"), "xsf");
            testCase.verifyEqual(registry.detect("any.file", "vasp"), ...
                "chgcar");
            testCase.verifyEqual( ...
                kssolv.services.fileparser.VolumeIO.supportedFormats(), ...
                ["chgcar", "cube", "xsf"]);
            filters = ...
                kssolv.services.fileparser.VolumeIO.fileFilters();
            testCase.verifySize(filters, [5, 2]);
            testCase.verifyTrue(contains(filters{1, 1}, "*.cube.bz2"));
            testCase.verifyTrue(contains(filters{1, 1}, "*.xsf.bz2"));
            testCase.verifyFalse(contains(filters{1, 1}, "CHGCAR*"));
            testCase.verifyEqual(filters{2, 1}, '*.*');
        end

        function volumeDialogFiltersAreLocalized(testCase)
            localizer = kssolv.ui.util.Localizer.getInstance();
            originalLocale = localizer.currentLocale;
            cleanup = onCleanup(@() ...
                kssolv.ui.util.Localizer.setLocale(originalLocale));

            kssolv.ui.util.Localizer.setLocale("en_US");
            english = ...
                kssolv.services.fileparser.FileDialogRegistry. ...
                volumeFilters();
            testCase.verifyEqual(english{1, 2}, ...
                'Volume data (CHGCAR, Cube, XSF)');
            testCase.verifyEqual(english{5, 2}, 'All files (*.*)');

            kssolv.ui.util.Localizer.setLocale("zh_CN");
            chinese = ...
                kssolv.services.fileparser.FileDialogRegistry. ...
                volumeFilters();
            testCase.verifyEqual(chinese{1, 2}, ...
                '体数据（CHGCAR、Cube、XSF）');
            testCase.verifyEqual(chinese{5, 2}, '所有文件（*.*）');
            clear cleanup
        end

        function fixtureManifestHashesMatchRepositoryFiles(testCase)
            manifestPath = fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "+kssolv", "+ui", "+test", "+fixtures", ...
                "+volume", "manifest.json");
            manifest = jsondecode(fileread(manifestPath));
            testCase.verifyEqual(string(manifest.schemaVersion), "1.0");
            testCase.verifyNumElements(manifest.fixtures, 13);
            for fixtureIndex = 1:numel(manifest.fixtures)
                if iscell(manifest.fixtures)
                    fixture = manifest.fixtures{fixtureIndex};
                else
                    fixture = manifest.fixtures(fixtureIndex);
                end
                testCase.verifyTrue(isfield(fixture, "source"));
                testCase.verifyTrue(isfield(fixture, "license"));
                testCase.verifyTrue(isfield(fixture, "redistributable"));
                testCase.verifyTrue(isfield(fixture, "oracle"));
                testCase.verifyTrue(fixture.redistributable);
                if ~isfield(fixture, "file"), continue; end
                filePath = fullfile(testCase.VolumeDirectory, ...
                    fixture.file);
                info = dir(filePath);
                testCase.verifyNotEmpty(info, ...
                    "Fixture is missing: " + string(fixture.file));
                testCase.verifyEqual(info.bytes, fixture.bytes);
                testCase.verifyEqual(sha256(filePath), ...
                    string(fixture.sha256));
            end
        end

        function readsNonSpinChgcarAsPhysicalDensity(testCase)
            source = fullfile(testCase.VolumeDirectory, ...
                "CHGCAR.nospin.gz");
            reader = kssolv.services.fileparser.VolumeIO(source);
            dataset = reader.Dataset;
            total = dataset.getChannel("total");

            testCase.verifyEqual(reader.fileType, "chgcar");
            testCase.verifyEqual(dataset.dimensions, [32, 32, 32]);
            testCase.verifyEqual(dataset.periodic, [true, true, true]);
            testCase.verifyEqual(dataset.sampling, "cell-periodic");
            testCase.verifyEqual(dataset.numChannels, 1);
            testCase.verifyEqual(dataset.structure.num_sites, 1);
            testCase.verifyEqual(dataset.origin, [0, 0, 0]);
            testCase.verifyEqual(dataset.voxelVectors .* ...
                dataset.dimensions.', ...
                dataset.structure.lattice.matrix, AbsTol = 1e-12);
            testCase.verifyEqual(total.units, "1/Angstrom^3");
            testCase.verifyGreaterThan(total.maximum, total.minimum);
            testCase.verifyEqual(total.integral, 1, AbsTol = 5e-6);
        end

        function readsSpinChgcarWithSignedMagnetization(testCase)
            source = fullfile(testCase.VolumeDirectory, ...
                "CHGCAR.spin.gz");
            dataset = ...
                kssolv.services.fileparser.VolumeIO(source).Dataset;
            total = dataset.getChannel("total");
            difference = dataset.getChannel("diff");

            testCase.verifyEqual(dataset.dimensions, [48, 48, 48]);
            testCase.verifyEqual(dataset.numChannels, 4);
            testCase.verifyFalse(total.signed);
            testCase.verifyTrue(difference.signed);
            testCase.verifyEqual(total.integral, 1, AbsTol = 5e-6);
            testCase.verifyLessThan(abs(difference.integral), 1.1);
            up = dataset.getChannel("up");
            down = dataset.getChannel("down");
            testCase.verifyEqual(up.values, ...
                0.5 * (total.values + difference.values), ...
                AbsTol = 1e-14);
            testCase.verifyEqual(down.values, ...
                0.5 * (total.values - difference.values), ...
                AbsTol = 1e-14);
        end

        function frozenProbeOraclesDetectAxisAndChannelOrdering(testCase)
            fixtures = { ...
                "CHGCAR.nospin.gz", ...
                [1,1,1;2,3,5;4,7,11;8,13,17; ...
                16,9,25;21,31,6;29,18,23;32,32,32], ...
                "total", ...
                [0.021868845362317032,0.02490403178290124, ...
                0.038474555021426424,0.052514147012186346, ...
                0.054642310491674201,0.052935400178042422, ...
                0.051821599266975757,0.022152962496688113]; ...
                "CHGCAR.spin.gz", ...
                [1,1,1;2,3,5;4,7,11;8,13,17; ...
                16,9,25;21,31,6;29,18,23;48,48,48], ...
                "total", ...
                [0.021909391908936222,0.023330392424424289, ...
                0.029522582306465043,0.040908674077704404, ...
                0.052380267568384313,0.054524331109023327, ...
                0.053793181855133577,0.022038540528148218]; ...
                "CHGCAR.spin.gz", ...
                [1,1,1;2,3,5;4,7,11;8,13,17; ...
                16,9,25;21,31,6;29,18,23;48,48,48], ...
                "diff", ...
                [-0.00013564578577838896,-0.00045761517954824213, ...
                -0.0010173899126140048,-0.0010546946113583089, ...
                -0.0010364489608627402,-0.00095187854860692537, ...
                -0.00097123404808947941,-0.00016724530095209658]; ...
                "elec.cube.gz", ...
                [1,1,1;2,3,5;4,7,11;8,13,17; ...
                16,9,23;21,22,6;23,18,20;23,23,24], ...
                "total", ...
                [0.0035896000000000001,0.012139, ...
                0.011391999999999999,0.007737,1.9976, ...
                0.070488999999999996,0.010522, ...
                0.0036554000000000001] ...
                };
            loaded = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            for fixtureIndex = 1:size(fixtures, 1)
                file = string(fixtures{fixtureIndex, 1});
                key = char(file);
                if ~isKey(loaded, key)
                    loaded(key) = ...
                        kssolv.services.fileparser.VolumeIO( ...
                        fullfile(testCase.VolumeDirectory, file)).Dataset;
                end
                dataset = loaded(key);
                values = dataset.getChannel( ...
                    string(fixtures{fixtureIndex, 3})).values;
                indices = fixtures{fixtureIndex, 2};
                actual = zeros(1, size(indices, 1));
                for probeIndex = 1:size(indices, 1)
                    index = num2cell(indices(probeIndex, :));
                    actual(probeIndex) = values(index{:});
                end
                testCase.verifyEqual(actual, ...
                    fixtures{fixtureIndex, 4}, AbsTol = 1e-14);
            end
        end

        function readsCubeGeometryInAngstrom(testCase)
            source = fullfile(testCase.VolumeDirectory, "elec.cube.gz");
            dataset = ...
                kssolv.services.fileparser.VolumeIO(source).Dataset;
            conversion = ...
                kssolv.analysis.matgenlab.core.UnitConstants. ...
                bohr_to_angstrom;
            total = dataset.getChannel("total");

            testCase.verifyEqual(dataset.dimensions, [23, 23, 24]);
            testCase.verifyEqual(dataset.structure.num_sites, 9);
            testCase.verifyEqual(dataset.origin, [0, 0, 0]);
            testCase.verifyEqual(dataset.voxelVectors(1, :), ...
                [0.238313, -0.348954, 0] * conversion, ...
                AbsTol = 1e-12);
            testCase.verifyEqual(dataset.periodic, ...
                [false, false, false]);
            testCase.verifyEqual(dataset.sampling, "point-inclusive");
            testCase.verifyEqual(size(total.values), [23, 23, 24]);
            testCase.verifyTrue(isfinite(total.integral));
        end

        function readsXsfGridGeometryAndValues(testCase)
            source = fullfile(testCase.VolumeDirectory, ...
                "datagrid_3d.xsf");
            dataset = ...
                kssolv.services.fileparser.VolumeIO(source).Dataset;
            density = dataset.getChannel("grid_density");

            testCase.verifyEqual(dataset.dimensions, [2, 2, 2]);
            testCase.verifyEqual(dataset.dimensionality, 3);
            testCase.verifyEqual(dataset.origin, [0, 0, 0]);
            testCase.verifyEqual(dataset.voxelVectors, 2 * eye(3));
            testCase.verifyEqual(dataset.periodic, [true, true, true]);
            testCase.verifyEqual(density.values, reshape(0:7, [2, 2, 2]));
        end

        function gzipXsfNormalizesIdentically(testCase)
            directory = string(tempname);
            mkdir(directory);
            cleanup = onCleanup(@() rmdir(directory, "s"));
            source = fullfile(testCase.VolumeDirectory, ...
                "datagrid_3d.xsf");
            plain = fullfile(directory, "density.xsf");
            copyfile(source, plain);
            gzipFiles = gzip(plain, directory);
            expected = ...
                kssolv.services.fileparser.VolumeIO(plain).Dataset;

            actual = ...
                kssolv.services.fileparser.VolumeIO( ...
                string(gzipFiles{1})).Dataset;
            testCase.verifyEqual(actual.dimensions, expected.dimensions);
            testCase.verifyEqual(actual.origin, expected.origin);
            testCase.verifyEqual(actual.voxelVectors, ...
                expected.voxelVectors);
            testCase.verifyEqual( ...
                actual.getChannel("grid_density").values, ...
                expected.getChannel("grid_density").values);
            clear cleanup
        end

        function manifestExcludesHeavyVoxelPayload(testCase)
            source = fullfile(testCase.VolumeDirectory, ...
                "datagrid_3d.xsf");
            reader = kssolv.services.fileparser.VolumeIO(source);
            manifest = reader.Dataset.manifest();
            info = reader.toInfoStruct();

            testCase.verifyEqual(manifest.schemaVersion, "1.0");
            testCase.verifyEqual(manifest.kind, "volume");
            testCase.verifyFalse(isfield(manifest.channels, "values"));
            testCase.verifyEqual(manifest.structure.formula, "Ne");
            testCase.verifyEqual(numel(info.datasets), 1);
            testCase.verifyFalse(contains(jsonencode(info), ...
                '"values"'));
        end

        function cubeRetainsNonzeroOriginAndAngstromSign(testCase)
            source = string(tempname) + ".cube";
            cleanup = onCleanup(@() deleteIfPresent(source));
            writeText(source, strjoin([ ...
                "origin fixture"
                "negative dimensions use Angstrom"
                "1 1.5 -2.0 0.25"
                "-2 0.5 0 0"
                "-2 0 0.75 0"
                "-2 0 0 1.25"
                "1 0 1.5 -2.0 0.25"
                "0 1 2 3 4 5 6 7"
                ], newline));

            dataset = ...
                kssolv.services.fileparser.VolumeIO(source).Dataset;

            testCase.verifyEqual(dataset.origin, [1.5, -2, 0.25]);
            testCase.verifyEqual(dataset.voxelVectors, ...
                diag([0.5, 0.75, 1.25]));
            testCase.verifyEqual(dataset.structure.cart_coords, ...
                [1.5, -2, 0.25]);
            clear cleanup
        end

        function cubeReadsNegativeAtomCountDatasetIdentifiers(testCase)
            source = string(tempname) + ".cube";
            cleanup = onCleanup(@() deleteIfPresent(source));
            writeText(source, strjoin([ ...
                "orbital fixture"
                "two values at every voxel"
                "-1 0 0 0"
                "-2 1 0 0"
                "-2 0 1 0"
                "-2 0 0 1"
                "1 0 0 0 0"
                "2 5 7"
                "1 -1 2 -2 3 -3 4 -4 5 -5 6 -6 7 -7 8 -8"
                ], newline));

            dataset = ...
                kssolv.services.fileparser.VolumeIO(source).Dataset;

            testCase.verifyEqual(dataset.numChannels, 2);
            expected = permute(reshape(1:8, [2, 2, 2]), [3, 2, 1]);
            testCase.verifyEqual(dataset.getChannel("total").values, ...
                expected);
            testCase.verifyEqual( ...
                dataset.getChannel("dataset_7").values, ...
                -expected);
            clear cleanup
        end

        function cubeReadsPositiveAtomCountNvalChannels(testCase)
            source = string(tempname) + ".cube";
            cleanup = onCleanup(@() deleteIfPresent(source));
            writeText(source, strjoin([ ...
                "NVAL fixture"
                "two interleaved values"
                "1 0 0 0 2"
                "-2 1 0 0"
                "-2 0 1 0"
                "-2 0 0 1"
                "1 0 0 0 0"
                "1 -1 2 -2 3 -3 4 -4 5 -5 6 -6 7 -7 8 -8"
                ], newline));

            dataset = ...
                kssolv.services.fileparser.VolumeIO(source).Dataset;

            testCase.verifyEqual(dataset.numChannels, 2);
            expected = permute(reshape(1:8, [2, 2, 2]), [3, 2, 1]);
            testCase.verifyEqual(dataset.getChannel("total").values, ...
                expected);
            testCase.verifyEqual( ...
                dataset.getChannel("dataset_2").values, ...
                -expected);
            clear cleanup
        end

        function readsMultipleLabeledXsfDatagrids(testCase)
            source = string(tempname) + ".xsf";
            cleanup = onCleanup(@() deleteIfPresent(source));
            writeText(source, strjoin([ ...
                "CRYSTAL"
                "PRIMVEC"
                "2 0 0"
                "0 2 0"
                "0 0 2"
                "PRIMCOORD"
                "1 1"
                "Ne 0 0 0"
                "BEGIN_BLOCK_DATAGRID_3D"
                "fields"
                "BEGIN_DATAGRID_3D_density"
                "2 2 2"
                "0 0 0"
                "2 0 0"
                "0 2 0"
                "0 0 2"
                "0 1 2 3 4 5 6 7"
                "END_DATAGRID_3D"
                "BEGIN_DATAGRID_3D_potential"
                "2 2 2"
                "0 0 0"
                "2 0 0"
                "0 2 0"
                "0 0 2"
                "10 11 12 13 14 15 16 17"
                "END_DATAGRID_3D"
                "END_BLOCK_DATAGRID_3D"
                ], newline));

            dataset = ...
                kssolv.services.fileparser.VolumeIO(source).Dataset;

            testCase.verifyEqual(dataset.numChannels, 2);
            testCase.verifyEqual( ...
                dataset.getChannel("grid_density").values, ...
                reshape(0:7, [2, 2, 2]));
            testCase.verifyEqual( ...
                dataset.getChannel("grid_potential").values, ...
                reshape(10:17, [2, 2, 2]));
            clear cleanup
        end

        function derivesNoncollinearMagnetizationMagnitude(testCase)
            source = fullfile(tempdir, "CHGCAR.noncol-" + ...
                string(matlab.lang.internal.uuid));
            cleanup = onCleanup(@() deleteIfPresent(source));
            structure = ...
                kssolv.analysis.matgenlab.core.Structure( ...
                eye(3), {"Ne"}, [0, 0, 0]);
            probe = reshape(1:8, [2, 2, 2]);
            data = struct( ...
                "total", probe, ...
                "diff_x", probe, ...
                "diff_y", 2 * probe, ...
                "diff_z", 3 * probe);
            value = kssolv.analysis.matgenlab.io.vasp.Chgcar( ...
                structure, data);
            value.write_file(source);

            dataset = ...
                kssolv.services.fileparser.VolumeIO(source).Dataset;

            testCase.verifyEqual(dataset.numChannels, 6);
            testCase.verifyEqual( ...
                dataset.getChannel( ...
                "magnetization_magnitude").values, ...
                sqrt(14) * probe, AbsTol = 1e-12);
            clear cleanup
        end

        function rejectsMalformedOrUnsupportedInput(testCase)
            source = string(tempname) + ".cube";
            cleanup = onCleanup(@() deleteIfPresent(source));
            writeText(source, strjoin([ ...
                "bad cube"
                "mixed voxel units"
                "0 0 0 0"
                "-1 1 0 0"
                "1 0 1 0"
                "-1 0 0 1"
                "0"
                ], newline));

            testCase.verifyError(@() ...
                kssolv.services.fileparser.VolumeIO(source), ...
                "KSSOLV:FileParser:VolumeIO:ParseFileError");
            testCase.verifyError(@() ...
                kssolv.services.fileparser.volume. ...
                VolumeFormatRegistry.detect("unknown.bin"), ...
                "KSSOLV:FileParser:VolumeFormat:Unsupported");
            clear cleanup
        end

        function rejectsUnsafeGridDeclarationsBeforeAllocation(testCase)
            limits = ...
                kssolv.services.fileparser.volume.VolumeLimits;
            testCase.verifyEqual( ...
                limits.validateDimensions([256, 256, 256]), ...
                256^3);
            testCase.verifyError(@() ...
                limits.validateDimensions([0, 2, 2]), ...
                "KSSOLV:FileParser:VolumeLimits:Dimensions");
            testCase.verifyError(@() ...
                limits.validateDimensions([257, 256, 256]), ...
                "KSSOLV:FileParser:VolumeLimits:VoxelCount");
            testCase.verifyError(@() ...
                limits.validateDimensions([flintmax, 2, 1]), ...
                "KSSOLV:FileParser:VolumeLimits:Overflow");
            testCase.verifyError(@() ...
                limits.validateDimensions([2, 2, 2], 65), ...
                "KSSOLV:FileParser:VolumeLimits:Channels");
            testCase.verifyError(@() ...
                limits.validateDimensions([256, 256, 256], 17), ...
                "KSSOLV:FileParser:VolumeLimits:DecodedBytes");

            cube = string(tempname) + ".cube";
            cubeCleanup = onCleanup(@() deleteIfPresent(cube));
            writeText(cube, strjoin([ ...
                "unsafe cube"
                "must fail before payload allocation"
                "0 0 0 0"
                "1000000 1 0 0"
                "1000000 0 1 0"
                "1000000 0 0 1"
                ], newline));
            cubeError = captureException(@() ...
                kssolv.services.fileparser.VolumeIO(cube));
            testCase.verifyEqual(string(cubeError.identifier), ...
                "KSSOLV:FileParser:VolumeIO:ParseFileError");
            testCase.verifyEqual(string(cubeError.cause{1}.identifier), ...
                "KSSOLV:Matgenlab:VolumetricData:GridLimit");

            xsf = string(tempname) + ".xsf";
            xsfCleanup = onCleanup(@() deleteIfPresent(xsf));
            writeText(xsf, strjoin([ ...
                "BEGIN_BLOCK_DATAGRID_3D"
                "unsafe"
                "BEGIN_DATAGRID_3D_density"
                "1000000 1000000 1000000"
                ], newline));
            xsfError = captureException(@() ...
                kssolv.services.fileparser.VolumeIO(xsf));
            testCase.verifyEqual(string(xsfError.identifier), ...
                "KSSOLV:FileParser:VolumeIO:ParseFileError");
            testCase.verifyEqual(string(xsfError.cause{1}.identifier), ...
                "KSSOLV:Matgenlab:XSF:GridLimit");
            clear cubeCleanup xsfCleanup
        end

        function buildsDetachedVolumeSceneTransport(testCase)
            source = fullfile(testCase.VolumeDirectory, ...
                "datagrid_3d.xsf");
            dataset = ...
                kssolv.services.fileparser.VolumeIO(source).Dataset;

            [scene, payloads] = ...
                kssolv.ui.scene.volume.VolumeSceneBuilder.build( ...
                dataset, requestId = "request-17");

            testCase.verifyEqual(scene.requestId, "request-17");
            testCase.verifyEqual(scene.transport.protocol, ...
                "chunked-binary");
            testCase.verifyEqual( ...
                scene.channels.transport.elementCount, 8);
            testCase.verifyEqual( ...
                scene.channels.transport.byteLength, 32);
            testCase.verifyClass(payloads.values, "single");
            payloadBytes = typecast(payloads.values(:), "uint8");
            [~, ~, endian] = computer;
            if endian ~= "L"
                payloadBytes = typecast( ...
                    swapbytes(payloads.values(:)), "uint8");
            end
            testCase.verifyEqual(scene.channels.transport.crc32, ...
                double(kssolv.ui.scene.volume.VolumeChunkEncoder. ...
                crc32(payloadBytes)));
            testCase.verifyFalse(contains(jsonencode(scene), ...
                '"values"'));
            testCase.verifyWarningFree(@() ...
                kssolv.ui.scene.volume.VolumeSceneValidator.validate(scene));
            transportScene = ...
                kssolv.ui.scene.volume.VolumeSceneSerializer. ...
                transportScene(scene);
            encodedScene = jsonencode(transportScene);
            testCase.verifyTrue(contains(encodedScene, ...
                '"channels":[{'));
            testCase.verifyTrue(contains(encodedScene, ...
                '"warnings":[]'));
            testCase.verifyTrue(contains(encodedScene, ...
                '"atomicOverlay":null'));

            [quantizedScene, quantizedPayload] = ...
                kssolv.ui.scene.volume.VolumeSceneBuilder.build( ...
                dataset, requestId = "request-uint16", ...
                encoding = "uint16-linear-le");
            transport = quantizedScene.channels.transport;
            reconstructed = ...
                double(quantizedPayload.values) * transport.scale + ...
                transport.offset;
            expected = double(dataset.channels.values);
            testCase.verifyClass(quantizedPayload.values, "uint16");
            testCase.verifyEqual(transport.byteLength, 16);
            testCase.verifyLessThanOrEqual( ...
                max(abs(reconstructed(:) - expected(:))), ...
                transport.scale + 1e-12);
            testCase.verifyWarningFree(@() ...
                kssolv.ui.scene.volume.VolumeSceneValidator. ...
                validate(quantizedScene));

            namespacedScene = ...
                kssolv.ui.scene.volume.VolumeSceneBuilder.build( ...
                dataset, requestId = "request-progressive", ...
                transportNamespace = "request-progressive:preview");
            testCase.verifyEqual( ...
                namespacedScene.channels.transport.transferId, ...
                "request-progressive:preview:grid_density");
        end

        function transportSceneSerializesWarningsAsSchemaObjects(testCase)
            source = fullfile(testCase.VolumeDirectory, ...
                "datagrid_3d.xsf");
            dataset = ...
                kssolv.services.fileparser.VolumeIO(source).Dataset;
            preview = ...
                kssolv.ui.scene.volume.VolumeLodBuilder. ...
                previewDataset(dataset, 4);
            scene = kssolv.ui.scene.volume.VolumeSceneBuilder.build( ...
                preview, requestId = "request-warning");

            encoded = jsonencode( ...
                kssolv.ui.scene.volume.VolumeSceneSerializer. ...
                transportScene(scene));

            testCase.verifyTrue(contains(encoded, ...
                '"warnings":[{"code":"volume-warning-1"'));
            testCase.verifyTrue(contains(encoded, ...
                '"severity":"warning"'));
        end

        function validatorRejectsTransportSizeMismatch(testCase)
            source = fullfile(testCase.VolumeDirectory, ...
                "datagrid_3d.xsf");
            dataset = ...
                kssolv.services.fileparser.VolumeIO(source).Dataset;
            scene = kssolv.ui.scene.volume.VolumeSceneBuilder.build( ...
                dataset, requestId = "request-invalid");
            scene.channels.transport.byteLength = 28;

            testCase.verifyError(@() ...
                kssolv.ui.scene.volume.VolumeSceneValidator.validate(scene), ...
                "KSSOLV:UI:Volume:SceneByteLength");
        end

        function chunkEncoderRoundTripsLittleEndianPayload(testCase)
            payload = struct( ...
                "transferId", "request:data", ...
                "channelId", "data", ...
                "encoding", "float32-le", ...
                "values", single([1.25, -2.5, 4, 8]));

            chunks = kssolv.ui.scene.volume.VolumeChunkEncoder.encode( ...
                "request", payload, 7);
            bytes = zeros(1, 0, "uint8");
            for chunk = chunks
                testCase.verifyEqual( ...
                    kssolv.ui.scene.volume.VolumeChunkEncoder.crc32( ...
                    matlab.net.base64decode(chunk.data)), ...
                    uint32(chunk.crc32));
                bytes = [bytes, ...
                    matlab.net.base64decode(chunk.data)]; %#ok<AGROW>
            end
            values = typecast(bytes, "single");
            [~, ~, endian] = computer;
            if endian ~= "L", values = swapbytes(values); end
            testCase.verifyEqual(values, payload.values);
        end

        function readsTwoDimensionalXsfGrid(testCase)
            source = string(tempname) + ".xsf";
            cleanup = onCleanup(@() deleteIfPresent(source));
            writeText(source, strjoin([ ...
                "SLAB"
                "PRIMVEC"
                "2 0 0"
                "0.5 3 0"
                "0 0 12"
                "PRIMCOORD"
                "1 1"
                "6 0 0 0"
                "BEGIN_BLOCK_DATAGRID_2D"
                "plane"
                "BEGIN_DATAGRID_2D_rho"
                "2 4"
                "1 2 3"
                "2 0 0"
                "0.5 3 0"
                "0 1 2 3 4 5 6 7"
                "END_DATAGRID_2D"
                "END_BLOCK_DATAGRID_2D"
                ], newline));

            dataset = ...
                kssolv.services.fileparser.VolumeIO(source).Dataset;

            testCase.verifyEqual(dataset.dimensionality, 2);
            testCase.verifyEqual(dataset.dimensions, [2, 4, 1]);
            testCase.verifyEqual(dataset.origin, [1, 2, 3]);
            testCase.verifyEqual(dataset.voxelVectors(1:2, :), ...
                [2, 0, 0; 1 / 6, 1, 0], AbsTol = 1e-12);
            testCase.verifyEqual(dataset.periodic, [true, true, false]);
            clear cleanup
        end

        function lodPreviewPreservesPointInclusiveExtent(testCase)
            dimensions = [41, 31, 21];
            values = reshape(1:prod(dimensions), dimensions);
            structure = ...
                kssolv.analysis.matgenlab.core.Structure( ...
                diag([8, 6, 4]), {"Ne"}, [0, 0, 0]);
            channel = ...
                kssolv.services.fileparser.volume. ...
                VolumeStatistics.channel("rho", "Density", ...
                "arbitrary", values);
            dataset = kssolv.services.fileparser.VolumeDataset( ...
                source = struct("format", "xsf", "name", "lod", ...
                "normalization", "source-values"), ...
                structure = structure, dimensionality = 3, ...
                dimensions = dimensions, origin = [1, 2, 3], ...
                voxelVectors = diag([0.2, 0.2, 0.2]), ...
                periodic = [true, true, true], ...
                sampling = "point-inclusive", channels = channel);

            preview = ...
                kssolv.ui.scene.volume.VolumeLodBuilder. ...
                previewDataset(dataset, 4^3);

            testCase.verifyLessThanOrEqual(prod(preview.dimensions), 5^3);
            testCase.verifyEqual( ...
                preview.voxelVectors .* (preview.dimensions - 1).', ...
                dataset.voxelVectors .* (dataset.dimensions - 1).', ...
                AbsTol = 1e-12);
            testCase.verifyEqual(preview.origin, dataset.origin);
            testCase.verifyEqual(preview.getChannel("rho").values(1), ...
                values(1));
            testCase.verifyEqual(preview.getChannel("rho").values(end), ...
                values(end));
        end
    end
end

function writeText(filePath, value)
file = fopen(filePath, "w", "n", "UTF-8");
if file < 0, error("Unable to create test file."); end
cleanup = onCleanup(@() fclose(file));
fwrite(file, char(value), "char");
clear cleanup
end

function deleteIfPresent(path)
if isfile(path), delete(path); end
end

function value = sha256(path)
file = fopen(path, "r");
if file < 0, error("Unable to open fixture for hashing."); end
cleanup = onCleanup(@() fclose(file));
bytes = fread(file, Inf, "*uint8");
clear cleanup
engine = java.security.MessageDigest.getInstance("SHA-256");
engine.update(typecast(bytes, "int8"));
digest = typecast(engine.digest(), "uint8");
value = lower(join(compose("%02x", digest), ""));
end

function exception = captureException(callback)
try
    callback();
catch exception
    return
end
error("Expected callback to throw an exception.");
end
