classdef Elfcar < kssolv.analysis.matgenlab.io.vasp.VolumetricData
    %ELFCAR VASP electron-localization-function file.
    properties
        poscar
    end
    methods
        function obj = Elfcar(poscar, data)
            if isa(poscar, "kssolv.analysis.matgenlab.io.vasp.Poscar")
                structure = poscar.structure;
            elseif isa(poscar, "kssolv.analysis.matgenlab.core.IStructure")
                structure = poscar;
                poscar = kssolv.analysis.matgenlab.io.vasp.Poscar(poscar);
            else
                error("KSSOLV:Matgenlab:Elfcar:Poscar", ...
                    "Unsupported POSCAR type.");
            end
            obj@kssolv.analysis.matgenlab.io.vasp.VolumetricData( ...
                structure, data);
            obj.poscar = poscar;
            obj.name = "ELFCAR";
        end
        function output = get_alpha(obj)
            names = fieldnames(obj.data);
            data = struct();
            for index = 1:numel(names)
                data.(names{index}) = sqrt(1 ./ obj.data.(names{index}) - 1);
            end
            output = kssolv.analysis.matgenlab.io.vasp.VolumetricData( ...
                obj.structure, data);
        end
    end
    methods (Static)
        function obj = from_file(filename)
            [poscar, data, ~] = ...
                kssolv.analysis.matgenlab.io.vasp.VolumetricData. ...
                parse_file(filename);
            obj = kssolv.analysis.matgenlab.io.vasp.Elfcar(poscar, data);
        end
    end
end
