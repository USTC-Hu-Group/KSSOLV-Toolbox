classdef BoltztrapAnalyzer < kssolv.analysis.matgenlab.util.MSONable
    %BOLTZTRAPANALYZER Parse and analyze classic BoltzTraP output.

    properties
        gap = []
        mu_steps double = []
        cond = []
        seebeck = []
        kappa = []
        hall = []
        warning = []
        doping = []
        mu_doping = []
        seebeck_doping = []
        cond_doping = []
        kappa_doping = []
        hall_doping = []
        intrans = []
        carrier_conc = []
        dos = []
        vol = []
        dos_partial = []
        bz_bands = []
        bz_kpoints = []
        fermi_surface_data = []
    end

    methods
        function obj = BoltztrapAnalyzer(varargin)
            names = constructorNames();
            if ~isempty(varargin) && (ischar(varargin{1}) || ...
                    isstring(varargin{1}))
                for index = 1:2:numel(varargin)
                    obj.(char(varargin{index})) = varargin{index + 1};
                end
            else
                for index = 1:min(numel(varargin), numel(names))
                    obj.(names{index}) = varargin{index};
                end
            end
        end

        function result = get_symm_bands(obj, structure, efermi, ...
                kpointLine, labels)
            if nargin < 4 || isempty(kpointLine)
                path = kssolv.analysis.matgenlab.symmetry.HighSymmKpath( ...
                    structure);
                [kpointLine, pointLabels] = path.get_kpoints(20, false);
                labels = containers.Map("KeyType", "char", "ValueType", "any");
                for index = 1:numel(pointLabels)
                    if strlength(pointLabels(index)) > 0
                        labels(char(pointLabels(index))) = ...
                            kpointLine(index, :);
                    end
                end
            elseif iscell(kpointLine) && isobject(kpointLine{1})
                kpointLine = cell2mat(cellfun(@(point) ...
                    point.frac_coords, kpointLine(:), ...
                    "UniformOutput", false));
            end
            indices = zeros(1, size(kpointLine, 1));
            for index = 1:numel(indices)
                [distance, indices(index)] = min(vecnorm( ...
                    obj.bz_kpoints - kpointLine(index, :), 2, 2));
                if distance > 1e-2
                    error("KSSOLV:Matgenlab:Boltztrap:BandsKpoint", ...
                        "No interpolated point matches requested k-point %d.", ...
                        index);
                end
            end
            bands = (obj.bz_bands(indices, :) * ryToEv() + efermi).';
            result = kssolv.analysis.matgenlab.electronic_structure. ...
                BandStructureSymmLine(kpointLine, struct("up", bands), ...
                structure.lattice.reciprocal_lattice, efermi, labels, ...
                false, structure);
        end

        function result = get_seebeck(obj, varargin)
            options = outputOptions(varargin{:});
            result = formatOutput(obj.seebeck, obj.seebeck_doping, ...
                options.output, options.doping_levels, 1e6);
        end

        function result = get_conductivity(obj, varargin)
            options = outputOptions(varargin{:});
            result = formatOutput(obj.cond, obj.cond_doping, ...
                options.output, options.doping_levels, ...
                options.relaxation_time);
        end

        function result = get_power_factor(obj, varargin)
            options = outputOptions(varargin{:});
            [plain, doped] = combineTensors(obj.cond, obj.cond_doping, ...
                obj.seebeck, obj.seebeck_doping, ...
                @(c, s, ~) c * s * s);
            result = formatOutput(plain, doped, options.output, ...
                options.doping_levels, 1e6 * options.relaxation_time);
        end

        function result = get_thermal_conductivity(obj, varargin)
            options = outputOptions(varargin{:});
            operation = @(k, c, s, temperature) thermalTensor( ...
                k, c, s, temperature, options.k_el);
            [plain, doped] = combineThree(obj.kappa, obj.kappa_doping, ...
                obj.cond, obj.cond_doping, obj.seebeck, ...
                obj.seebeck_doping, operation);
            result = formatOutput(plain, doped, options.output, ...
                options.doping_levels, options.relaxation_time);
        end

        function result = get_zt(obj, varargin)
            options = outputOptions(varargin{:});
            powerPlain = rawPower(obj.cond, obj.seebeck);
            powerDoped = rawPowerDoped(obj.cond_doping, obj.seebeck_doping);
            thermalPlain = rawThermal(obj.kappa, obj.cond, obj.seebeck, true);
            thermalDoped = rawThermalDoped(obj.kappa_doping, ...
                obj.cond_doping, obj.seebeck_doping, true);
            resultPlain = tensorMapLike(powerPlain);
            temperatures = mapKeys(powerPlain);
            for temperature = temperatures
                power = mapGet(powerPlain, temperature);
                thermal = mapGet(thermalPlain, temperature);
                output = zeros(size(power));
                for index = 1:size(power, 3)
                    denominator = thermal(:, :, index) * ...
                        options.relaxation_time + eye(3) * options.k_l;
                    output(:, :, index) = power(:, :, index) * ...
                        options.relaxation_time * temperature / denominator;
                end
                resultPlain(temperature) = output;
            end
            resultDoped = struct();
            for carrier = ["p", "n"]
                key = char(carrier);
                resultDoped.(key) = tensorMapLike(powerDoped.(key));
                temperatures = mapKeys(powerDoped.(key));
                for temperature = temperatures
                    power = mapGet(powerDoped.(key), temperature);
                    thermal = mapGet(thermalDoped.(key), temperature);
                    output = zeros(size(power));
                    for index = 1:size(power, 3)
                        denominator = thermal(:, :, index) * ...
                            options.relaxation_time + eye(3) * options.k_l;
                        output(:, :, index) = power(:, :, index) * ...
                            options.relaxation_time * temperature / denominator;
                    end
                    resultDoped.(key)(temperature) = output;
                end
            end
            result = formatOutput(resultPlain, resultDoped, options.output, ...
                options.doping_levels, 1);
        end

        function result = get_average_eff_mass(obj, varargin)
            options = outputOptions(varargin{:});
            concentrations = obj.get_carrier_concentration();
            resultPlain = tensorMapLike(obj.cond);
            for temperature = mapKeys(obj.cond)
                conductivity = mapGet(obj.cond, temperature);
                carrier = mapGet(concentrations, temperature);
                output = zeros(size(conductivity));
                for index = 1:size(conductivity, 3)
                    if rcond(conductivity(:, :, index)) > 1e-14
                        output(:, :, index) = ...
                            (conductivity(:, :, index) \ eye(3)) * ...
                            carrier(index) * 1e6 * electronCharge()^2 / ...
                            electronMass();
                    end
                end
                resultPlain(temperature) = output;
            end
            resultDoped = struct();
            for carrierType = ["p", "n"]
                key = char(carrierType);
                resultDoped.(key) = tensorMapLike(obj.cond_doping.(key));
                for temperature = mapKeys(obj.cond_doping.(key))
                    conductivity = mapGet(obj.cond_doping.(key), temperature);
                    output = zeros(size(conductivity));
                    for index = 1:size(conductivity, 3)
                        if rcond(conductivity(:, :, index)) > 1e-14
                            output(:, :, index) = ...
                                (conductivity(:, :, index) \ eye(3)) * ...
                                obj.doping.(key)(index) * 1e6 * ...
                                electronCharge()^2 / electronMass();
                        end
                    end
                    resultDoped.(key)(temperature) = output;
                end
            end
            result = formatOutput(resultPlain, resultDoped, ...
                options.output, options.doping_levels, 1);
        end

        function result = get_seebeck_eff_mass(obj, varargin)
            options = specialOptions(varargin{:});
            if options.doping_levels
                result = struct();
                source = obj.get_seebeck("output", options.output, ...
                    "doping_levels", true);
                for carrier = ["n", "p"]
                    key = char(carrier);
                    values = mapGet(source.(key), options.temp);
                    result.(key) = massFromSeebeck(values, ...
                        obj.doping.(key), options.temp, options.Lambda, ...
                        options.output);
                end
            else
                source = obj.get_seebeck("output", options.output, ...
                    "doping_levels", false);
                values = mapGet(source, options.temp);
                concentrations = mapGet(obj.get_carrier_concentration(), ...
                    options.temp);
                result = massFromSeebeck(values, concentrations, ...
                    options.temp, options.Lambda, options.output);
            end
        end

        function result = get_complexity_factor(obj, varargin)
            options = specialOptions(varargin{:});
            seebeckMass = obj.get_seebeck_eff_mass(varargin{:});
            conductivityMass = obj.get_average_eff_mass( ...
                "output", options.output, ...
                "doping_levels", options.doping_levels);
            if options.doping_levels
                result = struct();
                for carrier = ["n", "p"]
                    key = char(carrier);
                    mass = mapGet(conductivityMass.(key), options.temp);
                    result.(key) = complexity(seebeckMass.(key), mass, ...
                        options.output);
                end
            else
                mass = mapGet(conductivityMass, options.temp);
                result = complexity(seebeckMass, mass, options.output);
            end
        end

        function result = get_extreme(obj, target, varargin)
            options = extremeOptions(varargin{:});
            switch lower(string(target))
                case "seebeck"
                    source = obj.get_seebeck();
                case "power factor"
                    source = obj.get_power_factor();
                case "conductivity"
                    source = obj.get_conductivity();
                case "kappa"
                    source = obj.get_thermal_conductivity();
                case "zt"
                    source = obj.get_zt();
                otherwise
                    error("KSSOLV:Matgenlab:Boltztrap:ExtremeTarget", ...
                        "Unrecognized target property '%s'.", target);
            end
            result = struct();
            bestGlobal = [];
            bestCarrier = "";
            for carrier = ["p", "n"]
                key = char(carrier);
                best = [];
                for temperature = mapKeys(source.(key))
                    if temperature < options.min_temp || ...
                            temperature > options.max_temp, continue; end
                    values = mapGet(source.(key), temperature);
                    for index = 1:size(values, 1)
                        dopingLevel = obj.doping.(key)(index);
                        if dopingLevel < options.min_doping || ...
                                dopingLevel > options.max_doping, continue; end
                        eigenvalues = abs(values(index, :));
                        if options.use_average
                            value = mean(eigenvalues);
                        else
                            value = max(eigenvalues);
                        end
                        if isempty(best) || better(value, best.value, ...
                                options.maximize)
                            best = struct("value", value, ...
                                "temperature", temperature, ...
                                "doping", dopingLevel, "isotropic", ...
                                isIsotropic(eigenvalues, ...
                                options.isotropy_tolerance));
                        end
                    end
                end
                result.(key) = best;
                if isempty(bestGlobal) || better(best.value, ...
                        bestGlobal.value, options.maximize)
                    bestGlobal = best;
                    bestCarrier = carrier;
                end
            end
            bestGlobal.carrier_type = bestCarrier;
            result.best = bestGlobal;
        end

        function result = get_complete_dos(obj, structure, secondSpin)
            if nargin < 3, secondSpin = []; end
            spinName = fieldnames(obj.dos.densities);
            densities = obj.dos.densities;
            if ~isempty(secondSpin)
                if ~isequal(obj.dos.energies, secondSpin.dos.energies)
                    error("KSSOLV:Matgenlab:Boltztrap:DOSMerge", ...
                        "DOS energies for both spins differ.");
                end
                secondName = fieldnames(secondSpin.dos.densities);
                densities.(secondName{1}) = ...
                    secondSpin.dos.densities.(secondName{1});
            end
            total = kssolv.analysis.matgenlab.electronic_structure.Dos( ...
                obj.dos.efermi, obj.dos.energies, densities);
            pdos = cell(1, structure.num_sites);
            siteNames = fieldnames(obj.dos_partial);
            for index = 1:numel(siteNames)
                siteIndex = str2double(erase(siteNames{index}, "x")) + 1;
                pdos{siteIndex} = struct();
                orbitals = fieldnames(obj.dos_partial.(siteNames{index}));
                for orbitalIndex = 1:numel(orbitals)
                    orbital = orbitals{orbitalIndex};
                    pdos{siteIndex}.(orbital).(spinName{1}) = ...
                        obj.dos_partial.(siteNames{index}).(orbital);
                    if ~isempty(secondSpin)
                        secondName = fieldnames(secondSpin.dos.densities);
                        pdos{siteIndex}.(orbital).(secondName{1}) = ...
                            secondSpin.dos_partial.(siteNames{index}).(orbital);
                    end
                end
            end
            result = kssolv.analysis.matgenlab.electronic_structure. ...
                CompleteDos(structure, total, pdos);
        end

        function bounds = get_mu_bounds(obj, temperature)
            if nargin < 2, temperature = 300; end
            bounds = [min(mapGet(obj.mu_doping.p, temperature)), ...
                max(mapGet(obj.mu_doping.n, temperature))];
        end

        function result = get_carrier_concentration(obj)
            result = tensorMapLike(obj.carrier_conc);
            for temperature = mapKeys(obj.carrier_conc)
                result(temperature) = 1e24 * ...
                    mapGet(obj.carrier_conc, temperature) / obj.vol;
            end
        end

        function result = get_hall_carrier_concentration(obj)
            result = tensorMapLike(obj.hall);
            for temperature = mapKeys(obj.hall)
                values = mapGet(obj.hall, temperature);
                count = size(values, 4);
                output = zeros(1, count);
                for index = 1:count
                    trace = (values(2,3,1,index) + ...
                        values(3,1,2,index) + values(1,2,3,index)) / 3;
                    if abs(trace) > eps
                        output(index) = 1e-6 / ...
                            (trace * electronCharge());
                    end
                end
                result(temperature) = output;
            end
        end

        function value = as_dict(obj)
            names = constructorNames();
            value = struct("x_module", ...
                "pymatgen.electronic_structure.boltztrap", ...
                "x_class", "BoltztrapAnalyzer");
            for index = 1:numel(names)
                name = names{index};
                item = obj.(name);
                if isa(item, "kssolv.analysis.matgenlab.util.MSONable")
                    item = item.as_dict();
                end
                value.(name) = item;
            end
        end

        function value = asDict(obj)
            value = obj.as_dict();
        end
    end

    methods (Static)
        function varargout = parse_outputtrans(directory)
            text = splitlines(string(fileread(fullfile( ...
                directory, "boltztrap.outputtrans"))));
            runType = []; warningText = []; efermi = []; gap = [];
            dopingLevels = [];
            for line = reshape(text, 1, [])
                tokens = split(strtrim(line));
                if contains(line, "WARNING")
                    warningText = line;
                elseif contains(line, "Calc type:")
                    runType = tokens(end);
                elseif startsWith(line, "VBM")
                    efermi = str2double(tokens(2)) * ryToEv();
                elseif startsWith(line, "Egap:")
                    gap = str2double(tokens(2)) * ryToEv();
                elseif startsWith(line, "Doping level number")
                    dopingLevels(end + 1) = str2double(tokens(7)); %#ok<AGROW>
                end
            end
            varargout = {runType, warningText, efermi, gap, dopingLevels};
        end

        function [dos, partial] = parse_transdos( ...
                directory, efermi, dosSpin, trimDos)
            if nargin < 3, dosSpin = 1; end
            if nargin < 4, trimDos = false; end
            rows = numericLines(fullfile(directory, "boltztrap.transdos"), ...
                true);
            energies = rows(:, 1).' * ryToEv();
            density = rows(:, 2).';
            low = 1; high = numel(density);
            if trimDos
                nonzero = find(density ~= 0);
                low = nonzero(1) + 1;
                high = nonzero(end) - 1;
                energies = energies(low:high);
                density = density(low:high);
            end
            spin = "up"; if dosSpin < 0, spin = "down"; end
            dos = kssolv.analysis.matgenlab.electronic_structure.Dos( ...
                efermi, energies, struct(char(spin), density));
            partial = struct();
            files = dir(fullfile(directory, "*transdos*"));
            for index = 1:numel(files)
                if files(index).name == "boltztrap.transdos", continue; end
                dotted = split(files(index).name, ".");
                if numel(dotted) < 3, continue; end
                tokens = split(dotted(2), "_");
                if numel(tokens) < 3, continue; end
                site = char(matlab.lang.makeValidName( ...
                    char("x" + tokens(2))));
                orbital = char(matlab.lang.makeValidName( ...
                    char(join(tokens(3:end), "_"))));
                values = numericLines(fullfile(directory, ...
                    files(index).name), false);
                values = values(low:min(high, size(values, 1)), 2).';
                if ~isfield(partial, site), partial.(site) = struct(); end
                partial.(site).(orbital) = values;
            end
        end

        function value = parse_intrans(directory)
            lines = splitlines(string(fileread(fullfile( ...
                directory, "boltztrap.intrans"))));
            value = struct();
            for line = reshape(lines, 1, [])
                if contains(line, "iskip")
                    tokens = split(strtrim(line));
                    value.scissor = str2double(tokens(4)) * ryToEv();
                elseif contains(line, "HISTO") || contains(line, "TETRA")
                    value.dos_type = strtrim(line);
                end
            end
        end

        function volume = parse_struct(directory)
            lines = splitlines(string(fileread(fullfile( ...
                directory, "boltztrap.struct"))));
            lattice = zeros(3);
            for index = 1:3
                lattice(index, :) = sscanf(lines(index + 1), "%f", 3);
            end
            volume = abs(det(lattice)) * bohrAngstrom()^3;
        end

        function varargout = parse_cond_and_hall(directory, dopingLevels)
            if nargin < 2, dopingLevels = []; end
            full = numericLines(fullfile(directory, ...
                "boltztrap.condtens"), false);
            hallRows = numericLines(fullfile(directory, ...
                "boltztrap.halltens"), false);
            temperatures = unique(full(:, 2)).';
            muSteps = unique(full(:, 1)).' * ryToEv();
            cond = newMap(); seebeck = newMap(); kappa = newMap();
            hall = newMap(); carrier = newMap();
            for temperature = temperatures
                rows = full(full(:, 2) == temperature, :);
                cond(temperature) = rowsToTensor(rows(:, 4:12));
                seebeck(temperature) = rowsToTensor(rows(:, 13:21));
                kappa(temperature) = rowsToTensor(rows(:, 22:30));
                carrier(temperature) = rows(:, 3).';
                rows = hallRows(hallRows(:, 2) == temperature, :);
                hall(temperature) = rowsToHall(rows(:, 4:30));
            end
            doping = struct("p", dopingLevels(dopingLevels > 0), ...
                "n", -dopingLevels(dopingLevels < 0));
            [muDoping, seebeckDoping, condDoping, kappaDoping, ...
                hallDoping] = emptyDopingMaps(temperatures);
            condFile = fullfile(directory, "boltztrap.condtens_fixdoping");
            hallFile = fullfile(directory, "boltztrap.halltens_fixdoping");
            if isfile(condFile)
                fixed = numericLines(condFile, false);
                fixedHall = numericLines(hallFile, false);
                for carrierType = ["p", "n"]
                    key = char(carrierType);
                    signMask = fixed(:, 2) > 0;
                    if carrierType == "n", signMask = ~signMask; end
                    for temperature = temperatures
                        rows = fixed(signMask & fixed(:, 1) == temperature, :);
                        muDoping.(key)(temperature) = rows(:, end).' * ryToEv();
                        condDoping.(key)(temperature) = ...
                            rowsToTensor(rows(:, 3:11));
                        seebeckDoping.(key)(temperature) = ...
                            rowsToTensor(rows(:, 12:20));
                        kappaDoping.(key)(temperature) = ...
                            rowsToTensor(rows(:, 21:29));
                        maskHall = fixedHall(:, 2) > 0;
                        if carrierType == "n", maskHall = ~maskHall; end
                        rows = fixedHall(maskHall & ...
                            fixedHall(:, 1) == temperature, :);
                        hallDoping.(key)(temperature) = ...
                            rowsToHall(rows(:, 3:29));
                    end
                end
            end
            varargout = {muSteps, cond, seebeck, kappa, hall, doping, ...
                muDoping, seebeckDoping, condDoping, kappaDoping, ...
                hallDoping, carrier};
        end

        function obj = from_files(directory, dosSpin)
            if nargin < 2, dosSpin = 1; end
            [runType, warningText, efermi, gap, dopingLevels] = ...
                kssolv.analysis.matgenlab.electronic_structure. ...
                BoltztrapAnalyzer.parse_outputtrans(directory);
            volume = kssolv.analysis.matgenlab.electronic_structure. ...
                BoltztrapAnalyzer.parse_struct(directory);
            intransValue = kssolv.analysis.matgenlab.electronic_structure. ...
                BoltztrapAnalyzer.parse_intrans(directory);
            switch string(runType)
                case "BOLTZ"
                    [dosValue, partial] = ...
                        kssolv.analysis.matgenlab.electronic_structure. ...
                        BoltztrapAnalyzer.parse_transdos( ...
                        directory, efermi, dosSpin, false);
                    [mu, condValue, seebeckValue, kappaValue, hallValue, ...
                        dopingValue, muDoping, seebeckDoping, condDoping, ...
                        kappaDoping, hallDoping, carrier] = ...
                        kssolv.analysis.matgenlab.electronic_structure. ...
                        BoltztrapAnalyzer.parse_cond_and_hall( ...
                        directory, dopingLevels);
                    obj = kssolv.analysis.matgenlab.electronic_structure. ...
                        BoltztrapAnalyzer(gap, mu, condValue, ...
                        seebeckValue, kappaValue, hallValue, dopingValue, ...
                        muDoping, seebeckDoping, condDoping, kappaDoping, ...
                        hallDoping, intransValue, dosValue, partial, ...
                        carrier, volume, warningText);
                case "DOS"
                    trim = isfield(intransValue, "dos_type") && ...
                        startsWith(intransValue.dos_type, "HISTO");
                    [dosValue, partial] = ...
                        kssolv.analysis.matgenlab.electronic_structure. ...
                        BoltztrapAnalyzer.parse_transdos( ...
                        directory, efermi, dosSpin, trim);
                    obj = kssolv.analysis.matgenlab.electronic_structure. ...
                        BoltztrapAnalyzer("gap", gap, "dos", dosValue, ...
                        "dos_partial", partial, "warning", warningText, ...
                        "vol", volume);
                case "BANDS"
                    data = readmatrix(fullfile(directory, ...
                        "boltztrap_band.dat"), "FileType", "text");
                    obj = kssolv.analysis.matgenlab.electronic_structure. ...
                        BoltztrapAnalyzer("bz_bands", data(:, 2:end-6), ...
                        "bz_kpoints", data(:, end-2:end), ...
                        "warning", warningText, "vol", volume);
                case "FERMI"
                    cube = fullfile(directory, "boltztrap_BZ.cube");
                    if ~isfile(cube), cube = fullfile(directory, "fort.30"); end
                    obj = kssolv.analysis.matgenlab.electronic_structure. ...
                        BoltztrapAnalyzer("fermi_surface_data", ...
                        kssolv.analysis.matgenlab.electronic_structure. ...
                        read_cube_file(cube));
                otherwise
                    error("KSSOLV:Matgenlab:Boltztrap:RunType", ...
                        "Run type '%s' is not recognized.", runType);
            end
        end

        function obj = from_dict(value)
            names = constructorNames();
            arguments = cell(1, 2 * numel(names));
            argumentCount = 0;
            for index = 1:numel(names)
                if isfield(value, names{index})
                    item = value.(names{index});
                    if names{index} == "dos" && isstruct(item)
                        item = kssolv.analysis.matgenlab. ...
                            electronic_structure.Dos.from_dict(item);
                    end
                    arguments(argumentCount + 1:argumentCount + 2) = ...
                        {names{index}, item};
                    argumentCount = argumentCount + 2;
                end
            end
            obj = kssolv.analysis.matgenlab.electronic_structure. ...
                BoltztrapAnalyzer(arguments{1:argumentCount});
        end

        function result = check_acc_bzt_bands(first, second, threshold)
            if nargin < 3, threshold = [0.03, 0.03]; end
            count = min(8, first.nb_bands);
            selected = max(1, first.nb_bands-count+1):first.nb_bands;
            result = kssolv.analysis.matgenlab.electronic_structure. ...
                compare_sym_bands(first, second, selected);
            fields = fieldnames(result);
            corrValues = zeros(1, numel(fields));
            distanceValues = corrValues;
            for index = 1:numel(fields)
                corrValues(index) = result.(fields{index}).Corr;
                distanceValues(index) = result.(fields{index}).Dist;
            end
            result.avg_corr = mean(corrValues);
            result.avg_distance = mean(distanceValues);
            result.acc_err = [result.avg_corr > threshold(1), ...
                result.avg_distance > threshold(2)];
            result.acc_thr = threshold;
            result.nb_list = selected;
        end
    end
end

function names = constructorNames()
names = {"gap","mu_steps","cond","seebeck","kappa","hall", ...
    "doping","mu_doping","seebeck_doping","cond_doping", ...
    "kappa_doping","hall_doping","intrans","dos","dos_partial", ...
    "carrier_conc","vol","warning","bz_bands","bz_kpoints", ...
    "fermi_surface_data"};
end

function options = outputOptions(varargin)
options = struct("output", "eigs", "doping_levels", true, ...
    "relaxation_time", 1e-14, "k_el", true, "k_l", 1);
for index = 1:2:numel(varargin)
    options.(char(varargin{index})) = varargin{index + 1};
end
end

function options = specialOptions(varargin)
options = struct("output", "average", "temp", 300, ...
    "doping_levels", false, "Lambda", 0.5);
for index = 1:2:numel(varargin)
    options.(char(varargin{index})) = varargin{index + 1};
end
end

function options = extremeOptions(varargin)
options = struct("maximize", true, "min_temp", -inf, "max_temp", inf, ...
    "min_doping", -inf, "max_doping", inf, ...
    "isotropy_tolerance", 0.05, "use_average", true);
for index = 1:2:numel(varargin)
    options.(char(varargin{index})) = varargin{index + 1};
end
end

function result = formatOutput(plain, doped, format, dopingLevels, multiplier)
if dopingLevels
    result = struct();
    for carrier = ["p", "n"]
        key = char(carrier);
        result.(key) = formatMap(doped.(key), format, multiplier);
    end
else
    result = formatMap(plain, format, multiplier);
end
end

function result = formatMap(source, format, multiplier)
result = tensorMapLike(source);
for temperature = mapKeys(source)
    tensors = mapGet(source, temperature);
    count = size(tensors, 3);
    switch string(format)
        case {"eig", "eigs"}
            output = zeros(count, 3);
            for index = 1:count
                output(index, :) = sort(eig(tensors(:, :, index))).' * ...
                    multiplier;
            end
        case "tensor"
            output = tensors * multiplier;
        case "average"
            output = zeros(1, count);
            for index = 1:count
                output(index) = trace(tensors(:, :, index)) / 3 * ...
                    multiplier;
            end
        otherwise
            error("KSSOLV:Matgenlab:Boltztrap:Output", ...
                "Unknown output format '%s'.", format);
    end
    result(temperature) = output;
end
end

function [plain, doped] = combineTensors(first, firstDoped, ...
        second, secondDoped, operation)
plain = binaryMap(first, second, operation);
doped = struct("p", binaryMap(firstDoped.p, secondDoped.p, operation), ...
    "n", binaryMap(firstDoped.n, secondDoped.n, operation));
end

function output = binaryMap(first, second, operation)
output = tensorMapLike(first);
for temperature = mapKeys(first)
    a = mapGet(first, temperature); b = mapGet(second, temperature);
    result = zeros(size(a));
    for index = 1:size(a, 3)
        result(:, :, index) = operation( ...
            a(:, :, index), b(:, :, index), temperature);
    end
    output(temperature) = result;
end
end

function [plain, doped] = combineThree(a, ad, b, bd, c, cd, operation)
plain = ternaryMap(a, b, c, operation);
doped = struct("p", ternaryMap(ad.p, bd.p, cd.p, operation), ...
    "n", ternaryMap(ad.n, bd.n, cd.n, operation));
end

function output = ternaryMap(a, b, c, operation)
output = tensorMapLike(a);
for temperature = mapKeys(a)
    av = mapGet(a, temperature); bv = mapGet(b, temperature);
    cv = mapGet(c, temperature); result = zeros(size(av));
    for index = 1:size(av, 3)
        result(:, :, index) = operation(av(:, :, index), ...
            bv(:, :, index), cv(:, :, index), temperature);
    end
    output(temperature) = result;
end
end

function value = thermalTensor(kappa, conductivity, seebeck, ...
        temperature, electronic)
value = kappa;
if electronic, value = value - conductivity * seebeck * seebeck * ...
        temperature; end
end

function output = rawPower(cond, seebeck)
output = binaryMap(cond, seebeck, @(c, s, ~) c * s * s);
end

function output = rawPowerDoped(cond, seebeck)
output = struct("p", rawPower(cond.p, seebeck.p), ...
    "n", rawPower(cond.n, seebeck.n));
end

function output = rawThermal(kappa, cond, seebeck, electronic)
output = ternaryMap(kappa, cond, seebeck, ...
    @(k, c, s, t) thermalTensor(k, c, s, t, electronic));
end

function output = rawThermalDoped(kappa, cond, seebeck, electronic)
output = struct("p", rawThermal(kappa.p, cond.p, seebeck.p, electronic), ...
    "n", rawThermal(kappa.n, cond.n, seebeck.n, electronic));
end

function output = massFromSeebeck(values, concentrations, ...
        temperature, lambda, format)
if string(format) == "average"
    output = zeros(size(concentrations));
    for index = 1:numel(output)
        output(index) = kssolv.analysis.matgenlab.electronic_structure. ...
            seebeck_eff_mass_from_seebeck_carr(abs(values(index)), ...
            concentrations(index), temperature, lambda);
    end
else
    count = size(values, 3);
    output = zeros(count, 3);
    for index = 1:count
        for axis = 1:3
            output(index, axis) = ...
                kssolv.analysis.matgenlab.electronic_structure. ...
                seebeck_eff_mass_from_seebeck_carr( ...
                abs(values(axis, axis, index)), concentrations(index), ...
                temperature, lambda);
        end
    end
end
end

function output = complexity(seebeckMass, conductivityMass, format)
if string(format) == "average"
    output = (seebeckMass ./ abs(conductivityMass)).^1.5;
else
    count = size(seebeckMass, 1);
    output = zeros(count, 3);
    for index = 1:count
        for axis = 1:3
            output(index, axis) = (seebeckMass(index, axis) / ...
                abs(conductivityMass(axis, axis, index)))^1.5;
        end
    end
end
end

function value = better(candidate, reference, maximize)
if maximize, value = candidate > reference; else, value = candidate < reference; end
end

function value = isIsotropic(input, tolerance)
sorted = sort(input);
value = all(sorted ~= 0) && ...
    abs((sorted(2)-sorted(1))/sorted(2)) <= tolerance && ...
    abs((sorted(3)-sorted(1))/sorted(3)) <= tolerance && ...
    abs((sorted(3)-sorted(2))/sorted(3)) <= tolerance;
end

function rows = numericLines(filename, stopAtSecondHeader)
lines = splitlines(string(fileread(filename)));
rows = cell(1, 0); headers = 0;
for line = reshape(lines, 1, [])
    trimmed = strtrim(line);
    if startsWith(trimmed, "#")
        headers = headers + 1;
        if stopAtSecondHeader && headers > 1, break; end
        continue
    end
    if strlength(trimmed) == 0, continue; end
    row = sscanf(trimmed, "%f").';
    if ~isempty(row), rows{end+1} = row; end %#ok<AGROW>
end
if isempty(rows), rows = zeros(0); else, rows = vertcat(rows{:}); end
end

function output = rowsToTensor(rows)
output = zeros(3, 3, size(rows, 1));
for index = 1:size(rows, 1)
    output(:, :, index) = reshape(rows(index, :), 3, 3).';
end
end

function output = rowsToHall(rows)
output = zeros(3, 3, 3, size(rows, 1));
for index = 1:size(rows, 1)
    for first = 1:3
        range = (first-1)*9 + (1:9);
        output(first, :, :, index) = ...
            reshape(rows(index, range), 3, 3).';
    end
end
end

function [mu, seebeck, cond, kappa, hall] = emptyDopingMaps(temperatures)
mu = struct("p", newMap(), "n", newMap());
seebeck = struct("p", newMap(), "n", newMap());
cond = struct("p", newMap(), "n", newMap());
kappa = struct("p", newMap(), "n", newMap());
hall = struct("p", newMap(), "n", newMap());
for carrier = ["p", "n"]
    key = char(carrier);
    for temperature = temperatures
        mu.(key)(temperature) = [];
        seebeck.(key)(temperature) = zeros(3,3,0);
        cond.(key)(temperature) = zeros(3,3,0);
        kappa.(key)(temperature) = zeros(3,3,0);
        hall.(key)(temperature) = zeros(3,3,3,0);
    end
end
end

function output = tensorMapLike(~)
output = newMap();
end

function output = newMap()
output = containers.Map("KeyType", "double", "ValueType", "any");
end

function keys = mapKeys(map)
if isa(map, "containers.Map")
    keys = sort(cell2mat(map.keys));
else
    names = string(fieldnames(map));
    keys = sort(str2double(erase(names, "x")));
    keys = keys(~isnan(keys));
end
end

function value = mapGet(map, key)
if isa(map, "containers.Map")
    value = map(double(key));
else
    value = map.(matlab.lang.makeValidName("x" + string(key)));
end
end

function value = ryToEv()
value = 13.605693122994;
end

function value = bohrAngstrom()
value = 0.529177210903;
end

function value = electronCharge()
value = 1.602176634e-19;
end

function value = electronMass()
value = 9.1093837015e-31;
end
