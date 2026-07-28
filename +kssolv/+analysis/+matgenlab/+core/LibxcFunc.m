classdef LibxcFunc < kssolv.analysis.matgenlab.util.MSONable
    %LIBXCFUNC Libxc functional identifier and frozen metadata.

    properties (SetAccess = immutable)
        name (1,1) string
        value (1,1) double
        kind (1,1) string
        family (1,1) string
    end

    properties (Dependent, SetAccess = private)
        info_dict
        is_x_kind
        is_c_kind
        is_k_kind
        is_xc_kind
        is_lda_family
        is_gga_family
        is_mgga_family
        is_hyb_gga_family
        is_hyb_mgga_family
    end

    methods
        function obj = LibxcFunc(identifier)
            if isa(identifier, ...
                    "kssolv.analysis.matgenlab.core.LibxcFunc")
                obj = identifier;
                return
            end
            row = kssolv.analysis.matgenlab.core.LibxcFunc.lookup(identifier);
            obj.name = string(row.name);
            obj.value = double(row.value);
            obj.kind = string(row.Kind);
            obj.family = string(row.Family);
        end

        function value = get.info_dict(obj)
            value = ...
                kssolv.analysis.matgenlab.core.LibxcFunc.lookup(obj.value);
            value = rmfield(value, ["name", "value"]);
        end
        function value = get.is_x_kind(obj), value = obj.kind == "EXCHANGE"; end
        function value = get.is_c_kind(obj), value = obj.kind == "CORRELATION"; end
        function value = get.is_k_kind(obj), value = obj.kind == "KINETIC"; end
        function value = get.is_xc_kind(obj)
            value = obj.kind == "EXCHANGE_CORRELATION";
        end
        function value = get.is_lda_family(obj), value = obj.family == "LDA"; end
        function value = get.is_gga_family(obj), value = obj.family == "GGA"; end
        function value = get.is_mgga_family(obj), value = obj.family == "MGGA"; end
        function value = get.is_hyb_gga_family(obj)
            value = obj.family == "HYB_GGA";
        end
        function value = get.is_hyb_mgga_family(obj)
            value = obj.family == "HYB_MGGA";
        end

        function value = eq(obj, other)
            try
                other = ...
                    kssolv.analysis.matgenlab.core.LibxcFunc(other);
                value = obj.value == other.value;
            catch
                value = false;
            end
        end
        function value = ne(obj, other), value = ~eq(obj, other); end
        function value = char(obj), value = char(obj.name); end
        function value = string(obj), value = obj.name; end

        function value = as_dict(obj)
            value = struct( ...
                "name", obj.name, ...
                "x_module", "pymatgen.core.libxcfunc", ...
                "x_class", "LibxcFunc");
        end
        function value = asDict(obj), value = obj.as_dict(); end
        function value = to_json(obj)
            value = kssolv.analysis.matgenlab.util.encode(obj.as_dict());
        end
    end

    methods (Static)
        function values = all_families()
            rows = kssolv.analysis.matgenlab.core.LibxcFunc.rows();
            values = sort(unique(cellfun(@(row) string(row.Family), ...
                rows)));
        end

        function values = all_kinds()
            rows = kssolv.analysis.matgenlab.core.LibxcFunc.rows();
            values = sort(unique(cellfun(@(row) string(row.Kind), rows)));
        end

        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.core.LibxcFunc(value.name);
        end
        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.core.LibxcFunc.from_dict(value);
        end

        function obj = from_name(name)
            obj = kssolv.analysis.matgenlab.core.LibxcFunc(name);
        end
    end

    methods (Static, Access = private)
        function row = lookup(identifier)
            rows = kssolv.analysis.matgenlab.core.LibxcFunc.rows();
            if ischar(identifier) || isstring(identifier)
                names = cellfun(@(value) string(value.name), rows);
                location = find(names == string(identifier), 1);
            elseif isnumeric(identifier) && isscalar(identifier)
                numbers = cellfun(@(value) double(value.value), rows);
                location = find(numbers == double(identifier), 1);
            else
                location = [];
            end
            if isempty(location)
                error("KSSOLV:Matgenlab:LibxcFunc:InvalidIdentifier", ...
                    "Unknown Libxc functional identifier.");
            end
            row = rows{location};
        end

        function values = rows()
            persistent cache
            if isempty(cache)
                filename = fullfile(fileparts(mfilename("fullpath")), ...
                    "+data", "libxc_data.json");
                cache = jsondecode(fileread(filename));
                if isstruct(cache), cache = num2cell(cache); end
                cache = reshape(cache, 1, []);
            end
            values = cache;
        end
    end
end
