classdef CovalentBond
    %COVALENTBOND A covalent bond between two Site objects.

    properties (SetAccess = immutable)
        site1
        site2
    end

    properties (Dependent, SetAccess = private)
        length
    end

    methods
        function obj = CovalentBond(site1, site2)
            if ~isa(site1, "kssolv.analysis.matgenlab.core.Site") || ...
                    ~isa(site2, "kssolv.analysis.matgenlab.core.Site")
                error("KSSOLV:Matgenlab:Bonds:SiteType", ...
                    "CovalentBond endpoints must be Site objects.");
            end
            obj.site1 = site1;
            obj.site2 = site2;
        end

        function value = get.length(obj)
            value = obj.site1.distance(obj.site2);
        end

        function value = get_bond_order(obj, tol, default_bl)
            if nargin < 2, tol = 0.2; end
            if nargin < 3, default_bl = []; end
            value = kssolv.analysis.matgenlab.core.get_bond_order( ...
                obj.site1.specie, obj.site2.specie, obj.length, ...
                tol, default_bl);
        end

        function value = char(obj)
            value = sprintf("Covalent bond between %s and %s", ...
                char(obj.site1), char(obj.site2));
        end

        function value = string(obj), value = string(char(obj)); end
    end

    methods (Static)
        function bonded = is_bonded(site1, site2, tol, bond_order, default_bl)
            if nargin < 3 || isempty(tol), tol = 0.2; end
            if nargin < 4, bond_order = []; end
            if nargin < 5, default_bl = []; end
            symbols = sort([string(site1.specie.symbol), ...
                string(site2.specie.symbol)]);
            key = char(strjoin(symbols, "|"));
            data = kssolv.analysis.matgenlab.core.bond_lengths_data();
            if isKey(data, key)
                lengths = data(key);
                if ~isempty(bond_order)
                    if ~isKey(lengths, double(bond_order))
                        error("KSSOLV:Matgenlab:Bonds:MissingOrder", ...
                            "No order %g bond data for %s - %s.", ...
                            bond_order, symbols(1), symbols(2));
                    end
                    bonded = site1.distance(site2) < ...
                        (1 + tol) * lengths(double(bond_order));
                else
                    values = cell2mat(lengths.values);
                    bonded = any(site1.distance(site2) < ...
                        (1 + tol) .* values);
                end
            elseif ~isempty(default_bl)
                bonded = site1.distance(site2) < ...
                    (1 + tol) * default_bl;
            else
                error("KSSOLV:Matgenlab:Bonds:MissingData", ...
                    "No bond data for elements %s - %s", ...
                    symbols(1), symbols(2));
            end
        end
    end
end
