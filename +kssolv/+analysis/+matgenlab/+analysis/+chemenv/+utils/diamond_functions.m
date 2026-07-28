function value=diamond_functions(first,second,yX0,xY0)
%DIAMOND_FUNCTIONS Lower and upper boundary handles of a distorted diamond.
first=reshape(double(first),1,[]);second=reshape(double(second),1,[]);
if any(first==second)
    error("KSSOLV:Matgenlab:ChemEnv:Diamond","Invalid diamond points.");
end
if first(1)<second(1),p1=first;p2=second;else,p1=second;p2=first;end
slope=(p2(2)-p1(2))/(p2(1)-p1(1));
xB=p1(1)+xY0;bq=p1(2)-slope*xB;
if slope>0
    ap=p1(2)+yX0-slope*p1(1);xP=(p2(2)-ap)/slope;
    lower=@(input)where(input<=xB,p1(2),slope*input+bq);
    upper=@(input)where(input>=xP,p2(2),slope*input+ap);
else
    ap=p1(2)-yX0-slope*p1(1);xP=(p2(2)-ap)/slope;
    lower=@(input)where(input>=xP,p2(2),slope*input+ap);
    upper=@(input)where(input<=xB,p1(2),slope*input+bq);
end
value=struct(lower=lower,upper=upper);
end
function output=where(mask,constant,alternative)
output=alternative;output(mask)=constant;
end
