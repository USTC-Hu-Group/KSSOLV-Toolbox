classdef KeywordList < handle
 properties,name=[];keywords cell={};end
 methods
  function obj=KeywordList(keywords),if nargin<1,return,end;if ~iscell(keywords),keywords=num2cell(keywords);end;obj.keywords=keywords;if ~isempty(keywords),obj.name=keywords{1}.name;assert(all(cellfun(@(k)upper(k.name)==upper(obj.name),keywords)),"Keyword names must match.");end,end
  function value=append(obj,item),obj.keywords{end+1}=item;value=obj;end
  function value=extend(obj,lst),if isa(lst,"kssolv.analysis.matgenlab.io.cp2k.Keyword"),lst={lst};elseif ~iscell(lst),lst=num2cell(lst);end;obj.keywords=[obj.keywords,lst];value=obj;end
  function value=length(obj),value=numel(obj.keywords);end
  function value=get_str(obj,indent),if nargin<2,indent=0;end;parts=cellfun(@(k)string(repmat(sprintf('\t'),1,indent))+string(k.get_str()),obj.keywords,"UniformOutput",false);value=char(join(string([parts{:}]),newline));end
  function value=char(obj),value=obj.get_str();end
  function value=verbosity(obj,v),cellfun(@(k)k.verbosity(v),obj.keywords);value=obj;end
  function value=as_dict(obj),items=cellfun(@(k)k.as_dict(),obj.keywords,"UniformOutput",false);value=struct("x_module","pymatgen.io.cp2k.inputs","x_class","KeywordList","keywords",{items});end
  function value=subsref(obj,s),if strcmp(s(1).type,"()")&&isnumeric(s(1).subs{1}),value=obj.keywords{s(1).subs{1}};if numel(s)>1,value=builtin("subsref",value,s(2:end));end;else,value=builtin("subsref",obj,s);end,end
 end
 methods(Static)
  function obj=from_dict(d),items=d.keywords;if ~iscell(items),items=num2cell(items);end;for i=1:numel(items),if isstruct(items{i}),items{i}=kssolv.analysis.matgenlab.io.cp2k.Keyword.from_dict(items{i});end,end;obj=kssolv.analysis.matgenlab.io.cp2k.KeywordList(items);end
 end
end
