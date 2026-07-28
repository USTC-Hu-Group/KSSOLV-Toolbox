classdef BasicAbinitInput < kssolv.analysis.matgenlab.io.abinit.AbstractInput
    properties (SetAccess = private)
        structure
        pseudos cell = {}
        comment = []
    end
    properties (Dependent)
        ispaw
        isnc
    end
    methods
        function obj = BasicAbinitInput(structure, pseudos, varargin)
            if nargin == 0, return; end
            options = struct("pseudo_dir", "", "comment", [], "abi_args", struct(), "abi_kwargs", struct());
            for i = 1:2:numel(varargin), options.(char(string(varargin{i}))) = varargin{i + 1}; end
            obj.set_structure(structure);
            if strlength(string(options.pseudo_dir)) > 0
                if ischar(pseudos) || isstring(pseudos), pseudos = cellstr(string(pseudos)); end
                pseudos = cellfun(@(p) fullfile(options.pseudo_dir, p), pseudos, "UniformOutput", false);
            end
            table = kssolv.analysis.matgenlab.io.abinit.PseudoTable.as_table(pseudos);
            obj.pseudos = table.get_pseudos_for_structure(obj.structure);
            if ~isempty(options.comment), obj.set_comment(options.comment); end
            if ~isempty(options.abi_args), obj.set_vars(options.abi_args); end
            if ~isempty(options.abi_kwargs), obj.set_vars(options.abi_kwargs); end
        end
        function value = get.ispaw(obj), value = all(cellfun(@(p) p.ispaw, obj.pseudos)); end
        function value = get.isnc(obj), value = all(cellfun(@(p) p.isnc, obj.pseudos)); end
        function value = as_dict(obj)
            value = struct("x_module", "pymatgen.io.abinit.inputs", "x_class", "BasicAbinitInput", ...
                "structure", obj.structure.as_dict(), ...
                "pseudos", {cellfun(@(p) p.as_dict(), obj.pseudos, "UniformOutput", false)}, ...
                "comment", obj.comment, "abi_args", obj.vars_);
        end
        function value = asDict(obj), value = obj.as_dict(); end
        function value = add_abiobjects(obj, varargin)
            value = struct();
            for i = 1:numel(varargin)
                if ~ismethod(varargin{i}, "to_abivars")
                    error("KSSOLV:Matgenlab:Abinit:AbiObject", ...
                        "type %s does not have `to_abivars` method", class(varargin{i}));
                end
                added = obj.set_vars(varargin{i}.to_abivars()); value = mergeStruct(value, added);
            end
        end
        function value = to_str(obj, varargin)
            options = struct("post", "", "with_structure", true, "with_pseudos", true, "exclude", strings(0,1));
            for i = 1:2:numel(varargin), options.(char(string(varargin{i}))) = varargin{i + 1}; end
            lines = strings(0, 1);
            if ~isempty(obj.comment), lines(end + 1) = "# " + replace(string(obj.comment), newline, newline + "# "); end
            names = sort(string(fieldnames(obj.vars_)));
            for name = reshape(names, 1, [])
                if ismember(name, string(options.exclude)) || isempty(obj.vars_.(char(name))), continue; end
                lines(end + 1) = string(kssolv.analysis.matgenlab.io.abinit.InputVariable(name + string(options.post), obj.vars_.(char(name)))); %#ok<AGROW>
            end
            if options.with_structure
                geo = kssolv.analysis.matgenlab.io.abinit.structure_to_abivars(obj.structure);
                names = fieldnames(geo);
                for i = 1:numel(names), lines(end + 1) = string(kssolv.analysis.matgenlab.io.abinit.InputVariable(string(names{i}) + string(options.post), geo.(names{i}))); end %#ok<AGROW>
            end
            value = char(join(lines, newline));
            if options.with_pseudos
                info = struct("pseudos", {cellfun(@(p) p.as_dict(), obj.pseudos, "UniformOutput", false)});
                value = char(string(value) + newline + "#<JSON>" + newline + string(jsonencode(info, PrettyPrint=true)) + newline + "#</JSON>");
            end
        end
        function set_comment(obj, value), obj.comment = value; end
        function value = set_structure(obj, value)
            value = kssolv.analysis.matgenlab.io.abinit.as_structure(value);
            if det(value.lattice.matrix) <= 0
                error("KSSOLV:Matgenlab:Abinit:Input", "The triple product of the lattice vectors is negative.");
            end
            obj.structure = value;
        end
        function value = set_kmesh(obj, ngkpt, shiftk, kptopt)
            if nargin < 4, kptopt = 1; end
            shiftk = reshape(shiftk, [], 3);
            value = obj.set_vars(struct("ngkpt", reshape(ngkpt,1,3), "kptopt", kptopt, "nshiftk", size(shiftk,1), "shiftk", shiftk));
        end
        function value = set_gamma_sampling(obj), value = obj.set_kmesh([1 1 1], [0 0 0]); end
        function value = set_kpath(obj, ndivsm, kptbounds, iscf)
            if nargin < 4, iscf = -2; end
            if nargin < 3 || isempty(kptbounds), kptbounds = [0 0 0; .5 0 .5; .5 .5 .5; 0 0 0]; end
            kptbounds = reshape(kptbounds, [], 3);
            value = obj.set_vars(struct("kptbounds", kptbounds, "kptopt", -(size(kptbounds,1)-1), "ndivsm", ndivsm, "iscf", iscf));
        end
        function value = set_spin_mode(obj, mode)
            value = obj.pop_vars(["nsppol","nspden","nspinor"]);
            obj.add_abiobjects(kssolv.analysis.matgenlab.io.abinit.SpinMode.as_spinmode(mode));
        end
        function value = new_with_vars(obj, varargin), value = obj.deepcopy(); value.set_vars(varargin{:}); end
        function value = pop_tolerances(obj), value = obj.remove_vars(["toldfe","tolvrs","tolwfr","tolrff","toldff","tolimg","tolmxf","tolrde"], false); end
        function value = pop_irdvars(obj), value = obj.remove_vars(["irdbseig","irdbsreso","irdhaydock","irdddk","irdden","ird1den","irdqps","irdkss","irdscr","irdsuscep","irdvdw","irdwfk","irdwfkfine","irdwfq","ird1wf"], false); end
    end
    methods (Access = protected)
        function setOne(obj, key, value)
            name = char(string(key));
            if ismember(string(name), ["acell","rprim","rprimd","angdeg","xred","xcart","xangst","znucl","typat","ntypat","natom"])
                error("KSSOLV:Matgenlab:Abinit:Input", "Structure variables must be changed through set_structure.");
            end
            tolerances = ["toldfe","tolvrs","tolwfr","tolrff","toldff"];
            if ismember(string(name), tolerances), obj.remove_vars(setdiff(tolerances, string(name)), false); end
            setOne@kssolv.analysis.matgenlab.io.abinit.AbstractInput(obj, name, value);
        end
        function value = copyImpl(obj)
            value = kssolv.analysis.matgenlab.io.abinit.BasicAbinitInput(obj.structure, obj.pseudos, "comment", obj.comment);
            value.set_vars(obj.vars_);
        end
    end
    methods (Static)
        function obj = from_dict(value)
            ps = cellfun(@(p) kssolv.analysis.matgenlab.io.abinit.Pseudo.from_dict(p), value.pseudos, "UniformOutput", false);
            obj = kssolv.analysis.matgenlab.io.abinit.BasicAbinitInput(value.structure, ps, "comment", value.comment, "abi_args", value.abi_args);
        end
        function obj = fromDict(value), obj = kssolv.analysis.matgenlab.io.abinit.BasicAbinitInput.from_dict(value); end
    end
end
function out = mergeStruct(a,b), out=a; n=fieldnames(b); for i=1:numel(n),out.(n{i})=b.(n{i});end,end
