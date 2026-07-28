function [value,found]=map_value(map,key)
%MAP_VALUE Read containers.Map or struct with a species key.
key=char(string(key));found=false;value=[];
if isa(map,"containers.Map")
    if isKey(map,key),value=map(key);found=true;end
elseif isstruct(map)
    field=matlab.lang.makeValidName(key);
    if isfield(map,field),value=map.(field);found=true;end
elseif iscell(map)&&size(map,2)==2
    index=find(string(map(:,1))==string(key),1);
    if ~isempty(index),value=map{index,2};found=true;end
end
end
