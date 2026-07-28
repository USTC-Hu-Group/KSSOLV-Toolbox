classdef EOSBase
    %EOSBASE Base class for analytic equations of state.

    properties (SetAccess = immutable)
        volumes (1,:) double
        energies (1,:) double
    end

    properties (SetAccess = protected)
        params = []
        eos_params = []
    end

    properties (Dependent, SetAccess = private)
        e0
        b0
        b0_GPa
        b1
        v0
        results
    end

    methods
        function obj = EOSBase(volumes, energies)
            volumes = reshape(double(volumes), 1, []);
            energies = reshape(double(energies), 1, []);
            if numel(volumes) ~= numel(energies) || numel(volumes) < 4
                error("KSSOLV:Matgenlab:EOS:InvalidData", ...
                    "volumes and energies require equal length of at least four.");
            end
            obj.volumes = volumes;
            obj.energies = energies;
        end

        function obj = fit(obj)
            guess = obj.initialGuess();
            scale = [max(abs(guess(1)),1), max(abs(guess(2)),0.1), ...
                max(abs(guess(3)),1), max(abs(guess(4)),1)];
            initial = guess ./ scale;
            residual = @(scaled) obj.energies - ...
                obj.evaluate(obj.volumes, scaled .* scale);
            if exist("lsqnonlin", "file") == 2
                options = optimoptions("lsqnonlin", "Display", "off", ...
                    "FunctionTolerance", 1e-14, ...
                    "StepTolerance", 1e-14, ...
                    "OptimalityTolerance", 1e-14, ...
                    "MaxIterations", 5000, ...
                    "MaxFunctionEvaluations", 50000);
                [scaled, ~, ~, exitFlag] = ...
                    lsqnonlin(residual, initial, [], [], options);
            else
                objective = @(scaled) sum(residual(scaled).^2);
                options = optimset("Display", "off", ...
                    "TolX", 1e-12, "TolFun", 1e-24, ...
                    "MaxFunEvals", 50000, "MaxIter", 50000);
                [scaled, objectiveValue, exitFlag] = ...
                    fminsearch(objective, initial, options);
                if exitFlag == 0 && isfinite(objectiveValue)
                    exitFlag = 1;
                end
            end
            if exitFlag <= 0
                throw(kssolv.analysis.matgenlab.analysis.EOSError( ...
                    "Optimal parameters not found."));
            end
            obj.eos_params = scaled .* scale;
            obj.params = obj.eos_params;
        end

        function value = func(obj, volume)
            if isempty(obj.eos_params)
                error("KSSOLV:Matgenlab:EOS:NotFitted", ...
                    "EOS parameters have not been fitted.");
            end
            value = obj.evaluate(double(volume), obj.eos_params);
        end

        function value = get.e0(obj), value = obj.requireParam(1); end
        function value = get.b0(obj), value = obj.requireParam(2); end
        function value = get.b1(obj), value = obj.requireParam(3); end
        function value = get.v0(obj), value = obj.requireParam(4); end

        function value = get.b0_GPa(obj)
            value = kssolv.analysis.matgenlab.core.FloatWithUnit( ...
                obj.b0, "eV ang^-3").to("GPa");
        end

        function value = get.results(obj)
            value = struct("e0", obj.e0, "b0", obj.b0, ...
                "b1", obj.b1, "v0", obj.v0);
        end

        function axesHandle = plot(obj, width, height, axesHandle, dpi, varargin)
            if nargin < 2 || isempty(width), width = 8; end
            if nargin < 3 || isempty(height)
                height = width * (sqrt(5)-1)/2;
            end
            if nargin < 4 || isempty(axesHandle)
                figureHandle = figure("Visible", "off", ...
                    "Units", "inches", "Position", [0,0,width,height]);
                if nargin >= 5 && ~isempty(dpi)
                    setappdata(figureHandle,"RequestedDPI",dpi);
                end
                axesHandle = axes(figureHandle);
            end
            plot(axesHandle, obj.volumes, obj.energies, "o");
            hold(axesHandle, "on");
            range = linspace(min(obj.volumes)*0.99, ...
                max(obj.volumes)*1.01, 100);
            plot(axesHandle, range, obj.func(range), "--");
            xlabel(axesHandle, "Volume Angstrom^3");
            ylabel(axesHandle, "Energy (eV)");
            grid(axesHandle, "on");
        end

        function figureHandle = plot_ax(obj, axesHandle, fontsize, varargin)
            if nargin < 2 || isempty(axesHandle)
                figureHandle = figure("Visible", "off");
                axesHandle = axes(figureHandle);
            else
                figureHandle = ancestor(axesHandle, "figure");
            end
            if nargin < 3 || isempty(fontsize), fontsize = 12; end
            obj.plot([], [], axesHandle);
            axesHandle.FontSize = fontsize;
        end

        function varargout = subsref(obj, reference)
            if reference(1).type == "()"
                value = obj.func(reference(1).subs{1});
                if numel(reference) > 1
                    value = builtin("subsref", value, reference(2:end));
                end
                varargout{1} = value;
            else
                [varargout{1:nargout}] = builtin("subsref", obj, reference);
            end
        end
    end

    methods (Access = protected)
        function value = evaluate(~, ~, ~)
            value = []; %#ok<NASGU>
            error("KSSOLV:Matgenlab:EOS:AbstractModel", ...
                "EOSBase subclasses must implement evaluate.");
        end

        function guess = initialGuess(obj)
            coefficients = polyfit(obj.volumes, obj.energies, 2);
            a = coefficients(1); b = coefficients(2);
            equilibriumVolume = -b / (2*a);
            if ~(min(obj.volumes) < equilibriumVolume && ...
                    equilibriumVolume < max(obj.volumes))
                throw(kssolv.analysis.matgenlab.analysis.EOSError( ...
                    "The fitted parabola minimum is outside input volumes."));
            end
            equilibriumEnergy = polyval(coefficients,equilibriumVolume);
            bulkModulus = 2*a*equilibriumVolume;
            guess = [equilibriumEnergy,bulkModulus,4,equilibriumVolume];
        end

        function value = requireParam(obj, index)
            if isempty(obj.params)
                error("KSSOLV:Matgenlab:EOS:NotFitted", ...
                    "params have not been initialized.");
            end
            value = obj.params(index);
        end
    end
end
