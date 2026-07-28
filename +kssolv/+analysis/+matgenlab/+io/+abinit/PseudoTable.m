classdef PseudoTable
    properties (SetAccess = private)
        pseudos cell = {}
    end
    properties (Dependent)
        allnc
        allpaw
        zlist
    end
    methods
        function obj = PseudoTable(items)
            if nargin == 0 || isempty(items), return; end
            if isa(items, "kssolv.analysis.matgenlab.io.abinit.PseudoTable")
                obj.pseudos = items.pseudos; return
            end
            if ischar(items) || (isstring(items) && isscalar(items))
                items = {items};
            elseif isstring(items)
                items = cellstr(items);
            elseif ~iscell(items)
                items = num2cell(items);
            end
            for i = 1:numel(items)
                p = kssolv.analysis.matgenlab.io.abinit.Pseudo.as_pseudo(items{i});
                if ~isempty(p), obj.pseudos{end + 1} = p; end
            end
            if ~isempty(obj.pseudos)
                [~, order] = sort(cellfun(@(p) p.Z, obj.pseudos));
                obj.pseudos = obj.pseudos(order);
            end
        end
        function value = get.allnc(obj), value = all(cellfun(@(p) p.isnc, obj.pseudos)); end
        function value = get.allpaw(obj), value = all(cellfun(@(p) p.ispaw, obj.pseudos)); end
        function value = get.zlist(obj), value = unique(cellfun(@(p) p.Z, obj.pseudos)); end
        function value = is_complete(obj, zmax)
            if nargin < 2, zmax = 118; end
            value = all(ismember(1:zmax-1, obj.zlist));
        end
        function value = length(obj), value = numel(obj.pseudos); end
        function value = numel(obj, varargin), value = builtin("numel", obj, varargin{:}); end
        function value = char(obj), value = obj.to_table(); end
        function value = string(obj), value = string(obj.to_table()); end
        function value = subsref(obj, s)
            if strcmp(s(1).type, "()") && numel(s(1).subs) == 1 && isnumeric(s(1).subs{1}) %#ok<ISCL>
                z = s(1).subs{1}; selected = obj.pseudos(cellfun(@(p) ismember(p.Z, z), obj.pseudos));
                value = kssolv.analysis.matgenlab.io.abinit.PseudoTable(selected);
                if numel(s) > 1, value = builtin("subsref", value, s(2:end)); end
            elseif strcmp(s(1).type, ".") && ~isprop(obj, s(1).subs) && ~ismethod(obj, s(1).subs)
                selected = obj.select_symbols(string(s(1).subs), true);
                if isempty(selected), value = builtin("subsref", obj, s);
                else
                    value = selected;
                    if numel(s) > 1, value = builtin("subsref", value, s(2:end)); end
                end
            else
                value = builtin("subsref", obj, s);
            end
        end
        function value = as_dict(obj, varargin)
            value = struct("x_module", "pymatgen.io.abinit.pseudos", "x_class", "PseudoTable", "pseudos", {cellfun(@(p) p.as_dict(), obj.pseudos, "UniformOutput", false)});
        end
        function value = asDict(obj), value = obj.as_dict(); end
        function value = all_combinations_for_elements(obj, symbols)
            symbols = string(symbols); pools = cell(1, numel(symbols));
            for i = 1:numel(symbols), pools{i} = obj.select_symbols(symbols(i), true); end
            value = {{}};
            for i = 1:numel(pools)
                next = {};
                for j = 1:numel(value)
                    for k = 1:numel(pools{i}), next{end + 1} = [value{j}, pools{i}(k)]; end %#ok<AGROW>
                end
                value = next;
            end
        end
        function value = pseudo_with_symbol(obj, symbol, allow_multi)
            if nargin < 3, allow_multi = false; end
            found = obj.select_symbols(symbol, true);
            if isempty(found) || (numel(found) > 1 && ~allow_multi)
                error("KSSOLV:Matgenlab:Abinit:PseudoSelection", ...
                    "Found %d occurrences of symbol %s.", numel(found), symbol);
            end
            if allow_multi, value = found; else, value = found{1}; end
        end
        function value = pseudos_with_symbols(obj, symbols)
            symbols = string(symbols); value = cell(1, numel(symbols));
            for i = 1:numel(symbols), value{i} = obj.pseudo_with_symbol(symbols(i)); end
        end
        function value = select_symbols(obj, symbols, ret_list)
            if nargin < 3, ret_list = false; end
            symbols = string(symbols); exclude = startsWith(symbols(1), "-");
            if exclude
                if any(~startsWith(symbols, "-")), error("KSSOLV:Matgenlab:Abinit:PseudoSelection", "All excluded symbols must start with '-'."); end
                symbols = extractAfter(symbols, 1);
            end
            selected = obj.pseudos(cellfun(@(p) xor(exclude, ismember(p.symbol, symbols)), obj.pseudos));
            if ret_list, value = selected;
            else, value = kssolv.analysis.matgenlab.io.abinit.PseudoTable(selected);
            end
        end
        function value = get_pseudos_for_structure(obj, structure)
            if isprop(structure, "symbol_set"), symbols = structure.symbol_set;
            else, symbols = unique(string({structure.species.symbol}), "stable");
            end
            value = obj.pseudos_with_symbols(symbols);
        end
        function print_table(obj, varargin), fprintf("%s\n", obj.to_table(varargin{:})); end
        function value = to_table(obj, filter_function)
            if nargin < 2, filter_function = []; end
            lines = strings(numel(obj.pseudos) + 1, 1);
            lines(1) = "basename | symbol | Z_val | l_max | l_local | type";
            count = 1;
            for i = 1:numel(obj.pseudos)
                p = obj.pseudos{i};
                if ~isempty(filter_function) && ~filter_function(p), continue; end
                count = count + 1;
                lines(count) = sprintf("%s | %s | %g | %g | %g | %s", ...
                    p.basename, p.symbol, p.Z_val, p.l_max, p.l_local, p.type);
            end
            value = char(join(lines(1:count), newline));
        end
        function value = sorted(obj, attrname, reverse)
            if nargin < 3, reverse = false; end
            vals = cellfun(@(p) double(p.(char(attrname))), obj.pseudos);
            if reverse, direction = "descend"; else, direction = "ascend"; end
            [~, idx] = sort(vals, direction); value = kssolv.analysis.matgenlab.io.abinit.PseudoTable(obj.pseudos(idx));
        end
        function value = sort_by_z(obj), value = obj.sorted("Z"); end
        function value = select(obj, condition)
            value = kssolv.analysis.matgenlab.io.abinit.PseudoTable(obj.pseudos(cellfun(condition, obj.pseudos)));
        end
        function value = with_dojo_report(obj), value = obj.select(@(p) p.has_dojo_report); end
        function value = select_rows(obj, rows)
            value = obj.select(@(p) ismember(p.element.row, rows));
        end
        function value = select_family(obj, family)
            name = "is_" + string(family);
            value = obj.select(@(p) p.element.(char(name)));
        end
    end
    methods (Static)
        function obj = as_table(items), obj = kssolv.analysis.matgenlab.io.abinit.PseudoTable(items); end
        function obj = from_dir(top, exts, varargin)
            if nargin < 2 || isempty(exts), exts = "psp8"; end
            entries = dir(fullfile(top, "**", "*")); paths = {};
            for i = 1:numel(entries)
                if entries(i).isdir, continue; end
                [~, ~, ext] = fileparts(entries(i).name);
                if string(exts) == "all_files" || ismember(erase(string(ext), "."), string(exts))
                    paths{end + 1} = fullfile(entries(i).folder, entries(i).name); %#ok<AGROW>
                end
            end
            parsed = {};
            for i = 1:numel(paths)
                try
                    parsed{end + 1} = kssolv.analysis.matgenlab.io.abinit.Pseudo.from_file(paths{i}); %#ok<AGROW>
                catch
                    % Ignore non-pseudopotential files when scanning a directory.
                end
            end
            obj = kssolv.analysis.matgenlab.io.abinit.PseudoTable(parsed);
        end
        function obj = from_dict(value)
            items = value.pseudos; parsed = cell(size(items));
            for i = 1:numel(items), parsed{i} = kssolv.analysis.matgenlab.io.abinit.Pseudo.from_dict(items{i}); end
            obj = kssolv.analysis.matgenlab.io.abinit.PseudoTable(parsed);
        end
        function obj = fromDict(value), obj = kssolv.analysis.matgenlab.io.abinit.PseudoTable.from_dict(value); end
    end
end
