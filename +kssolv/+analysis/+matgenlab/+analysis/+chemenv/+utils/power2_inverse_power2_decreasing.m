function value=power2_inverse_power2_decreasing(input,varargin)
%POWER2_INVERSE_POWER2_DECREASING Inverse-square quadratic decrease.
[edges,prefactor]=options(varargin);
if ~isempty(edges)
    input=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
        scale_and_clamp(input,edges(1),edges(2),0,1);
end
if isempty(prefactor),prefactor=1;end
value=prefactor*(input-1).^2./input.^2;value(abs(input)<1e-12)=inf;
end
function [edges,prefactor]=options(args)
edges=[];prefactor=[];
if ~isempty(args)&&(ischar(args{1})||isstring(args{1}))
    for index=1:2:numel(args)
        if strcmpi(string(args{index}),"edges"),edges=args{index+1};
        elseif strcmpi(string(args{index}),"prefactor"),prefactor=args{index+1};end
    end
else
    if ~isempty(args),edges=args{1};end
    if numel(args)>1,prefactor=args{2};end
end
end
