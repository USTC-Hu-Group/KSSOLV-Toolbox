function value=gramschmidt(vin,uin)
%GRAMSCHMIDT Component of vin orthogonal to uin.
denominator=dot(uin,uin);
if denominator<=0
    error("KSSOLV:Matgenlab:LocalEnv:GramSchmidt", ...
        "Zero or negative inner product.");
end
value=vin-dot(vin,uin)/denominator*uin;
end
