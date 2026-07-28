classdef (Abstract) MSONable
    %MSONABLE Interface for Monty-compatible JSON serialization.

    methods (Abstract)
        value = asDict(this)
    end

    methods
        function text = toJSON(this, options)
            arguments
                this
                options.PrettyPrint (1,1) logical = false
            end
            text = kssolv.analysis.matgenlab.util.encode( ...
                this, PrettyPrint = options.PrettyPrint);
        end
    end
end
