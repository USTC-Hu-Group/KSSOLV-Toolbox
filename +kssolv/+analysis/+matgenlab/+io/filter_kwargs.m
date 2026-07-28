function filtered=filter_kwargs(functionHandle,keywordArguments,varargin)
%FILTER_KWARGS Retain keyword fields accepted by a MATLAB function handle.
if ~isa(functionHandle,"function_handle")||~isstruct(keywordArguments)
    error("KSSOLV:Matgenlab:Registry:FilterArguments", ...
        "Expected a function handle and scalar keyword struct.");
end
if nargin(functionHandle)<0
    filtered=keywordArguments;return
end
metadata=functions(functionHandle);signature=string(metadata.function);
tokens=regexp(signature,"^@\(([^)]*)\)","tokens","once");
if isempty(tokens)
    filtered=keywordArguments;
    return
end
accepted=strtrim(split(string(tokens{1}),","));
names=fieldnames(keywordArguments);filtered=struct();
dropped=strings(1,0);
for index=1:numel(names)
    if any(string(names{index})==accepted)
        filtered.(names{index})=keywordArguments.(names{index});
    else
        dropped(end+1)=string(names{index}); %#ok<AGROW>
    end
end
if ~isempty(dropped)
    warning("KSSOLV:Matgenlab:Registry:UnsupportedKeywords", ...
        "Unsupported keyword arguments ignored: %s.",join(dropped,", "));
end
if ~isempty(varargin)
    % stacklevel has no MATLAB analogue and is accepted for API parity.
end
end
