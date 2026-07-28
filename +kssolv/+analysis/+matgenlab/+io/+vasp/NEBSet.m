classdef NEBSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %NEBSET Nudged elastic band inputs for a sequence of structures.
    properties
        structures = {}
        unset_encut (1,1) logical = false
        parent_set (1,1) string = "MPRelaxSet"
    end
    properties (Dependent, SetAccess = private)
        poscars
    end
    methods
        function obj = NEBSet(structures, varargin)
            if nargin < 1 || isempty(structures)
                error("KSSOLV:Matgenlab:NEBSet:Structures", ...
                    "At least two structures are required.");
            end
            if ~iscell(structures), structures = num2cell(structures); end
            if numel(structures) < 2
                error("KSSOLV:Matgenlab:NEBSet:Structures", ...
                    "At least two structures are required.");
            end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structures{1}, "MPRelaxSet", varargin{:});
            obj.set_name = "NEBSet";
            obj.structures = structures;
            obj.extra_incar_updates = struct("IMAGES",numel(structures)-2, ...
                "IBRION",3,"POTIM",0,"LCLIMB",false,"SPRING",-5);
            if obj.unset_encut
                obj.user_incar_settings.ENCUT = [];
            end
        end

        function value = get.poscars(obj)
            value = cell(1, numel(obj.structures));
            for index = 1:numel(value)
                value{index} = kssolv.analysis.matgenlab.io.vasp.Poscar( ...
                    obj.structures{index}, sort_structure = false);
            end
        end

        function write_input(obj, output_dir, varargin)
            options = obj.parse_write_options(varargin);
            if ~isfolder(output_dir)
                if options.make_dir_if_not_present, mkdir(output_dir);
                else
                    error("KSSOLV:Matgenlab:NEBSet:Directory", ...
                        "Output directory does not exist.");
                end
            end
            obj.incar.write_file(fullfile(output_dir, "INCAR"));
            points = obj.kpoints;
            if ~isempty(points)
                points.write_file(fullfile(output_dir, "KPOINTS"));
            end
            if options.potcar_spec
                text = strjoin(obj.potcar_symbols, newline) + newline;
                kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                    writeText(fullfile(output_dir, "POTCAR.spec"), text);
            else
                obj.potcar.write_file(fullfile(output_dir, "POTCAR"));
            end
            images = obj.poscars;
            width = max(2, strlength(string(numel(images) - 1)));
            for index = 1:numel(images)
                folder = fullfile(output_dir, ...
                    sprintf("%0*d", width, index - 1));
                if ~isfolder(folder), mkdir(folder); end
                images{index}.write_file(fullfile(folder, "POSCAR"));
            end
        end
    end
end
