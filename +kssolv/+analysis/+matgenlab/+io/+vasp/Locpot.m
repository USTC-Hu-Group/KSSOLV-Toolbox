classdef Locpot < kssolv.analysis.matgenlab.io.vasp.VolumetricData
    %LOCPOT VASP local-potential file.
    properties
        poscar
    end
    methods
        function obj = Locpot(poscar, data, options)
            arguments
                poscar
                data (1,1) struct
                options.distance_matrix = struct()
                options.data_aug (1,1) struct = struct()
            end
            if isa(poscar, "kssolv.analysis.matgenlab.io.vasp.Poscar")
                structure = poscar.structure;
                name = poscar.comment;
            elseif isa(poscar, "kssolv.analysis.matgenlab.core.IStructure")
                structure = poscar;
                poscar = kssolv.analysis.matgenlab.io.vasp.Poscar(poscar);
                name = poscar.comment;
            else
                error("KSSOLV:Matgenlab:Locpot:Poscar", ...
                    "Unsupported POSCAR type.");
            end
            obj@kssolv.analysis.matgenlab.io.vasp.VolumetricData( ...
                structure, data, distance_matrix = options.distance_matrix, ...
                data_aug = options.data_aug);
            obj.poscar = poscar;
            obj.name = name;
        end
    end
    methods (Static)
        function obj = from_file(filename, varargin)
            [poscar, data, ~] = ...
                kssolv.analysis.matgenlab.io.vasp.VolumetricData. ...
                parse_file(filename);
            obj = kssolv.analysis.matgenlab.io.vasp.Locpot( ...
                poscar, data, varargin{:});
        end
    end
end
