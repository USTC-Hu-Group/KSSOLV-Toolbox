classdef Keyword < handle
 properties,name string;values cell={};description=[];units=[];verbose=false;repeats=false;end
 methods
  function obj=Keyword(name,varargin)
   if nargin==0,return,end;obj.name=string(name);cut=numel(varargin)+1;
   known=["description","units","verbose","repeats"];for i=1:numel(varargin),if ischar(varargin{i})||isstring(varargin{i}),if ismember(lower(string(varargin{i})),known)&&mod(numel(varargin)-i+1,2)==0,cut=i;break,end,end,end
   obj.values=varargin(1:cut-1);for i=cut:2:numel(varargin),obj.(char(lower(string(varargin{i}))))=varargin{i+1};end
  end
  function value=get_str(obj),parts=obj.name;if ~isempty(obj.units),parts=parts+" ["+string(obj.units)+"]";end;for i=1:numel(obj.values),v=obj.values{i};if isempty(v),continue,end;if islogical(v),s=upper(string(v));elseif isnumeric(v)&&~isscalar(v),s=join(string(v)," ");else,s=string(v);end;if any(ismissing(s)),continue,end;parts=parts+" "+s;end;if obj.verbose&&~isempty(obj.description),parts=parts+" ! "+string(obj.description);end;value=char(parts);end
  function value=char(obj),value=obj.get_str();end
  function value=string(obj),value=string(obj.get_str());end
  function value=eq(a,b),value=isa(b,class(a))&&upper(a.name)==upper(b.name)&&isequal(normalize(a.values),normalize(b.values))&&isequal(a.units,b.units);end
  function value=as_dict(obj),value=struct("x_module","pymatgen.io.cp2k.inputs","x_class","Keyword","name",obj.name,"values",{obj.values},"description",obj.description,"repeats",obj.repeats,"units",obj.units,"verbose",obj.verbose);end
  function value=verbosity(obj,v),obj.verbose=v;value=obj;end
 end
 methods(Static)
  function obj=from_dict(d),obj=kssolv.analysis.matgenlab.io.cp2k.Keyword(d.name,d.values{:},"description",d.description,"repeats",d.repeats,"units",d.units,"verbose",d.verbose);end
  function obj=from_str(s,description)
   if nargin<2,description=[];end;unit=regexp(char(s),'\[(.*?)\]','tokens','once');s=regexprep(string(s),'\[.*?\]','');a=split(strtrim(s));vals=cell(1,numel(a)-1);for i=2:numel(a),vals{i-1}=kssolv.analysis.matgenlab.io.cp2k.postprocessor(a(i));end
   args=vals;if ~isempty(unit),args=[args,{"units",unit{1}}];end;args=[args,{"description",description}];obj=kssolv.analysis.matgenlab.io.cp2k.Keyword(a(1),args{:});
  end
 end
end
function out=normalize(x),out=x;for i=1:numel(out),if ischar(out{i})||isstring(out{i}),out{i}=upper(string(out{i}));end,end,end
