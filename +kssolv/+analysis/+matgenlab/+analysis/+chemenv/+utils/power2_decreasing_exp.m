function value=power2_decreasing_exp(input,varargin)
%POWER2_DECREASING_EXP Exponentially damped quadratic decrease.
[edges,alpha]=options(varargin,1,"alpha");
if ~isempty(edges)
    input=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
        scale_and_clamp(input,edges(1),edges(2),0,1);
end
value=(input-1).^2.*exp(-alpha*input);
end
function [edges,parameter]=options(args,default,name)
edges=[];parameter=default;
if ~isempty(args)&&(ischar(args{1})||isstring(args{1}))
    for index=1:2:numel(args)
        if strcmpi(string(args{index}),"edges"),edges=args{index+1};
        elseif strcmpi(string(args{index}),name),parameter=args{index+1};end
    end
else
    if ~isempty(args),edges=args{1};end
    if numel(args)>1,parameter=args{2};end
end
end
