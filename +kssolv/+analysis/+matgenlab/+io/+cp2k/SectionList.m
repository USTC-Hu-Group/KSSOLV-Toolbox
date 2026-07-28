classdef SectionList < handle
 properties,name=[];alias=[];sections cell={};end
 methods
  function obj=SectionList(sections),if nargin<1,return,end;if ~iscell(sections),sections=num2cell(sections);end;obj.sections=sections;if ~isempty(sections),obj.name=sections{1}.name;obj.alias=sections{1}.alias;end,end
  function value=get_str(obj),parts=cellfun(@(s)string(s.get_str()),obj.sections,"UniformOutput",false);value=char(join(parts," "+newline));end
  function value=get(obj,d,index),if nargin<3,index=numel(obj.sections);end;value=obj.sections{index}.get(d);end
  function value=append(obj,item),obj.sections{end+1}=item;value=obj;end
  function value=extend(obj,lst),if ~iscell(lst),lst=num2cell(lst);end;obj.sections=[obj.sections,lst];value=obj;end
  function value=verbosity(obj,v),cellfun(@(s)s.verbosity(v),obj.sections);value=obj;end
  function value=silence(obj),cellfun(@(s)s.silence(),obj.sections);value=obj;end
  function value=length(obj),value=numel(obj.sections);end
  function value=as_dict(obj),items=cellfun(@(s)s.as_dict(),obj.sections,"UniformOutput",false);value=struct("x_module","pymatgen.io.cp2k.inputs","x_class","SectionList","sections",{items});end
  function value=subsref(obj,s),if strcmp(s(1).type,"()"),value=obj.sections{s(1).subs{1}};if numel(s)>1,value=builtin("subsref",value,s(2:end));end;else,value=builtin("subsref",obj,s);end,end
 end
 methods(Static)
  function obj=from_dict(d),items=d.sections;if ~iscell(items),items=num2cell(items);end;for i=1:numel(items),if isstruct(items{i}),items{i}=kssolv.analysis.matgenlab.io.cp2k.Section.from_dict(items{i});end,end;obj=kssolv.analysis.matgenlab.io.cp2k.SectionList(items);end
 end
end
