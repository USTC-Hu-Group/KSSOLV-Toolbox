function value=power2_inverse_powern_decreasing(input,varargin)
%POWER2_INVERSE_POWERN_DECREASING Inverse-power quadratic decrease.
[edges,prefactor,powern]=options(varargin);
if ~isempty(edges)
    input=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
        scale_and_clamp(input,edges(1),edges(2),0,1);
end
if isempty(prefactor),prefactor=1;end
value=prefactor*(input-1).^2./input.^powern;
end
function [edges,prefactor,powern]=options(args)
edges=[];prefactor=[];powern=2;
if ~isempty(args)&&(ischar(args{1})||isstring(args{1}))
    for index=1:2:numel(args)
        switch lower(string(args{index}))
            case "edges",edges=args{index+1};
            case "prefactor",prefactor=args{index+1};
            case "powern",powern=args{index+1};
        end
    end
else
    if ~isempty(args),edges=args{1};end
    if numel(args)>1,prefactor=args{2};end
    if numel(args)>2,powern=args{3};end
end
end
