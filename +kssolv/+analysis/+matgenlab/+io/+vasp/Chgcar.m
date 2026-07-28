classdef Chgcar < kssolv.analysis.matgenlab.io.vasp.VolumetricData
    %CHGCAR VASP charge-density file.
    properties
        poscar
    end
    properties (Dependent, SetAccess = private)
        net_magnetization
    end
    methods
        function obj = Chgcar(poscar, data, data_aug, varargin)
            if nargin < 3 || isempty(data_aug), data_aug = struct(); end
            if isa(poscar, "kssolv.analysis.matgenlab.io.vasp.Poscar")
                structure = poscar.structure;
                name = poscar.comment;
            elseif isa(poscar, "kssolv.analysis.matgenlab.core.IStructure")
                structure = poscar;
                poscar = kssolv.analysis.matgenlab.io.vasp.Poscar(poscar);
                name = "";
            else
                error("KSSOLV:Matgenlab:Chgcar:Poscar", ...
                    "Unsupported POSCAR type.");
            end
            obj@kssolv.analysis.matgenlab.io.vasp.VolumetricData( ...
                structure, data, data_aug = data_aug);
            obj.poscar = poscar;
            obj.name = name;
        end
        function value = get.net_magnetization(obj)
            if obj.is_spin_polarized && isfield(obj.data, "diff")
                value = sum(obj.data.diff, "all");
            else, value = [];
            end
        end
    end
    methods (Static)
        function obj = from_file(filename)
            [poscar, data, data_aug] = ...
                kssolv.analysis.matgenlab.io.vasp.VolumetricData. ...
                parse_file(filename);
            obj = kssolv.analysis.matgenlab.io.vasp.Chgcar( ...
                poscar, data, data_aug);
        end
    end
end
