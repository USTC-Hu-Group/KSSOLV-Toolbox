classdef Tolerance
    %TOLERANCE Central numerical comparison policy for Matgenlab.
    %
    % Algorithms may use tighter internal tolerances. These values define
    % default public comparison and cross-language parity tolerances.

    properties (Constant)
        Absolute double = 1e-8
        Relative double = 1e-7
        Coordinates double = 1e-8
        Lattice double = 1e-8
        Energy double = 1e-7
        Symmetry double = 1e-5
    end

    methods (Static)
        function tf = isClose(actual, expected, options)
            arguments
                actual {mustBeNumeric}
                expected {mustBeNumeric}
                options.Absolute (1,1) double {mustBeNonnegative} = ...
                    kssolv.analysis.matgenlab.internal.Tolerance.Absolute
                options.Relative (1,1) double {mustBeNonnegative} = ...
                    kssolv.analysis.matgenlab.internal.Tolerance.Relative
                options.EqualNaN (1,1) logical = true
            end

            if ~isequal(size(actual), size(expected))
                tf = false;
                return
            end

            actual = double(actual);
            expected = double(expected);
            finiteMask = isfinite(actual) & isfinite(expected);
            scale = max(abs(actual), abs(expected));
            closeMask = abs(actual - expected) <= ...
                options.Absolute + options.Relative .* scale;

            if options.EqualNaN
                closeMask(isnan(actual) & isnan(expected)) = true;
            end
            closeMask(isinf(actual) & isinf(expected) & ...
                sign(actual) == sign(expected)) = true;
            closeMask(~finiteMask & ~closeMask) = false;
            tf = all(closeMask, "all");
        end
    end
end
