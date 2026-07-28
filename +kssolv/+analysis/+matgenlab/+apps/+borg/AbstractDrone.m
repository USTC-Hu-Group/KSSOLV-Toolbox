classdef (Abstract) AbstractDrone < kssolv.analysis.matgenlab.util.MSONable
    %ABSTRACTDRONE Interface for filesystem data assimilation.
    %
    % Native MATLAB counterpart of pymatgen.apps.borg.hive.AbstractDrone.
    % Concrete drones return matgenlab MSONable objects and identify valid
    % paths from an os.walk-like {parent, subdirectories, files} tuple.

    methods (Abstract)
        value = assimilate(obj, path)
        paths = get_valid_paths(obj, path)
    end

    methods
        function value = asDict(obj)
            value = obj.as_dict();
        end
    end
end
