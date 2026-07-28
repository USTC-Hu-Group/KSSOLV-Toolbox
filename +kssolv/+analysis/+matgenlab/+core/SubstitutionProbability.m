classdef SubstitutionProbability
    %SUBSTITUTIONPROBABILITY Data-mined ionic substitution probabilities.

    properties (SetAccess = protected)
        alpha (1,1) double = -5
        Z (1,1) double = 0
        species cell = cell(1, 0)
    end

    properties (Access = protected)
        lambda_table cell = cell(0, 3)
        lambda_map
        px_map
    end

    methods
        function obj = SubstitutionProbability(lambdaTable, alpha)
            if nargin < 1 || isempty(lambdaTable)
                lambdaTable = kssolv.analysis.matgenlab.core. ...
                    SubstitutionProbability.defaultTable();
            end
            if nargin < 2 || isempty(alpha), alpha = -5; end
            obj.alpha = double(alpha);
            obj.lambda_table = obj.normalizeTable(lambdaTable);
            obj.lambda_map = containers.Map("KeyType", "char", ...
                "ValueType", "double");

            speciesByKey = containers.Map("KeyType", "char", ...
                "ValueType", "any");
            for index = 1:size(obj.lambda_table, 1)
                left = string(obj.lambda_table{index, 1});
                right = string(obj.lambda_table{index, 2});
                if contains(left, "D1+") || contains(right, "D1+")
                    continue
                end
                s1 = kssolv.analysis.matgenlab.core.getElSp(left);
                s2 = kssolv.analysis.matgenlab.core.getElSp(right);
                k1 = obj.speciesKey(s1);
                k2 = obj.speciesKey(s2);
                speciesByKey(char(k1)) = s1;
                speciesByKey(char(k2)) = s2;
                obj.lambda_map(char(obj.pairKey(k1, k2))) = ...
                    double(obj.lambda_table{index, 3});
            end
            names = sort(string(keys(speciesByKey)));
            obj.species = cell(1, numel(names));
            for index = 1:numel(names)
                obj.species{index} = speciesByKey(char(names(index)));
            end

            obj.px_map = containers.Map("KeyType", "char", ...
                "ValueType", "double");
            for index = 1:numel(names), obj.px_map(char(names(index))) = 0; end
            for i = 1:numel(names)
                for j = 1:numel(names)
                    value = exp(obj.lambdaByKey(names(i), names(j)));
                    obj.px_map(char(names(i))) = ...
                        obj.px_map(char(names(i))) + value / 2;
                    obj.px_map(char(names(j))) = ...
                        obj.px_map(char(names(j))) + value / 2;
                    obj.Z = obj.Z + value;
                end
            end
        end

        function value = get_lambda(obj, s1, s2)
            value = obj.lambdaByKey(obj.speciesKey(s1), obj.speciesKey(s2));
        end

        function value = get_px(obj, species)
            key = char(obj.speciesKey(species));
            if isKey(obj.px_map, key), value = obj.px_map(key);
            else, value = 0;
            end
        end

        function value = prob(obj, s1, s2)
            value = exp(obj.get_lambda(s1, s2)) / obj.Z;
        end

        function value = cond_prob(obj, s1, s2)
            denominator = obj.get_px(s2);
            if denominator == 0, value = Inf;
            else, value = exp(obj.get_lambda(s1, s2)) / denominator;
            end
        end

        function value = pair_corr(obj, s1, s2)
            value = exp(obj.get_lambda(s1, s2)) * obj.Z / ...
                (obj.get_px(s1) * obj.get_px(s2));
        end

        function value = cond_prob_list(obj, l1, l2)
            l1 = reshape(obj.toCell(l1), 1, []);
            l2 = reshape(obj.toCell(l2), 1, []);
            if numel(l1) ~= numel(l2)
                error("KSSOLV:Matgenlab:SubstitutionProbability:LengthMismatch", ...
                    "lengths of l1 and l2 mismatch.");
            end
            value = 1;
            for index = 1:numel(l1)
                value = value * obj.cond_prob(l1{index}, l2{index});
            end
        end

        function result = as_dict(obj)
            result = struct( ...
                "name", "SubstitutionProbability", ...
                "version", "1.2", ...
                "init_args", struct( ...
                    "lambda_table", {obj.lambda_table}, ...
                    "alpha", obj.alpha), ...
                "x_module", ...
                    "pymatgen.core.structure_prediction.substitution_probability", ...
                "x_class", "SubstitutionProbability");
        end
    end

    methods (Static)
        function obj = from_dict(dct)
            args = dct.init_args;
            obj = kssolv.analysis.matgenlab.core.SubstitutionProbability( ...
                args.lambda_table, args.alpha);
        end
    end

    methods (Access = protected)
        function value = lambdaByKey(obj, left, right)
            key = char(obj.pairKey(left, right));
            if isKey(obj.lambda_map, key), value = obj.lambda_map(key);
            else, value = obj.alpha;
            end
        end
    end

    methods (Static, Access = protected)
        function table = defaultTable()
            here = fileparts(mfilename("fullpath"));
            path = fullfile(here, "+data", "substitution_lambda.json");
            table = jsondecode(fileread(path));
        end

        function table = normalizeTable(input)
            if iscell(input)
                table = input;
                if isvector(table) && ~isempty(table) && iscell(table{1})
                    rows = table;
                    table = cell(numel(rows), 3);
                    for index = 1:numel(rows)
                        row = reshape(rows{index}, 1, []);
                        if numel(row) ~= 3
                            error("KSSOLV:Matgenlab:SubstitutionProbability:InvalidTable", ...
                                "A lambda table must be an N-by-3 cell array.");
                        end
                        table(index, :) = row;
                    end
                end
            elseif isstruct(input)
                error("KSSOLV:Matgenlab:SubstitutionProbability:InvalidTable", ...
                    "A lambda table must be an N-by-3 cell array.");
            else
                table = num2cell(input);
            end
            if size(table, 2) ~= 3
                error("KSSOLV:Matgenlab:SubstitutionProbability:InvalidTable", ...
                    "A lambda table must be an N-by-3 cell array.");
            end
        end

        function key = speciesKey(value)
            species = kssolv.analysis.matgenlab.core.getElSp(value);
            key = string(species);
        end

        function key = pairKey(left, right)
            names = sort([string(left), string(right)]);
            key = names(1) + "|" + names(2);
        end

        function values = toCell(input)
            if iscell(input), values = input;
            elseif isstring(input), values = cellstr(input);
            else, values = num2cell(input);
            end
        end
    end
end
