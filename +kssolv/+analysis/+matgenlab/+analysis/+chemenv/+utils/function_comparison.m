function value=function_comparison(first,second,x1,x2,varargin)
%FUNCTION_COMPARISON Compare two non-crossing functions on an interval.
count=500;
if ~isempty(varargin)
    if (ischar(varargin{1})||isstring(varargin{1})),count=varargin{2};
    else,count=varargin{1};end
end
inputs=linspace(x1,x2,count);one=first(inputs);two=second(inputs);
if all(one<two),value="<";
elseif all(one>two),value=">";
elseif all(one==two),value="=";
elseif all(one<=two),value="<=";
elseif all(one>=two),value=">=";
else
    error("KSSOLV:Matgenlab:ChemEnv:FunctionComparison", ...
        "The compared functions cross on the interval.");
end
end
