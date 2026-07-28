function hkl=hkl_transformation(transformation,hkl)
%HKL_TRANSFORMATION Transform and reduce an hkl index between settings.
values=transformation(abs(transformation)>0);
denominators=zeros(size(values));
for index=1:numel(values)
    [~,denominators(index)]=rat(values(index),1e-10);
end
multiple=1;
for value=reshape(denominators,1,[]),multiple=lcm(multiple,value);end
integerMatrix=round(transformation*multiple);
hkl=integerMatrix*reshape(double(hkl),[],1);
divisor=gcd(gcd(abs(round(hkl(1))),abs(round(hkl(2)))), ...
    abs(round(hkl(3))));
hkl=reshape(round(hkl/divisor),1,3);
if sum(hkl<0)>1,hkl=-hkl;end
end
