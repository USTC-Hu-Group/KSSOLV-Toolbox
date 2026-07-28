classdef PotentialInfo < handle
 properties,electrons=[];potential_type=[];nlcc=[];xc=[];end
 methods
  function obj=PotentialInfo(varargin),for i=1:2:numel(varargin),obj.(char(varargin{i}))=varargin{i+1};end,end
  function value=softmatch(obj,other),value=isa(other,class(obj));n=properties(obj);for i=1:numel(n),v=obj.(n{i});if ~isempty(v)&&~isequal(v,other.(n{i})),value=false;return,end,end,end
  function value=as_dict(obj),value=struct("electrons",obj.electrons,"potential_type",obj.potential_type,"nlcc",obj.nlcc,"xc",obj.xc);end
 end
 methods(Static)
  function obj=from_str(text),s=upper(string(text));obj=kssolv.analysis.matgenlab.io.cp2k.PotentialInfo();if contains(s,"GTH"),obj.potential_type="GTH";end;obj.nlcc=contains(s,"NLCC");q=regexp(s,'Q(\d+)','tokens','once');if ~isempty(q),obj.electrons=str2double(q{1});end;for x=["SCAN","B3LYP","BLYP","PBE0","PBE","GGA","MGGA","LDA","HF"],if contains(s,x),obj.xc=x;break,end,end,end
  function obj=from_dict(d),obj=kssolv.analysis.matgenlab.io.cp2k.PotentialInfo();n=fieldnames(d);for i=1:numel(n),if isprop(obj,n{i}),obj.(n{i})=d.(n{i});end,end,end
 end
end
