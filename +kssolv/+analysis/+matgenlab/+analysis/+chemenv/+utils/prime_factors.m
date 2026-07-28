function value=prime_factors(n)
%PRIME_FACTORS Prime factors from greatest recursive factor to smallest.
n=double(n);factor=2;
while factor<=sqrt(n)
    if mod(n,factor)==0
        value=[kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
            prime_factors(n/factor),factor];
        return
    end
    factor=factor+1;
end
value=n;
end
