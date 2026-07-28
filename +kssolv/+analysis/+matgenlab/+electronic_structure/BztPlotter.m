classdef BztPlotter < handle
    %BZTPLOTTER MATLAB plotting adapter for BoltzTraP2 results.

    properties
        bzt_transP = []
        bzt_interp = []
    end

    methods
        function obj = BztPlotter(transport, interpolator)
            if nargin >= 1, obj.bzt_transP = transport; end
            if nargin >= 2, obj.bzt_interp = interpolator; end
        end

        function output = plot_props(obj, property, xName, zName, varargin)
            if nargin < 4 || isempty(zName), zName = "temp"; end
            options = parseOptions(varargin{:});
            [field, label] = propertyName(property);
            figureHandle = figure("Visible", "off");
            axesHandle = axes(figureHandle);
            hold(axesHandle, "on");
            if xName == "mu" && zName == "temp"
                values = obj.bzt_transP.(field + "_mu");
                temperatures = selected(obj.bzt_transP.temp_r, options.temps);
                for temperature = temperatures
                    ti = find(obj.bzt_transP.temp_r == temperature, 1);
                    plot(axesHandle, obj.bzt_transP.mu_r_eV, ...
                        reduceTensor(squeeze(values(ti, :, :, :)), ...
                        options.output), "DisplayName", ...
                        sprintf("%g K", temperature));
                end
                xlabel(axesHandle, "\mu (eV)");
                xlim(axesHandle, options.xlim);
            elseif xName == "doping" && zName == "temp"
                values = obj.bzt_transP.(field + "_doping").( ...
                    char(options.dop_type));
                temperatures = selected(obj.bzt_transP.temp_r, options.temps);
                for temperature = temperatures
                    ti = find(obj.bzt_transP.temp_r == temperature, 1);
                    semilogx(axesHandle, obj.bzt_transP.doping, ...
                        reduceTensor(squeeze(values(ti, :, :, :)), ...
                        options.output), "DisplayName", ...
                        sprintf("%g K", temperature));
                end
                xlabel(axesHandle, "Carrier concentration (cm^{-3})");
            elseif xName == "temp" && zName == "doping"
                values = obj.bzt_transP.(field + "_doping").( ...
                    char(options.dop_type));
                dopings = selected(obj.bzt_transP.doping, options.doping);
                for doping = dopings
                    di = find(obj.bzt_transP.doping == doping, 1);
                    plot(axesHandle, obj.bzt_transP.temp_r, ...
                        reduceTensor(squeeze(values(:, di, :, :)), ...
                        options.output), "DisplayName", ...
                        sprintf("%g cm^{-3}", doping));
                end
                xlabel(axesHandle, "Temperature (K)");
            else
                error("KSSOLV:Matgenlab:BztPlotter:Axes", ...
                    "Unsupported x/z property combination.");
            end
            ylabel(axesHandle, label);
            grid(axesHandle, "on");
            legend(axesHandle, "show", "Location", "best");
            if isempty(options.ax), output = figureHandle;
            else
                copyobj(allchild(axesHandle), options.ax);
                close(figureHandle);
                output = options.ax;
            end
        end

        function output = plot_bands(obj, varargin)
            if isempty(obj.bzt_interp)
                error("KSSOLV:Matgenlab:BztPlotter:MissingInterpolator", ...
                    "BztInterpolator is not present.");
            end
            bandStructure = obj.bzt_interp.get_band_structure(varargin{:});
            output = kssolv.analysis.matgenlab.electronic_structure. ...
                BSPlotter(bandStructure);
        end

        function output = plot_dos(obj, varargin)
            if isempty(obj.bzt_interp)
                error("KSSOLV:Matgenlab:BztPlotter:MissingInterpolator", ...
                    "BztInterpolator is not present.");
            end
            options = struct("T", [], "npoints", 10000, "label", "Total");
            for index = 1:2:numel(varargin)
                options.(char(varargin{index})) = varargin{index + 1};
            end
            dos = obj.bzt_interp.get_dos("T", options.T, ...
                "npts_mu", options.npoints);
            output = kssolv.analysis.matgenlab.electronic_structure.DosPlotter();
            output.add_dos(options.label, dos);
        end
    end
end

function options = parseOptions(varargin)
options = struct("output", "avg_eigs", "dop_type", "n", ...
    "doping", [], "temps", [], "xlim", [-2, 2], "ax", []);
for index = 1:2:numel(varargin)
    options.(char(varargin{index})) = varargin{index + 1};
end
end

function [field, label] = propertyName(input)
names = ["Conductivity","Seebeck","Kappa","Effective_mass", ...
    "Power_Factor","Carrier_conc","Hall_carrier_conc_trace"];
matches = startsWith(lower(names), lower(string(input)));
if sum(matches) ~= 1
    error("KSSOLV:Matgenlab:BztPlotter:Property", ...
        "prop_y is not valid.");
end
field = names(matches);
label = replace(field, "_", " ");
end

function output = selected(allValues, requested)
if isempty(requested), output = allValues; else, output = requested; end
end

function output = reduceTensor(values, mode)
if ismatrix(values)
    output = abs(values);
    return
end
count = size(values, 1);
eigenvalues = zeros(count, 3);
for index = 1:count
    eigenvalues(index, :) = sort(eig(squeeze(values(index, :, :))));
end
if string(mode) == "eigs", output = eigenvalues;
else, output = mean(eigenvalues, 2); end
end
