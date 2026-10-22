classdef QABCollector < handle
    properties
        Controls cell = {}
    end
    methods
        function add(this, control)
            this.Controls{end+1} = control;
        end
    end
end
