classdef NumericalEOS < kssolv.analysis.matgenlab.analysis.PolynomialEOS
    methods
        function obj = fit(obj, minDataFactor, maxOrderFactor, minOrder)
            if nargin < 2 || isempty(minDataFactor), minDataFactor = 3; end
            if nargin < 3 || isempty(maxOrderFactor), maxOrderFactor = 5; end
            if nargin < 4 || isempty(minOrder), minOrder = 2; end
            pairs = sortrows([obj.energies(:),obj.volumes(:)], 1);
            minimumPair = pairs(1,:);
            pairs = sortrows(pairs, 2);
            minimumIndex = find(all(pairs == minimumPair,2),1);
            if minimumIndex == 1 || minimumIndex == size(pairs,1)
                throw(kssolv.analysis.matgenlab.analysis.EOSError( ...
                    "Minimum-energy volume must have neighbors."));
            end
            before = pairs(minimumIndex-1,2);
            after = pairs(minimumIndex+1,2);
            count = size(pairs,1);
            minimumCount = max(count-2*minDataFactor,minOrder+1);
            records = {};
            minimumRms = inf;
            working = pairs;
            while size(working,1) >= minimumCount && ...
                    any(all(working == minimumPair,2))
                fitCount = size(working,1);
                maximumOrder = fitCount-maxOrderFactor;
                for order = minOrder:maximumOrder
                    coefficients = polyfit(working(:,2),working(:,1),order);
                    derivative = polyder(coefficients);
                    if polyval(derivative,before)* ...
                            polyval(derivative,after) < 0
                        residual = sqrt(mean((working(:,1)- ...
                            polyval(coefficients,working(:,2))).^2));
                        minimumRms = min(minimumRms, ...
                            residual*order/fitCount);
                        records{end+1} = struct( ...
                            "order",order,"count",fitCount, ...
                            "coefficients",fliplr(coefficients), ...
                            "rms",residual); %#ok<AGROW>
                    end
                end
                working = working(2:end-1,:);
            end
            if isempty(records)
                throw(kssolv.analysis.matgenlab.analysis.EOSError( ...
                    "No acceptable numerical EOS polynomials."));
            end
            weighted = zeros(1,count);
            normalization = 0;
            for index = 1:numel(records)
                record = records{index};
                weightedRms = record.rms*record.order / ...
                    minimumRms/record.count;
                weight = exp(-(weightedRms^2));
                coefficients = [record.coefficients, ...
                    zeros(1,count-numel(record.coefficients))];
                weighted = weighted + weight*coefficients;
                normalization = normalization + weight;
            end
            obj.eos_params = fliplr(weighted/normalization);
            obj = obj.setPolynomialParams();
        end
    end
end
