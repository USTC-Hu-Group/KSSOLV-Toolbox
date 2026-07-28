function value=map_get(map,key,default)
%MAP_GET Read a symbol-keyed struct or containers.Map.
if nargin<3,default=[];end
key=char(string(key));
if isa(map,"containers.Map")
    if isKey(map,key),value=map(key);else,value=default;end
elseif isstruct(map)&&isfield(map,key)
    value=map.(key);
elseif isstruct(map)&&isfield(map,matlab.lang.makeValidName(key))
    value=map.(matlab.lang.makeValidName(key));
else
    value=default;
end
end
