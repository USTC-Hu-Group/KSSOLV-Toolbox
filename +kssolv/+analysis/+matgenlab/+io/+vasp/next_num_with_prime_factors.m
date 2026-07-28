function value = next_num_with_prime_factors(n, max_prime_factor, must_inc_2)
%NEXT_NUM_WITH_PRIME_FACTORS First integer >= n with allowed prime factors.
if nargin < 3, must_inc_2 = true; end
if max_prime_factor < 2
    error("KSSOLV:Matgenlab:VaspInputSet:PrimeFactor", ...
        "Must choose a maximum prime factor greater than 2.");
end
allowed = kssolv.analysis.matgenlab.io.vasp. ...
    primes_less_than(max_prime_factor);
value = ceil(n);
while true
    if ~must_inc_2 || mod(value, 2) == 0
        remainder = value;
        for factor = allowed
            while mod(remainder, factor) == 0
                remainder = remainder / factor;
            end
        end
        if remainder == 1, return; end
    end
    value = value + 1;
end
end
