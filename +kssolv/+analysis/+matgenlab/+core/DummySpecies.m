classdef DummySpecies < kssolv.analysis.matgenlab.core.Species
    %DUMMYSPECIES Non-element species such as a vacancy or placeholder.

    methods
        function obj = DummySpecies(symbol, oxidationState, varargin)
            if nargin < 1, symbol = "X"; end
            if nargin < 2 || isempty(oxidationState), oxidationState = 0; end
            obj@kssolv.analysis.matgenlab.core.Species();
            symbol = lower(string(symbol));
            symbol = upper(extractBefore(symbol, 2)) + extractAfter(symbol, 1);
            for count = 1:min(2, strlength(symbol))
                prefix = extractBefore(symbol, count + 1);
                if kssolv.analysis.matgenlab.core.Element.isValidSymbol(prefix)
                    error("KSSOLV:Matgenlab:DummySpecies:InvalidSymbol", ...
                        "%s contains %s, which is a valid element symbol.", symbol, prefix);
                end
            end
            spinValue = NaN;
            if ~isempty(varargin)
                for idx = 1:2:numel(varargin)
                    if strcmpi(string(varargin{idx}), "spin")
                        spinValue = varargin{idx + 1};
                    end
                end
            end
            obj.symbol = symbol;
            obj.oxi_state = double(oxidationState);
            obj.spin = double(spinValue);
            obj.is_dummy = true;
            obj.Z = kssolv.analysis.matgenlab.core.DummySpecies.stableHash(symbol);
            obj.A = NaN;
        end

        function out = char(obj)
            out = char(obj.symbol);
            if ~isnan(obj.oxi_state)
                magnitude = kssolv.analysis.matgenlab.core.Species. ...
                    formatNumber(abs(obj.oxi_state), true);
                if obj.oxi_state >= 0, sign_ = "+"; else, sign_ = "-"; end
                out = char(obj.symbol + magnitude + sign_);
            end
            if ~isnan(obj.spin)
                out = sprintf("%s,spin=%s", out, ...
                    kssolv.analysis.matgenlab.core.Species. ...
                    formatNumber(obj.spin, false));
            end
        end
        function out = string(obj), out = string(char(obj)); end
        function result = asDict(obj)
            result = struct(x_module="pymatgen.core.periodic_table", ...
                x_class="DummySpecies", element=obj.symbol, ...
                oxidation_state=obj.oxi_state, spin=obj.spin);
        end
        function result = as_dict(obj), result = obj.asDict(); end
    end

    methods (Static)
        function obj = fromStr(text)
            parsed = regexp(char(string(text)), ...
                '^([A-Za-z]+)([0-9]*\.?[0-9]*)([+-]?)$', 'tokens', 'once');
            if isempty(parsed)
                error("KSSOLV:Matgenlab:DummySpecies:Parse", ...
                    "Invalid dummy species string '%s'.", string(text));
            end
            if isempty(parsed{2}) && isempty(parsed{3})
                oxi = 0;
            else
                oxi = str2double(parsed{2});
                if isnan(oxi), oxi = 1; end
                if strcmp(parsed{3}, "-"), oxi = -oxi; end
            end
            obj = kssolv.analysis.matgenlab.core.DummySpecies(parsed{1}, oxi);
        end
        function obj = from_str(text), obj = kssolv.analysis.matgenlab.core.DummySpecies.fromStr(text); end
        function obj = fromDict(dct)
            spinValue = NaN;
            if isfield(dct, "spin") && ~isempty(dct.spin), spinValue = dct.spin; end
            obj = kssolv.analysis.matgenlab.core.DummySpecies( ...
                dct.element, dct.oxidation_state, "spin", spinValue);
        end
        function obj = from_dict(dct), obj = kssolv.analysis.matgenlab.core.DummySpecies.fromDict(dct); end
    end

    methods (Static, Access = private)
        function value = stableHash(text)
            bytes = unicode2native(char(text), "UTF-8");
            hash = uint32(2166136261);
            for idx = 1:numel(bytes)
                hash = bitxor(hash, uint32(bytes(idx)));
                hash = uint32(mod(uint64(hash) * uint64(16777619), 2^32));
            end
            value = double(bitand(hash, uint32(intmax("int32"))));
        end
    end
end
