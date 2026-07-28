function value=divisors(n)
%DIVISORS Positive divisors in ascending order.
n=double(n);
if n<1||n~=fix(n)
    error("KSSOLV:Matgenlab:ChemEnv:Integer","n must be a positive integer.");
end
value=find(mod(n,1:n)==0);
end
