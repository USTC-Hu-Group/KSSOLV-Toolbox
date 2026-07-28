function value=map_get(map,key,default)
%MAP_GET Read JSON-decoded keys, including MATLAB-prefixed numeric names.
if nargin<3,default=[];end
key=char(string(key));
valid=matlab.lang.makeValidName(key);
if isstruct(map)&&isfield(map,key)
    value=map.(key);
elseif isstruct(map)&&isfield(map,valid)
    value=map.(valid);
elseif isa(map,"containers.Map")&&isKey(map,key)
    value=map(key);
else
    value=default;
end
end
