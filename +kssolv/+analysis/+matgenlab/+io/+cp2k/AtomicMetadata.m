classdef AtomicMetadata < handle
%#ok<*PROP>
 properties,info=[];element=[];potential=[];name=[];alias_names string=strings(0,1);filename=[];version=[];raw string="";end
 methods
  function obj=AtomicMetadata(varargin),for i=1:2:numel(varargin),if isprop(obj,string(varargin{i})),obj.(char(varargin{i}))=varargin{i+1};end,end,end
  function value=softmatch(obj,other),value=isa(other,class(obj))&&(isempty(obj.element)||string(obj.element)==string(other.element))&&(isempty(obj.potential)||string(obj.potential)==string(other.potential));if value&&~isempty(obj.info),value=obj.info.softmatch(other.info);end,end
  function value=get_hash(obj),md=java.security.MessageDigest.getInstance("MD5");md.update(uint8(lower(obj.get_str())));raw=typecast(md.digest(),"uint8");value=lower(string(reshape(dec2hex(raw,2).',1,[])));end
  function value=get_str(obj),value=char(obj.raw);end
  function value=as_dict(obj),value=struct("element",string(obj.element),"potential",obj.potential,"name",obj.name,"alias_names",obj.alias_names,"filename",obj.filename,"version",obj.version,"raw",obj.raw);if ~isempty(obj.info),value.info=obj.info.as_dict();end;end
 end
end
