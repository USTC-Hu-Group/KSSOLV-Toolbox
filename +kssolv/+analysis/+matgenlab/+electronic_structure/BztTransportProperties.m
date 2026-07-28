classdef BztTransportProperties < handle
    %BZTTRANSPORTPROPERTIES Semiclassical transport from interpolated bands.

    properties
        dosweight (1,1) double = 2
        volume (1,1) double = 0
        nelect (1,1) double = 0
        efermi (1,1) double = 0
        temp_r double = 100:100:1300
        doping double = []
        CRTA (1,1) double = 1e-14
        epsilon double = []
        dos double = []
        vvdos double = []
        cdos double = []
        mu_r double = []
        mu_r_eV double = []
        Conductivity_mu double = []
        Seebeck_mu double = []
        Kappa_mu double = []
        Carrier_conc_mu double = []
        Hall_carrier_conc_trace_mu double = []
        Power_Factor_mu double = []
        Effective_mass_mu double = []
        Conductivity_doping struct = struct()
        Seebeck_doping struct = struct()
        Kappa_doping struct = struct()
        Carriers_conc_doping struct = struct()
        Power_Factor_doping struct = struct()
        Effective_mass_doping struct = struct()
        mu_doping struct = struct()
        mu_doping_eV struct = struct()
        contain_props_doping (1,1) logical = false
    end

    methods
        function obj = BztTransportProperties(interpolator, varargin)
            options = parseOptions(varargin{:});
            obj.dosweight = interpolator.data.dosweight;
            obj.volume = interpolator.data.get_volume();
            obj.nelect = interpolator.data.nelect;
            obj.efermi = interpolator.data.fermi / hartreePerEv();
            if options.load_bztTranspProps
                obj.load(options.fname);
                return
            end
            obj.temp_r = reshape(double(options.temp_r), 1, []);
            obj.doping = options.doping;
            obj.CRTA = options.CRTA;
            obj.buildSpectralFunctions(interpolator, options.npts_mu);
            margin = options.margin;
            if isempty(margin)
                margin = 9 * boltzmannHartree() * max(obj.temp_r);
            end
            mask = obj.epsilon > min(obj.epsilon) + margin & ...
                obj.epsilon < max(obj.epsilon) - margin;
            obj.mu_r = obj.epsilon(mask);
            obj.mu_r_eV = obj.mu_r / hartreePerEv() - obj.efermi;
            obj.computeMuProperties();
            if ~isempty(obj.doping)
                obj.compute_properties_doping(obj.doping, obj.temp_r);
            end
            if options.save_bztTranspProps, obj.save(options.fname); end
        end

        function compute_properties_doping(obj, doping, temperatures)
            if nargin < 3 || isempty(temperatures), temperatures = obj.temp_r; end
            doping = reshape(double(doping), 1, []);
            fields = ["Conductivity_doping","Seebeck_doping", ...
                "Kappa_doping","Carriers_conc_doping", ...
                "Power_Factor_doping","Effective_mass_doping"];
            for index = 1:numel(fields), obj.(fields(index)) = struct(); end
            obj.mu_doping = struct();
            obj.mu_doping_eV = struct();
            for carrier = ["n", "p"]
                countT = numel(temperatures);
                countD = numel(doping);
                conductivity = zeros(countT, countD, 3, 3);
                seebeck = conductivity;
                kappa = conductivity;
                concentration = zeros(countT, countD);
                power = conductivity;
                mass = conductivity;
                chemical = zeros(countT, countD);
                targetSign = 1;
                if carrier == "p", targetSign = -1; end
                for ti = 1:countT
                    carrierGrid = obj.carriersAtMu(temperatures(ti), obj.mu_r);
                    for di = 1:countD
                        target = targetSign * doping(di);
                        [~, nearest] = min(abs(carrierGrid - target));
                        chemical(ti, di) = obj.mu_r(nearest);
                        conductivity(ti, di, :, :) = ...
                            obj.Conductivity_mu(ti, nearest, :, :);
                        seebeck(ti, di, :, :) = ...
                            obj.Seebeck_mu(ti, nearest, :, :);
                        kappa(ti, di, :, :) = ...
                            obj.Kappa_mu(ti, nearest, :, :);
                        concentration(ti, di) = carrierGrid(nearest);
                        power(ti, di, :, :) = ...
                            obj.Power_Factor_mu(ti, nearest, :, :);
                        mass(ti, di, :, :) = ...
                            obj.effectiveMass( ...
                            squeeze(conductivity(ti, di, :, :)), ...
                            abs(doping(di)));
                    end
                end
                key = char(carrier);
                obj.Conductivity_doping.(key) = conductivity;
                obj.Seebeck_doping.(key) = seebeck;
                obj.Kappa_doping.(key) = kappa;
                obj.Carriers_conc_doping.(key) = concentration;
                obj.Power_Factor_doping.(key) = power;
                obj.Effective_mass_doping.(key) = mass;
                obj.mu_doping.(key) = chemical;
                obj.mu_doping_eV.(key) = chemical / hartreePerEv() - ...
                    obj.efermi;
            end
            obj.doping = doping;
            obj.contain_props_doping = true;
        end

        function save(obj, filename)
            if nargin < 2, filename = "bztTranspProps.json.gz"; end
            names = serialNames();
            value = cell(1, numel(names));
            for index = 1:numel(names), value{index} = obj.(names{index}); end
            writeJson(filename, value);
        end

        function success = load(obj, filename)
            if nargin < 2, filename = "bztTranspProps.json.gz"; end
            value = readJson(filename);
            if ~iscell(value), value = num2cell(value); end
            names = serialNames();
            for index = 1:min(numel(value), numel(names))
                obj.(names{index}) = decodeValue(value{index});
            end
            obj.contain_props_doping = numel(value) > 15;
            success = true;
        end
    end

    methods (Access = private)
        function buildSpectralFunctions(obj, interpolator, points)
            minimum = min(interpolator.eband, [], "all");
            maximum = max(interpolator.eband, [], "all");
            edges = linspace(minimum, maximum, points + 1);
            obj.epsilon = (edges(1:end-1) + edges(2:end)) / 2;
            spacing = mean(diff(edges));
            samples = size(interpolator.eband, 2);
            obj.dos = histcounts(interpolator.eband, edges) * ...
                obj.dosweight / (samples * spacing);
            obj.vvdos = zeros(points, 3, 3);
            for band = 1:size(interpolator.eband, 1)
                bins = discretize(interpolator.eband(band, :), edges);
                for first = 1:3
                    for second = 1:3
                        weights = squeeze(interpolator.vvband( ...
                            band, first, second, :));
                        valid = ~isnan(bins);
                        obj.vvdos(:, first, second) = ...
                            obj.vvdos(:, first, second) + accumarray( ...
                            bins(valid).', weights(valid), [points, 1]);
                    end
                end
            end
            obj.vvdos = obj.vvdos * obj.dosweight / ...
                (samples * spacing);
            obj.cdos = [];
        end

        function computeMuProperties(obj)
            nt = numel(obj.temp_r);
            nm = numel(obj.mu_r);
            obj.Conductivity_mu = zeros(nt, nm, 3, 3);
            obj.Seebeck_mu = zeros(nt, nm, 3, 3);
            obj.Kappa_mu = zeros(nt, nm, 3, 3);
            obj.Carrier_conc_mu = zeros(nt, nm);
            obj.Hall_carrier_conc_trace_mu = zeros(nt, nm);
            obj.Power_Factor_mu = zeros(nt, nm, 3, 3);
            obj.Effective_mass_mu = zeros(nt, nm, 3, 3);
            volumeM3 = obj.volume * bohrMeters()^3;
            energyJ = obj.epsilon * hartreeJoules();
            for ti = 1:nt
                temperature = obj.temp_r(ti);
                for mi = 1:nm
                    mu = obj.mu_r(mi);
                    derivative = fermiDerivative(obj.epsilon, mu, temperature);
                    deltaJ = (obj.epsilon - mu) * hartreeJoules();
                    l0 = squeeze(trapz(energyJ, obj.vvdos .* ...
                        reshape(derivative / hartreeJoules(), [], 1, 1), 1));
                    l1 = squeeze(trapz(energyJ, obj.vvdos .* ...
                        reshape(derivative / hartreeJoules() .* deltaJ, ...
                        [], 1, 1), 1));
                    l2 = squeeze(trapz(energyJ, obj.vvdos .* ...
                        reshape(derivative / hartreeJoules() .* deltaJ.^2, ...
                        [], 1, 1), 1));
                    conductivity = electronCharge()^2 * obj.CRTA / ...
                        volumeM3 * l0;
                    obj.Conductivity_mu(ti, mi, :, :) = conductivity;
                    if rcond(l0) > 1e-14
                        seebeck = -(l0 \ l1) / ...
                            (electronCharge() * temperature) * 1e6;
                        thermal = obj.CRTA / (volumeM3 * temperature) * ...
                            (l2 - l1 * (l0 \ l1));
                    else
                        seebeck = zeros(3);
                        thermal = zeros(3);
                    end
                    obj.Seebeck_mu(ti, mi, :, :) = seebeck;
                    obj.Kappa_mu(ti, mi, :, :) = thermal;
                    carrier = obj.carriersAtMu(temperature, mu);
                    obj.Carrier_conc_mu(ti, mi) = carrier;
                    obj.Hall_carrier_conc_trace_mu(ti, mi) = carrier;
                    obj.Power_Factor_mu(ti, mi, :, :) = ...
                        (seebeck * seebeck) * conductivity * 1e-9;
                    obj.Effective_mass_mu(ti, mi, :, :) = ...
                        obj.effectiveMass(conductivity, abs(carrier));
                end
            end
        end

        function result = carriersAtMu(obj, temperature, chemicalPotential)
            occupancy = fermiFunction(obj.epsilon, ...
                chemicalPotential(:), temperature);
            electrons = trapz(obj.epsilon, obj.dos .* occupancy, 2);
            volumeCm3 = obj.volume * (bohrMeters() * 100)^3;
            result = reshape((electrons - obj.nelect) / volumeCm3, ...
                size(chemicalPotential));
        end

        function mass = effectiveMass(obj, conductivity, concentration)
            if rcond(conductivity) <= 1e-14
                mass = zeros(3);
            else
                mass = (conductivity \ eye(3)) * concentration * 1e6 * ...
                    electronCharge()^2 * obj.CRTA / electronMass();
            end
        end
    end
end

function options = parseOptions(varargin)
options = struct("temp_r", 100:100:1300, "doping", [], ...
    "npts_mu", 4000, "CRTA", 1e-14, "margin", [], ...
    "save_bztTranspProps", false, "load_bztTranspProps", false, ...
    "fname", "bztTranspProps.json.gz");
for index = 1:2:numel(varargin)
    options.(char(varargin{index})) = varargin{index + 1};
end
end

function names = serialNames()
names = {"temp_r","CRTA","epsilon","dos","vvdos","cdos","mu_r", ...
    "mu_r_eV","Conductivity_mu","Seebeck_mu","Kappa_mu", ...
    "Carrier_conc_mu","Hall_carrier_conc_trace_mu","Power_Factor_mu", ...
    "Effective_mass_mu","Conductivity_doping","Seebeck_doping", ...
    "Kappa_doping","Power_Factor_doping","Effective_mass_doping", ...
    "Carriers_conc_doping","doping","mu_doping","mu_doping_eV"};
end

function result = fermiFunction(energy, mu, temperature)
x = (reshape(energy, 1, []) - mu) / ...
    (boltzmannHartree() * temperature);
x = max(min(x, 700), -700);
result = 1 ./ (exp(x) + 1);
end

function result = fermiDerivative(energy, mu, temperature)
f = fermiFunction(energy, mu, temperature);
result = f .* (1 - f) / (boltzmannHartree() * temperature);
end

function value = hartreePerEv()
value = 1 / 27.211386245988;
end

function value = boltzmannHartree()
value = 3.166811563e-6;
end

function value = bohrMeters()
value = 5.29177210903e-11;
end

function value = hartreeJoules()
value = 4.3597447222071e-18;
end

function value = electronCharge()
value = 1.602176634e-19;
end

function value = electronMass()
value = 9.1093837015e-31;
end

function value = readJson(filename)
if endsWith(string(filename), ".gz")
    folder = tempname; mkdir(folder);
    cleanup = onCleanup(@() rmdir(folder, "s"));
    files = gunzip(filename, folder);
    value = jsondecode(fileread(files{1}));
    clear cleanup
else
    value = jsondecode(fileread(filename));
end
end

function writeJson(filename, value)
text = jsonencode(value);
if endsWith(string(filename), ".gz")
    folder = tempname; mkdir(folder);
    cleanup = onCleanup(@() rmdir(folder, "s"));
    plain = fullfile(folder, "transport.json");
    writeText(plain, text);
    files = gzip(plain, folder);
    movefile(files{1}, filename, "f");
    clear cleanup
else
    writeText(filename, text);
end
end

function writeText(filename, text)
file = fopen(filename, "w");
cleanup = onCleanup(@() fclose(file));
fwrite(file, text, "char");
end

function value = decodeValue(value)
if isstruct(value) && isfield(value, "data")
    value = value.data;
end
if iscell(value)
    converted = cellfun(@decodeValue, value, "UniformOutput", false);
    try
        value = cat(ndims(converted{1}) + 1, converted{:});
        value = permute(value, [ndims(value), 1:ndims(value)-1]);
    catch
        value = converted;
    end
elseif isstruct(value)
    names = fieldnames(value);
    for index = 1:numel(names)
        value.(names{index}) = decodeValue(value.(names{index}));
    end
end
end
