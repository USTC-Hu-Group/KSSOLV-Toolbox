%#ok<*NASGU>
function set_info(additionalInfo,field,isite,cnMap,value)
%SET_INFO Store weight diagnostics in a mutable containers.Map.
if isempty(additionalInfo)||~isa(additionalInfo,"containers.Map"),return,end
key=sprintf('%d:%d:%d',isite,cnMap(1),cnMap(2));
if ~isKey(additionalInfo,char(field))
    additionalInfo(char(field))=containers.Map("KeyType","char", ...
        "ValueType","any");
end
map=additionalInfo(char(field));map(key)=value;
end
