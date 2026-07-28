function output = contract(input)
%CONTRACT Run-length encode an ABINIT whitespace-separated value string.
tokens = split(strip(string(input))); tokens(tokens=="")=[];
if isempty(tokens), output=char(string(input)); return; end
parts={}; count=1;
for index=2:numel(tokens)
    if tokens(index)==tokens(index-1), count=count+1;
    else, parts{end+1}=sprintf("%d*%s",count,tokens(index-1)); count=1; end %#ok<AGROW>
end
parts{end+1}=sprintf("%d*%s",count,tokens(end));
output=char(join(string(parts),' '));
end
