classdef Spectrum < handle
    %SPECTRUM One- or multi-channel spectrum with pymatgen-compatible tools.

    properties (Dependent, SetAccess = private)
        XLABEL
        YLABEL
    end

    properties
        x double
        y double
    end

    properties (SetAccess = private)
        ydim
        args cell
        kwargs struct
    end

    methods
        function obj = Spectrum(x, y, varargin)
            arguments
                x {mustBeNumeric}
                y {mustBeNumeric}
            end
            arguments (Repeating)
                varargin
            end
            obj.x = double(x);
            obj.y = double(y);
            if isrow(obj.x)
                obj.x = obj.x(:);
            end
            if isrow(obj.y) && numel(obj.y) == numel(obj.x)
                obj.y = obj.y(:);
            end
            obj.ydim = size(obj.y);
            if size(obj.x, 1) ~= size(obj.y, 1)
                error("KSSOLV:Matgenlab:Spectrum:DimensionMismatch", ...
                    "x and y values have different first dimension!");
            end
            obj.args = varargin;
            obj.kwargs = struct();
        end

        function n = length(obj)
            n = size(obj.y, 1);
        end

        function value = get.XLABEL(obj), value = obj.xLabel(); end
        function value = get.YLABEL(obj), value = obj.yLabel(); end

        function result = plus(left, right)
            left.assertCompatible(right);
            result = left.construct(left.x, left.y + right.y);
        end

        function result = minus(left, right)
            left.assertCompatible(right);
            result = left.construct(left.x, left.y - right.y);
        end

        function result = times(left, right)
            if isa(left, "kssolv.analysis.matgenlab.core.Spectrum")
                result = left.construct(left.x, left.y .* right);
            else
                result = right.construct(right.x, left .* right.y);
            end
        end

        function result = mtimes(left, right)
            result = times(left, right);
        end

        function result = rdivide(left, right)
            if ~isa(left, "kssolv.analysis.matgenlab.core.Spectrum")
                error("KSSOLV:Matgenlab:Spectrum:InvalidDivision", ...
                    "A numeric value cannot be divided by a Spectrum.");
            end
            result = left.construct(left.x, left.y ./ right);
        end

        function result = mrdivide(left, right)
            result = rdivide(left, right);
        end

        function result = idivide(obj, divisor)
            result = obj.construct(obj.x, floor(obj.y ./ divisor));
        end

        function normalize(obj, mode, value)
            arguments
                obj
                mode (1,1) string = "max"
                value (1,1) double = 1.0
            end
            mode = lower(mode);
            if mode == "sum"
                factor = sum(obj.y, 1);
            elseif mode == "max"
                factor = max(obj.y, [], 1);
            else
                error("KSSOLV:Matgenlab:Spectrum:InvalidNormalization", ...
                    "Unsupported normalization mode='%s'!", mode);
            end
            obj.y = obj.y ./ (factor ./ value);
            obj.ydim = size(obj.y);
        end

        function smear(obj, sigma, func)
            arguments
                obj
                sigma (1,1) double = 0.0
                func = "gaussian"
            end
            points = linspace(min(obj.x) - mean(obj.x), ...
                max(obj.x) - mean(obj.x), length(obj.x)).';
            if isa(func, "function_handle")
                weights = func(points);
            else
                func = lower(string(func));
                if func == "gaussian"
                    weights = exp(-0.5 * (points ./ sigma).^2) ./ ...
                        (sqrt(2*pi) * sigma);
                elseif func == "lorentzian"
                    weights = ...
                        kssolv.analysis.matgenlab.core.lorentzian( ...
                        points, 0, sigma);
                else
                    error("KSSOLV:Matgenlab:Spectrum:InvalidSmearing", ...
                        "Invalid func='%s'", func);
                end
            end
            weights = weights(:) ./ sum(weights(:));
            total = sum(obj.y, 1);
            output = zeros(size(obj.y));
            for channel = 1:size(obj.y, 2)
                output(:, channel) = ...
                    kssolv.analysis.matgenlab.core.Spectrum. ...
                    convolveReflect(obj.y(:, channel), weights);
            end
            obj.y = output .* (total ./ sum(output, 1));
            obj.ydim = size(obj.y);
        end

        function value = get_interpolated_value(obj, x_value)
            arguments
                obj
                x_value (1,1) double
            end
            value = zeros(1, size(obj.y, 2));
            for channel = 1:size(obj.y, 2)
                value(channel) = ...
                    kssolv.analysis.matgenlab.util. ...
                    get_linear_interpolated_value( ...
                    obj.x, obj.y(:, channel), x_value);
            end
            if isvector(obj.y)
                value = value(1);
            end
        end

        function result = copy(obj)
            result = obj.construct(obj.x, obj.y);
        end

        function text = char(obj)
            xText = mat2str(obj.x.');
            if isvector(obj.y)
                yDisplay = obj.y.';
            else
                yDisplay = obj.y;
            end
            yText = mat2str(yDisplay);
            text = sprintf("%s\n%s: %s\n%s: %s", ...
                className(obj), obj.XLABEL, xText, obj.YLABEL, yText);
        end

        function text = string(obj)
            text = string(char(obj));
        end

        function disp(obj)
            fprintf("%s\n", char(obj));
        end

        function data = asDict(obj)
            data = struct( ...
                "x_module", "pymatgen.core.spectrum", ...
                "x_class", className(obj), ...
                "x", obj.x, ...
                "y", obj.y);
            if ~isempty(obj.args)
                data.args = obj.args;
            end
            if ~isempty(fieldnames(obj.kwargs))
                data.kwargs = obj.kwargs;
            end
        end

        function data = as_dict(obj)
            data = obj.asDict();
        end
    end

    methods (Static)
        function obj = from_dict(data)
            obj = kssolv.analysis.matgenlab.core.Spectrum(data.x, data.y);
        end
    end

    methods (Access = protected)
        function value = xLabel(~), value = "x"; end
        function value = yLabel(~), value = "y"; end

        function result = construct(obj, x, y)
            %CONSTRUCT Hook retained for subclasses needing constructor args.
            result = feval(class(obj), x, y, obj.args{:});
        end
    end

    methods (Access = private)
        function assertCompatible(obj, other)
            if ~isa(other, "kssolv.analysis.matgenlab.core.Spectrum") || ...
                    ~isequal(obj.x, other.x)
                error("KSSOLV:Matgenlab:Spectrum:IncompatibleXAxis", ...
                    "X axis values are not compatible!");
            end
        end
    end

    methods (Static, Access = private)
        function output = convolveReflect(input, weights)
            % Match scipy.ndimage.convolve1d(..., mode="reflect", origin=0).
            input = input(:);
            count = numel(input);
            width = numel(weights);
            center = floor(width / 2) + 1;
            output = zeros(count, 1);
            for row = 1:count
                value = 0;
                for offset = 1:width
                    source = row + center - offset;
                    source = ...
                        kssolv.analysis.matgenlab.core.Spectrum. ...
                        reflectIndex(source, count);
                    value = value + weights(offset) * input(source);
                end
                output(row) = value;
            end
        end

        function index = reflectIndex(index, count)
            if count == 1
                index = 1;
                return
            end
            period = 2 * count;
            index = mod(index - 1, period) + 1;
            if index > count
                index = period - index + 1;
            end
        end
    end
end

function name = className(obj)
parts = split(string(class(obj)), ".");
name = parts(end);
end
