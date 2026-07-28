classdef FreqUnits
    %FREQUNITS Conversion factor from THz and its display label.
    properties (SetAccess=immutable)
        factor (1,1) double
        label (1,1) string
    end
    methods
        function obj=FreqUnits(factor,label)
            obj.factor=double(factor);
            obj.label=string(label);
        end
    end
end
