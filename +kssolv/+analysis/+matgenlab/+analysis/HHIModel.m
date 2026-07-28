classdef HHIModel
    %HHIMODEL Herfindahl-Hirschman resource concentration estimator.
    %
    % Values and weighting follow pymatgen.analysis.hhi.HHIModel.  Compound
    % values are mass-fraction weighted averages of the elemental
    % production and reserve indices.

    properties (SetAccess = private)
        symbol_hhip_hhir
    end

    methods
        function obj = HHIModel(dataPath)
            if nargin < 1
                dataPath = fullfile(fileparts(mfilename("fullpath")), ...
                    "+data", "hhi_data.csv");
            end
            if ~isfile(dataPath)
                error("KSSOLV:Matgenlab:HHIModel:MissingData", ...
                    "HHI data file does not exist: %s", dataPath);
            end
            obj.symbol_hhip_hhir = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            rows = readlines(dataPath);
            for index = 1:numel(rows)
                line = strip(rows(index));
                if strlength(line) == 0 || startsWith(line, "#")
                    continue
                end
                fields = split(line, ",");
                if numel(fields) ~= 3
                    error("KSSOLV:Matgenlab:HHIModel:InvalidData", ...
                        "Malformed HHI data row %d.", index);
                end
                obj.symbol_hhip_hhir(char(strip(fields(1)))) = ...
                    [str2double(fields(2)), str2double(fields(3))];
            end
        end

        function [hhiProduction, hhiReserve] = get_hhi(obj, compOrForm)
            %GET_HHI Return production and reserve HHI for a composition.
            try
                if ~isa(compOrForm, ...
                        "kssolv.analysis.matgenlab.core.Composition")
                    compOrForm = ...
                        kssolv.analysis.matgenlab.core.Composition(compOrForm);
                end
                hhiProduction = 0;
                hhiReserve = 0;
                elements = compOrForm.elements;
                for index = 1:numel(elements)
                    element = elements{index};
                    values = obj.get_hhi_el(element);
                    fraction = compOrForm.get_wt_fraction(element);
                    hhiProduction = hhiProduction + values(1) * fraction;
                    hhiReserve = hhiReserve + values(2) * fraction;
                end
            catch
                % pymatgen deliberately converts invalid/unsupported
                % compositions into (None, None).
                hhiProduction = [];
                hhiReserve = [];
            end
        end

        function out = get_hhi_production(obj, compOrForm)
            [out, ~] = obj.get_hhi(compOrForm);
        end

        function out = get_hhi_reserve(obj, compOrForm)
            [~, out] = obj.get_hhi(compOrForm);
        end
    end

    methods (Static)
        function designation = get_hhi_designation(hhi)
            if isempty(hhi)
                designation = [];
            elseif hhi >= 0 && hhi < 1500
                designation = "low";
            elseif hhi >= 1500 && hhi <= 2500
                designation = "medium";
            else
                designation = "high";
            end
        end
    end

    methods (Access = private)
        function out = get_hhi_el(obj, element)
            if isa(element, "kssolv.analysis.matgenlab.core.Element")
                symbol = char(element.symbol);
            else
                symbol = char(string(element));
            end
            out = obj.symbol_hhip_hhir(symbol);
        end
    end
end
