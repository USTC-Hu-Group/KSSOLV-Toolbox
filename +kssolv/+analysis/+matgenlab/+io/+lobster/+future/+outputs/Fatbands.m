classdef Fatbands < handle
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %FATBANDS Aggregate a directory of FATBAND files.
    properties
        directory (1,1) string = "."
        filenames cell = {}
        efermi double = []
        spins cell = {"up"}
        kpoints = []
        structure = []
        reciprocal_lattice = []
        fatbands cell = {}
        lobster_version (1,1) string = "5.1.1"
    end
    methods
        function obj = Fatbands(directory, structure, varargin)
            if nargin == 0, return; end
            obj.directory = string(directory);
            files = dir(fullfile(directory, "FATBAND_*.lobster"));
            names = sort(string({files.name}));
            obj.filenames = cellstr(fullfile(directory, names));
            if isempty(obj.filenames)
                error("KSSOLV:Matgenlab:Lobster:Fatbands", ...
                    "No FATBAND files found.");
            end
            if nargin >= 2, obj.structure = structure; end
            if ~isempty(varargin) && islogical(varargin{end}) && varargin{end}
                obj.process();
            end
        end
        function process(obj)
            obj.fatbands = cell(size(obj.filenames));
            for index = 1:numel(obj.filenames)
                reader = kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                    Fatband(obj.filenames{index});
                obj.fatbands{index} = reader.fatband;
                if reader.is_spin_polarized, obj.spins = {"up", "down"}; end
            end
        end
        function value = as_dict(obj)
            value = struct("x_module", "pymatgen.io.lobster.future.outputs.bands", ...
                "x_class", "Fatbands", "directory", obj.directory, ...
                "filenames", {obj.filenames}, "efermi", obj.efermi, ...
                "spins", {obj.spins}, "fatbands", {obj.fatbands});
        end
        function value = has_spin(obj), value = ~isempty(obj.spins); end
        function value = is_spin_polarized(obj), value = numel(obj.spins) > 1; end
    end
end
