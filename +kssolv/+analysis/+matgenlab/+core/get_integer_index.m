function miller = get_integer_index(miller_index, round_dp, verbose)
%GET_INTEGER_INDEX Convert proportional floating indices to small integers.
if nargin < 2, round_dp = 4; end
if nargin < 3, verbose = true; end
values = reshape(double(miller_index), 1, []);
nonzero = values(abs(values) > eps);
if isempty(nonzero), miller = zeros(size(values)); return; end
values = values / min(nonzero);
values = values / max(abs(values));
denominators = ones(size(values));
for index = 1:numel(values)
    bestError = Inf;
    for denominator = 1:12
        numerator = round(values(index) * denominator);
        currentError = abs(values(index) - numerator / denominator);
        if currentError < bestError
            bestError = currentError;
            denominators(index) = denominator;
        end
    end
end
values = values * prod(denominators);
integerValues = round(values, 1);
divisor = 0;
for value = abs(round(integerValues))
    divisor = gcd(divisor, value);
end
if divisor > 0, values = values / divisor; end
values = round(values, round_dp);
integerValues = round(values);
if any(abs(values - integerValues) > 1e-6)
    if verbose
        warning("KSSOLV:Matgenlab:Lattice:NonIntegerMillerIndex", ...
            "Non-integer encountered in Miller index.");
    end
    miller = values;
else
    miller = integerValues;
end
miller(miller == 0) = 0;
if nnz(miller < 0) > nnz(-miller < 0), miller = -miller; end
if nnz(miller) == 2 && nnz(miller < 0) == 1 && ...
        abs(min(miller)) > max(miller)
    miller = -miller;
end
end
