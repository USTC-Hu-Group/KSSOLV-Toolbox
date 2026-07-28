function values = primes_less_than(max_val)
%PRIMES_LESS_THAN Prime numbers less than or equal to max_val.
validateattributes(max_val, {'numeric'}, ...
    {'scalar','integer','nonnegative'});
if max_val < 2, values = zeros(1, 0); else, values = primes(max_val); end
end
