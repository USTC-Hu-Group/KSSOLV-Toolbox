classdef XcFunc < kssolv.analysis.matgenlab.util.MSONable
    %XCFUNC Exchange-correlation functional descriptor.

    properties (SetAccess = immutable)
        xc = []
        x = []
        c = []
    end

    properties (Dependent, SetAccess = private)
        type
        name
    end

    methods
        function obj = XcFunc(xc, x, c)
            if nargin < 1, xc = []; end
            if nargin < 2, x = []; end
            if nargin < 3, c = []; end
            if isempty(xc)
                if isempty(x) || isempty(c)
                    error("KSSOLV:Matgenlab:XcFunc:MissingComponents", ...
                        "x and c must be specified when xc is empty.");
                end
                obj.x = kssolv.analysis.matgenlab.core.LibxcFunc(x);
                obj.c = kssolv.analysis.matgenlab.core.LibxcFunc(c);
            elseif ~isempty(x) || ~isempty(c)
                error("KSSOLV:Matgenlab:XcFunc:ExclusiveComponents", ...
                    "x and c must be empty when xc is specified.");
            else
                obj.xc = kssolv.analysis.matgenlab.core.LibxcFunc(xc);
            end
        end

        function value = get.type(obj)
            alias = obj.alias();
            if ~isempty(alias)
                value = alias.type;
            elseif ~isempty(obj.xc)
                value = obj.xc.family;
            elseif ~isempty(obj.x) && ~isempty(obj.c)
                value = obj.x.family + "+" + obj.c.family;
            else
                value = missing;
            end
        end

        function value = get.name(obj)
            alias = obj.alias();
            if ~isempty(alias)
                value = alias.name;
            elseif ~isempty(obj.xc)
                value = obj.xc.name;
            elseif ~isempty(obj.x) && ~isempty(obj.c)
                value = obj.x.name + "+" + obj.c.name;
            else
                value = missing;
            end
        end

        function value = eq(obj, other)
            if isa(other, "kssolv.analysis.matgenlab.core.XcFunc")
                value = obj.name == other.name;
            elseif ischar(other) || isstring(other)
                value = obj.name == string(other);
            else
                value = false;
            end
        end
        function value = ne(obj, other), value = ~eq(obj, other); end
        function value = char(obj), value = char(obj.name); end
        function value = string(obj), value = obj.name; end

        function value = as_dict(obj)
            value = struct( ...
                "x_module", "pymatgen.core.xcfunc", ...
                "x_class", "XcFunc");
            if ~isempty(obj.x), value.x = obj.x.as_dict(); end
            if ~isempty(obj.c), value.c = obj.c.as_dict(); end
            if ~isempty(obj.xc), value.xc = obj.xc.as_dict(); end
        end
        function value = asDict(obj), value = obj.as_dict(); end
    end

    methods (Static)
        function values = aliases()
            aliases = kssolv.analysis.matgenlab.core.XcFunc.aliasData();
            values = string({aliases.name});
        end

        function value = asxc(input)
            if isa(input, "kssolv.analysis.matgenlab.core.XcFunc")
                value = input;
            elseif ischar(input) || isstring(input)
                value = ...
                    kssolv.analysis.matgenlab.core.XcFunc.from_name(input);
            else
                error("KSSOLV:Matgenlab:XcFunc:Conversion", ...
                    "Cannot convert this value to XcFunc.");
            end
        end

        function obj = from_abinit_ixc(ixc)
            if ixc == 0, obj = []; return; end
            if ixc > 0
                table = { ...
                    1, "LDA_XC_TETER93", "", ""; ...
                    2, "", "LDA_X", "LDA_C_PZ"; ...
                    4, "", "LDA_X", "LDA_C_WIGNER"; ...
                    5, "", "LDA_X", "LDA_C_HL"; ...
                    7, "", "LDA_X", "LDA_C_PW"; ...
                    11, "", "GGA_X_PBE", "GGA_C_PBE"; ...
                    14, "", "GGA_X_PBE_R", "GGA_C_PBE"; ...
                    15, "", "GGA_X_RPBE", "GGA_C_PBE"};
                location = find(cell2mat(table(:, 1)) == ixc, 1);
                if isempty(location)
                    error("KSSOLV:Matgenlab:XcFunc:AbinitIxc", ...
                        "Unsupported positive Abinit ixc value %g.", ixc);
                end
                if strlength(table{location, 2}) > 0
                    obj = kssolv.analysis.matgenlab.core.XcFunc( ...
                        table{location, 2});
                else
                    obj = kssolv.analysis.matgenlab.core.XcFunc([], ...
                        table{location, 3}, table{location, 4});
                end
                return
            end
            encoded = abs(fix(ixc));
            first = floor(encoded / 1000);
            last = encoded - first * 1000;
            exchange = ...
                kssolv.analysis.matgenlab.core.LibxcFunc(first);
            correlation = ...
                kssolv.analysis.matgenlab.core.LibxcFunc(last);
            if ~exchange.is_x_kind
                temporary = exchange;
                exchange = correlation;
                correlation = temporary;
            end
            if ~exchange.is_x_kind
                error("KSSOLV:Matgenlab:XcFunc:ExchangeKind", ...
                    "Encoded exchange functional is not exchange-kind.");
            end
            if ~correlation.is_c_kind
                error("KSSOLV:Matgenlab:XcFunc:CorrelationKind", ...
                    "Encoded correlation functional is not correlation-kind.");
            end
            obj = kssolv.analysis.matgenlab.core.XcFunc( ...
                [], exchange, correlation);
        end

        function obj = from_name(name)
            obj = kssolv.analysis.matgenlab.core.XcFunc. ...
                from_type_name([], name);
        end

        function obj = from_type_name(typeValue, name)
            aliases = kssolv.analysis.matgenlab.core.XcFunc.aliasData();
            for index = 1:numel(aliases)
                if (~isempty(typeValue) && ...
                        string(typeValue) ~= aliases(index).type) || ...
                        string(name) ~= aliases(index).name
                    continue
                end
                obj = kssolv.analysis.matgenlab.core.XcFunc([], ...
                    aliases(index).x, aliases(index).c);
                return
            end
            pieces = split(string(name), "+");
            if numel(pieces) == 2
                obj = kssolv.analysis.matgenlab.core.XcFunc([], ...
                    strtrim(pieces(1)), strtrim(pieces(2)));
            elseif isscalar(pieces)
                obj = kssolv.analysis.matgenlab.core.XcFunc( ...
                    strtrim(pieces(1)));
            else
                error("KSSOLV:Matgenlab:XcFunc:Name", ...
                    "Invalid functional name '%s'.", name);
            end
        end

        function obj = from_dict(value)
            xc = []; x = []; c = [];
            if isfield(value, "xc")
                xc = ...
                    kssolv.analysis.matgenlab.core.LibxcFunc.from_dict(value.xc);
            end
            if isfield(value, "x")
                x = kssolv.analysis.matgenlab.core.LibxcFunc.from_dict(value.x);
            end
            if isfield(value, "c")
                c = kssolv.analysis.matgenlab.core.LibxcFunc.from_dict(value.c);
            end
            obj = kssolv.analysis.matgenlab.core.XcFunc(xc, x, c);
        end
        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.core.XcFunc.from_dict(value);
        end
    end

    methods (Access = private)
        function value = alias(obj)
            value = [];
            if isempty(obj.x) || isempty(obj.c), return; end
            aliases = kssolv.analysis.matgenlab.core.XcFunc.aliasData();
            for index = 1:numel(aliases)
                if obj.x == aliases(index).x && obj.c == aliases(index).c
                    value = aliases(index);
                    return
                end
            end
        end
    end

    methods (Static, Access = private)
        function values = aliasData()
            persistent cache
            if isempty(cache)
                types = ["LDA", "LDA", "LDA", "LDA", "LDA", "LDA", ...
                    "LDA", "GGA", "GGA", "GGA", "GGA", "GGA", "GGA", ...
                    "GGA"];
                names = ["PW", "PW_MOD", "PZ", "W", "HL", "GL", "VWN", ...
                    "PW91", "PBE", "RPBE", "revPBE", "PBEsol", "AM05", ...
                    "BLYP"];
                exchanges = ["LDA_X", "LDA_X", "LDA_X", "LDA_X", ...
                    "LDA_X", "LDA_X", "LDA_X", "GGA_X_PW91", ...
                    "GGA_X_PBE", "GGA_X_RPBE", "GGA_X_PBE_R", ...
                    "GGA_X_PBE_SOL", "GGA_X_AM05", "GGA_X_B88"];
                correlations = ["LDA_C_PW", "LDA_C_PW_MOD", "LDA_C_PZ", ...
                    "LDA_C_WIGNER", "LDA_C_HL", "LDA_C_GL", "LDA_C_VWN", ...
                    "GGA_C_PW91", "GGA_C_PBE", "GGA_C_PBE", "GGA_C_PBE", ...
                    "GGA_C_PBE_SOL", "GGA_C_AM05", "GGA_C_LYP"];
                cache = repmat(struct("type", "", "name", "", ...
                    "x", [], "c", []), 1, numel(names));
                for index = 1:numel(names)
                    cache(index).type = types(index);
                    cache(index).name = names(index);
                    cache(index).x = ...
                        kssolv.analysis.matgenlab.core.LibxcFunc( ...
                            exchanges(index));
                    cache(index).c = ...
                        kssolv.analysis.matgenlab.core.LibxcFunc( ...
                            correlations(index));
                end
            end
            values = cache;
        end
    end
end
