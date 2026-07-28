function [functional,basisSet,parameters,diezeTag]=read_route_line(route)
%READ_ROUTE_LINE Parse a Gaussian route card.
route=strtrim(string(route));
functional=missing;basisSet=missing;diezeTag=missing;
parameters=containers.Map("KeyType","char","ValueType","any");
if strlength(route)==0,return,end
method=regexp(char(route),'(?:^|\s)([^\s#/]+)/([^\s]+)', ...
    'tokens','once');
if ~isempty(method)
    functional=string(method{1});basisSet=string(method{2});
    route=regexprep(route,'(?:^|\s)[^\s#/]+/[^\s]+',' ');
end
tokens=regexp(char(route),'\S+(?:\([^)]*\))?','match');
for index=1:numel(tokens)
    token=string(tokens{index});
    if any(upper(token)==["#","#N","#P","#T"])
        if token=="#",diezeTag="#N";else,diezeTag=token;end
        continue
    end
    token=strip(token,"left","#");
    nested=regexp(char(token), ...
        '^([A-Za-z]+[0-9-]*)[\s=]+\((.*)\)$','tokens','once');
    if ~isempty(nested)
        inner=containers.Map("KeyType","char","ValueType","any");
        entries=split(string(nested{2}),",");
        for entry=reshape(entries,1,[])
            pair=split(entry,"=");
            key=char(strtrim(pair(1)));
            if isscalar(pair),inner(key)=[];
            else,inner(key)=char(strtrim(join(pair(2:end),"=")));end
        end
        parameters(nested{1})=inner;
        continue
    end
    pair=split(token,"=");
    key=char(strtrim(pair(1)));
    if strlength(string(key))==0,continue,end
    if isscalar(pair)
        parameters(key)=[];
    else
        parameters(key)=char(strtrim(join(pair(2:end),"=")));
    end
end
end
