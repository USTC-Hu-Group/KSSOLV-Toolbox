classdef Unit
    %UNIT Physical unit with integer or real powers and SI conversion.
    %
    % Strings use pymatgen syntax, for example "kg m^2 s^-2". Unit objects
    % are immutable value objects.  Multiplication, division and power
    % preserve symbolic units and canonicalize exact derived-unit matches.

    properties (Access = private)
        unitMap (1,1) struct = struct()
    end

    properties (Dependent, SetAccess = private)
        as_base_units
    end

    methods
        function obj = Unit(unit_def)
            if nargin == 0
                unit_def = struct();
            end
            obj.unitMap = ...
                kssolv.analysis.matgenlab.core.Unit.parseDefinition(unit_def);
            obj.unitMap = ...
                kssolv.analysis.matgenlab.core.Unit.canonicalize(obj.unitMap);
        end

        function n = length(obj)
            n = numel(fieldnames(obj.unitMap));
        end

        function n = numel(obj, varargin)
            if nargin == 1
                n = 1;
            else
                n = builtin("numel", obj, varargin{:});
            end
        end

        function varargout = subsref(obj, subscript)
            if subscript(1).type == "()"
                if numel(subscript(1).subs) ~= 1
                    error("KSSOLV:Matgenlab:Unit:InvalidIndex", ...
                        "Unit indexing accepts one unit name.");
                end
                result = obj.exponent(subscript(1).subs{1});
                if numel(subscript) > 1
                    result = builtin("subsref",result,subscript(2:end));
                end
                varargout{1} = result;
            else
                [varargout{1:nargout}] = builtin("subsref",obj,subscript);
            end
        end

        function keys = unit_names(obj)
            keys = string(fieldnames(obj.unitMap)).';
        end

        function value = exponent(obj, name)
            name = char(string(name));
            if ~isfield(obj.unitMap, name)
                error("KSSOLV:Matgenlab:Unit:MissingUnit", ...
                    "Unit '%s' is not present.", name);
            end
            value = obj.unitMap.(name);
        end

        function result = mtimes(obj, other)
            other = kssolv.analysis.matgenlab.core.Unit(other);
            result = kssolv.analysis.matgenlab.core.Unit. ...
                combine(obj.unitMap, other.unitMap, 1);
        end

        function result = mrdivide(obj, other)
            other = kssolv.analysis.matgenlab.core.Unit(other);
            result = kssolv.analysis.matgenlab.core.Unit. ...
                combine(obj.unitMap, other.unitMap, -1);
        end

        function result = mpower(obj, exponent)
            arguments
                obj
                exponent (1,1) double {mustBeFinite}
            end
            map = obj.unitMap;
            names = fieldnames(map);
            for index = 1:numel(names)
                map.(names{index}) = map.(names{index}) * exponent;
            end
            result = kssolv.analysis.matgenlab.core.Unit(map);
        end

        function tf = eq(obj, other)
            if ~isa(other, "kssolv.analysis.matgenlab.core.Unit")
                try
                    other = kssolv.analysis.matgenlab.core.Unit(other);
                catch
                    tf = false;
                    return
                end
            end
            tf = isequal(obj.unitMap, other.unitMap);
        end

        function tf = ne(obj, other)
            tf = ~eq(obj, other);
        end

        function text = char(obj)
            names = fieldnames(obj.unitMap);
            if isempty(names)
                text = '';
                return
            end
            powers = cellfun(@(name) obj.unitMap.(name), names);
            % Sort by descending power, then lexically within equal powers.
            uniquePowers = sort(unique(powers), "descend");
            orderedNames = {};
            for power = reshape(uniquePowers, 1, [])
                group = sort(names(powers == power));
                orderedNames = [orderedNames; group]; %#ok<AGROW>
            end
            pieces = strings(1, numel(orderedNames));
            for index = 1:numel(orderedNames)
                name = orderedNames{index};
                power = obj.unitMap.(name);
                if power == 1
                    pieces(index) = string(name);
                else
                    pieces(index) = string(name) + "^" + ...
                        kssolv.analysis.matgenlab.core.Unit.formatPower(power);
                end
            end
            text = char(strjoin(pieces, " "));
        end

        function text = string(obj)
            text = string(char(obj));
        end

        function disp(obj)
            fprintf("%s\n", char(obj));
        end

        function result = get.as_base_units(obj)
            [units, factor] = obj.get_base_units();
            result = struct("units", units, "factor", factor);
        end

        function [baseUnits, factor] = get_base_units(obj)
            definitions = ...
                kssolv.analysis.matgenlab.core.Unit.definitions();
            baseUnits = struct();
            factor = 1;
            names = fieldnames(obj.unitMap);
            for index = 1:numel(names)
                name = names{index};
                power = obj.unitMap.(name);
                if ~isKey(definitions.byName, name)
                    throw(kssolv.analysis.matgenlab.core.UnitError( ...
                        "Unknown unit %s", name));
                end
                definition = definitions.byName(name);
                dims = fieldnames(definition.dims);
                for dimIndex = 1:numel(dims)
                    dim = dims{dimIndex};
                    if ~isfield(baseUnits, dim)
                        baseUnits.(dim) = 0;
                    end
                    baseUnits.(dim) = baseUnits.(dim) + ...
                        definition.dims.(dim) * power;
                end
                factor = factor * definition.factor ^ power;
            end
            dims = fieldnames(baseUnits);
            for index = numel(dims):-1:1
                if baseUnits.(dims{index}) == 0
                    baseUnits = rmfield(baseUnits, dims{index});
                end
            end
        end

        function factor = get_conversion_factor(obj, new_unit)
            newUnit = kssolv.analysis.matgenlab.core.Unit(new_unit);
            [oldBase, oldFactor] = obj.get_base_units();
            [newBase, newFactor] = newUnit.get_base_units();
            if ~kssolv.analysis.matgenlab.core.Unit.mapsEqual( ...
                    oldBase, newBase)
                throw(kssolv.analysis.matgenlab.core.UnitError( ...
                    "Units %s and %s are not compatible!", ...
                    char(obj), char(newUnit)));
            end
            factor = oldFactor / newFactor;
        end

        function map = to_struct(obj)
            map = obj.unitMap;
        end
    end

    methods (Static, Access = private)
        function unitMap = parseDefinition(unit_def)
            if isa(unit_def, "kssolv.analysis.matgenlab.core.Unit")
                unitMap = unit_def.unitMap;
                return
            end
            if isstruct(unit_def)
                if ~isscalar(unit_def)
                    error("KSSOLV:Matgenlab:Unit:InvalidDefinition", ...
                        "A unit struct must be scalar.");
                end
                unitMap = unit_def;
            elseif isa(unit_def, "containers.Map")
                unitMap = struct();
                names = unit_def.keys;
                for index = 1:numel(names)
                    unitMap.(names{index}) = unit_def(names{index});
                end
            elseif iscell(unit_def)
                unitMap = struct();
                if size(unit_def, 2) ~= 2
                    error("KSSOLV:Matgenlab:Unit:InvalidDefinition", ...
                        "A cell unit definition must have two columns.");
                end
                for index = 1:size(unit_def, 1)
                    unitMap.(char(string(unit_def{index,1}))) = ...
                        double(unit_def{index,2});
                end
            elseif ischar(unit_def) || (isstring(unit_def) && isscalar(unit_def))
                text = char(string(unit_def));
                unitMap = struct();
                matches = regexp(text, ...
                    '([A-Za-z]+)\s*\^*\s*([\-+0-9.]*)', ...
                    'tokens');
                for index = 1:numel(matches)
                    name = matches{index}{1};
                    powerText = matches{index}{2};
                    if isempty(powerText)
                        power = 1;
                    else
                        power = str2double(powerText);
                    end
                    if isnan(power)
                        error("KSSOLV:Matgenlab:Unit:InvalidPower", ...
                            "Invalid exponent in unit '%s'.", text);
                    end
                    if ~isfield(unitMap, name)
                        unitMap.(name) = 0;
                    end
                    unitMap.(name) = unitMap.(name) + power;
                end
                if ~isempty(strtrim(text)) && isempty(matches)
                    error("KSSOLV:Matgenlab:Unit:InvalidDefinition", ...
                        "Could not parse unit '%s'.", text);
                end
            else
                error("KSSOLV:Matgenlab:Unit:InvalidDefinition", ...
                    "Unit definition must be text, a struct, map, cell pairs, or Unit.");
            end
            names = fieldnames(unitMap);
            for index = numel(names):-1:1
                value = unitMap.(names{index});
                if ~(isnumeric(value) && isscalar(value) && isfinite(value))
                    error("KSSOLV:Matgenlab:Unit:InvalidPower", ...
                        "Unit powers must be finite numeric scalars.");
                end
                if value == 0
                    unitMap = rmfield(unitMap, names{index});
                end
            end
        end

        function result = combine(left, right, sign)
            map = left;
            names = fieldnames(right);
            for index = 1:numel(names)
                name = names{index};
                if ~isfield(map, name)
                    map.(name) = 0;
                end
                map.(name) = map.(name) + sign * right.(name);
            end
            result = kssolv.analysis.matgenlab.core.Unit(map);
        end

        function map = canonicalize(map)
            definitions = ...
                kssolv.analysis.matgenlab.core.Unit.definitions();
            derivedNames = definitions.derivedOrder;
            for index = 1:numel(derivedNames)
                name = derivedNames{index};
                definition = definitions.byName(name);
                if definition.factor == 1 && ...
                        kssolv.analysis.matgenlab.core.Unit.mapsEqual( ...
                        map, definition.symbolic)
                    map = struct();
                    map.(name) = 1;
                    return
                end
            end
        end

        function tf = mapsEqual(left, right)
            leftNames = sort(fieldnames(left));
            rightNames = sort(fieldnames(right));
            if ~isequal(leftNames, rightNames)
                tf = false;
                return
            end
            tf = true;
            for index = 1:numel(leftNames)
                name = leftNames{index};
                if left.(name) ~= right.(name)
                    tf = false;
                    return
                end
            end
        end

        function result = definitions()
            persistent cached
            if ~isempty(cached)
                result = cached;
                return
            end
            C = kssolv.analysis.matgenlab.core.Constants;
            haToEv = 1 / C.value("electron volt-hartree relationship");
            bohr = C.value("Bohr radius");
            amu = C.value("atomic mass unit-kilogram relationship");
            names = {};
            records = {};
            derivedOrder = {};

            addBase("m", "length", 1, "m");
            addBase("km", "length", 1000, "m");
            addBase("mile", "length", C.mile, "m");
            addBase("ang", "length", 1e-10, "m");
            addBase("cm", "length", 1e-2, "m");
            addBase("pm", "length", 1e-12, "m");
            addBase("bohr", "length", bohr, "m");
            addBase("kg", "mass", 1, "kg");
            addBase("g", "mass", 1e-3, "kg");
            addBase("amu", "mass", amu, "kg");
            addBase("s", "time", 1, "s");
            addBase("min", "time", 60, "s");
            addBase("h", "time", 3600, "s");
            addBase("d", "time", 86400, "s");
            addBase("A", "current", 1, "A");
            addBase("K", "temperature", 1, "K");
            addBase("mol", "amount", 1, "mol");
            addBase("atom", "amount", 1 / C.N_A, "mol");
            addBase("cd", "intensity", 1, "cd");
            addBase("byte", "memory", 1, "byte");
            addBase("KB", "memory", 1024, "byte");
            addBase("MB", "memory", 1024^2, "byte");
            addBase("GB", "memory", 1024^3, "byte");
            addBase("TB", "memory", 1024^4, "byte");

            energyDims = struct("kg",1,"m",2,"s",-2);
            addDerived("eV", "energy", C.e, energyDims, ...
                struct("kg",1,"m",2,"s",-2));
            addDerived("meV", "energy", C.e*1e-3, energyDims, struct());
            addDerived("Ha", "energy", C.e*haToEv, energyDims, struct());
            addDerived("Ry", "energy", C.e*haToEv/2, energyDims, struct());
            addDerived("J", "energy", 1, energyDims, energyDims);
            addDerived("kJ", "energy", 1000, energyDims, struct());
            addDerived("kCal", "energy", 1000*C.calorie, energyDims, struct());
            addDerived("C", "charge", 1, struct("A",1,"s",1), ...
                struct("A",1,"s",1));
            addDerived("e", "charge", C.e, struct("A",1,"s",1), struct());
            addDerived("N", "force", 1, struct("kg",1,"m",1,"s",-2), ...
                struct("kg",1,"m",1,"s",-2));
            addDerived("KN", "force", 1e3, struct("kg",1,"m",1,"s",-2), struct());
            addDerived("MN", "force", 1e6, struct("kg",1,"m",1,"s",-2), struct());
            addDerived("GN", "force", 1e9, struct("kg",1,"m",1,"s",-2), struct());
            addDerived("Hz", "frequency", 1, struct("s",-1), struct("s",-1));
            addDerived("KHz", "frequency", 1e3, struct("s",-1), struct());
            addDerived("MHz", "frequency", 1e6, struct("s",-1), struct());
            addDerived("GHz", "frequency", 1e9, struct("s",-1), struct());
            addDerived("THz", "frequency", 1e12, struct("s",-1), struct());
            pressureDims = struct("kg",1,"m",-1,"s",-2);
            addDerived("Pa", "pressure", 1, pressureDims, pressureDims);
            addDerived("KPa", "pressure", 1e3, pressureDims, struct());
            addDerived("MPa", "pressure", 1e6, pressureDims, struct());
            addDerived("GPa", "pressure", 1e9, pressureDims, struct());
            powerDims = struct("m",2,"kg",1,"s",-3);
            addDerived("W", "power", 1, powerDims, powerDims);
            addDerived("KW", "power", 1e3, powerDims, struct());
            addDerived("MW", "power", 1e6, powerDims, struct());
            addDerived("GW", "power", 1e9, powerDims, struct());
            addDerived("V", "emf", 1, ...
                struct("m",2,"kg",1,"s",-3,"A",-1), ...
                struct("m",2,"kg",1,"s",-3,"A",-1));
            addDerived("F", "capacitance", 1, ...
                struct("m",-2,"kg",-1,"s",4,"A",2), ...
                struct("m",-2,"kg",-1,"s",4,"A",2));
            addDerived("ohm", "resistance", 1, ...
                struct("m",2,"kg",1,"s",-3,"A",-2), ...
                struct("m",2,"kg",1,"s",-3,"A",-2));
            addDerived("S", "conductance", 1, ...
                struct("m",-2,"kg",-1,"s",3,"A",2), ...
                struct("m",-2,"kg",-1,"s",3,"A",2));
            addDerived("Wb", "magnetic_flux", 1, ...
                struct("m",2,"kg",1,"s",-2,"A",-1), ...
                struct("m",2,"kg",1,"s",-2,"A",-1));
            addDerived("barn", "cross_section", 1e-28, ...
                struct("m",2), struct());
            addDerived("mbarn", "cross_section", 1e-31, ...
                struct("m",2), struct());

            cached = struct( ...
                "byName", containers.Map(names, records), ...
                "derivedOrder", {derivedOrder});
            result = cached;

            function addBase(name, type, factor, base)
                name = char(name);
                type = char(type);
                base = char(base);
                dims = struct();
                dims.(base) = 1;
                names{end+1} = name;
                records{end+1} = struct("type", type, "factor", factor, ...
                    "dims", dims, "symbolic", struct());
            end
            function addDerived(name, type, factor, dims, symbolic)
                name = char(name);
                type = char(type);
                names{end+1} = name;
                records{end+1} = struct("type", type, "factor", factor, ...
                    "dims", dims, "symbolic", symbolic);
                derivedOrder{end+1} = name;
            end
        end

        function text = formatPower(value)
            if value == fix(value)
                text = string(sprintf("%d", value));
            else
                text = string(sprintf("%.15g", value));
            end
        end
    end

    methods (Static)
        function names = supported_for_type(unitType)
            definitions = ...
                kssolv.analysis.matgenlab.core.Unit.definitions();
            allNames = string(keys(definitions.byName));
            mask = false(size(allNames));
            for index = 1:numel(allNames)
                record = definitions.byName(char(allNames(index)));
                mask(index) = string(record.type) == string(unitType);
            end
            % Match upstream declaration order, not containers.Map order.
            declarationOrder = [ ...
                "m","km","mile","ang","cm","pm","bohr", ...
                "kg","g","amu","s","min","h","d","A","K","mol","atom", ...
                "cd","byte","KB","MB","GB","TB","eV","meV","Ha","Ry", ...
                "J","kJ","kCal","C","e","N","KN","MN","GN","Hz","KHz", ...
                "MHz","GHz","THz","Pa","KPa","MPa","GPa","W","KW","MW", ...
                "GW","V","F","ohm","S","Wb","barn","mbarn"];
            names = declarationOrder(ismember(declarationOrder, allNames(mask)));
        end

        function type = type_for_name(name)
            definitions = ...
                kssolv.analysis.matgenlab.core.Unit.definitions();
            name = char(string(name));
            if ~isKey(definitions.byName, name)
                throw(kssolv.analysis.matgenlab.core.UnitError( ...
                    "Unknown unit %s", name));
            end
            record = definitions.byName(name);
            type = string(record.type);
        end
    end
end
