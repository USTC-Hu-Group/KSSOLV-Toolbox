classdef Sqs
    %SQS Result returned by an ATAT mcsqs search.

    properties (SetAccess = private)
        bestsqs
        objective_function
        allsqs
        clusters
        directory (1, 1) string
    end

    methods
        function obj = Sqs(bestsqs, objective_function, allsqs, ...
                clusters, directory)
            if nargin == 0, return; end
            obj.bestsqs = bestsqs;
            obj.objective_function = objective_function;
            obj.allsqs = allsqs;
            obj.clusters = clusters;
            obj.directory = string(directory);
        end

        function value = as_dict(obj)
            value = struct("bestsqs", obj.bestsqs.as_dict(), ...
                "objective_function", obj.objective_function, ...
                "allsqs", {obj.allsqs}, "clusters", {obj.clusters}, ...
                "directory", obj.directory);
        end
    end
end
