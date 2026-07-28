function value=powern_parts_step(input,varargin)
%POWERN_PARTS_STEP Piecewise polynomial smooth step.
%#ok<*ALIGN>
[edges,inverse,degree]=options(varargin);
if ~isempty(edges)
    input=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
        scale_and_clamp(input,edges(1),edges(2),0,1);
else,input=min(max(input,0),1);end
factor=.5^(1-degree);value=zeros(size(input));lower=input<.5;
value(lower)=factor*input(lower).^degree;
if mod(degree,2)==0
    value(~lower)=1-factor*(input(~lower)-1).^degree;
else
    value(~lower)=1+factor*(input(~lower)-1).^degree;
end
if inverse,value=1-value;end
end
function [edges,inverse,degree]=options(args)
edges=[];inverse=false;degree=2;
if ~isempty(args)&&(ischar(args{1})||isstring(args{1}))
    for index=1:2:numel(args)
        switch lower(string(args{index}))
            case "edges",edges=args{index+1};
            case "inverse",inverse=logical(args{index+1});
            case "nn",degree=args{index+1};
        end
    end
else
    if ~isempty(args),edges=args{1};end
    if numel(args)>1,inverse=logical(args{2});end
    if numel(args)>2,degree=args{3};end
end
end
