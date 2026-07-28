function value=quarter_ellipsis_functions(first,second)
%QUARTER_ELLIPSIS_FUNCTIONS Lower and upper quarter-ellipse handles.
first=reshape(double(first),1,[]);second=reshape(double(second),1,[]);
if any(first==second)
    error("KSSOLV:Matgenlab:ChemEnv:Ellipse","Invalid ellipse points.");
end
if first(1)<second(1),p1=first;p2=second;else,p1=second;p2=first;end
if all(first<second)||all(first>second)
    lowerCenter=[p1(1),p2(2)];upperCenter=[p2(1),p1(2)];
    b2=(p2(2)-p1(2))^2;
else
    lowerCenter=[p2(1),p1(2)];upperCenter=[p1(1),p2(2)];
    b2=(p1(2)-p2(2))^2;
end
ratio=b2/(p2(1)-p1(1))^2;
value=struct(lower=@lower,upper=@upper);
    function output=lower(input)
        output=lowerCenter(2)-sqrt(b2-ratio*(input-lowerCenter(1)).^2);
    end
    function output=upper(input)
        output=upperCenter(2)+sqrt(b2-ratio*(input-upperCenter(1)).^2);
    end
end
