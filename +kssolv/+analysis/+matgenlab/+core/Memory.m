classdef Memory < kssolv.analysis.matgenlab.core.FloatWithUnit
    %MEMORY Scalar memory quantity with byte/KB/MB/GB/TB conversion.

    methods
        function obj = Memory(val, unit)
            obj@kssolv.analysis.matgenlab.core.FloatWithUnit( ...
                val, unit, "memory");
        end
    end

    methods (Static)
        function obj = from_str(text)
            parsed = ...
                kssolv.analysis.matgenlab.core.FloatWithUnit.from_str(text);
            obj = kssolv.analysis.matgenlab.core.Memory( ...
                double(parsed), parsed.unit);
        end

        function obj = from_dict(data)
            obj = kssolv.analysis.matgenlab.core.Memory( ...
                data.val, data.unit);
        end
    end
end
