function value=smoothstep(input,varargin)
%SMOOTHSTEP Cubic smooth step.
%#ok<*ALIGN>
[edges,inverse]=stepOptions(varargin);
if ~isempty(edges)
    input=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
        scale_and_clamp(input,edges(1),edges(2),0,1);
else,input=min(max(input,0),1);end
value=input.^2.*(3-2*input);
if inverse,value=1-value;end
end
function [edges,inverse]=stepOptions(args)
edges=[];inverse=false;
if ~isempty(args)&&(ischar(args{1})||isstring(args{1}))
    for index=1:2:numel(args)
        switch lower(string(args{index}))
            case "edges",edges=args{index+1};
            case "inverse",inverse=logical(args{index+1});
        end
    end
else
    if ~isempty(args),edges=args{1};end
    if numel(args)>1,inverse=logical(args{2});end
end
end
