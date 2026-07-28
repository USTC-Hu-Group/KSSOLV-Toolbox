classdef Section < handle
%#ok<*AGROW,*ISCL>
 properties,name string;subsections struct=struct();repeats=false;description=[];keywords struct=struct();section_parameters string=strings(0,1);location=[];verbose=false;alias=[];end
 methods
  function obj=Section(name,varargin)
   if nargin==0,return,end;obj.name=string(name);opts=struct("subsections",struct(),"repeats",false,"description",[],"keywords",struct(),"section_parameters",strings(0,1),"location",[],"verbose",false,"alias",[]);
   for i=1:2:numel(varargin),key=char(lower(string(varargin{i})));if isfield(opts,key),opts.(key)=varargin{i+1};else,opts.keywords.(char(string(varargin{i})))=kssolv.analysis.matgenlab.io.cp2k.Keyword(varargin{i},varargin{i+1});end,end
   n=fieldnames(opts);for i=1:numel(n),obj.(n{i})=opts.(n{i});end
  end
  function out=setitem(obj,key,value,strict),if nargin<4,strict=false;end;if isa(value,"kssolv.analysis.matgenlab.io.cp2k.Section")||isa(value,"kssolv.analysis.matgenlab.io.cp2k.SectionList"),if ~strict||~isempty(obj.get_section(key)),obj.subsections.(matlab.lang.makeValidName(string(key)))=value;end;else,if ~isa(value,"kssolv.analysis.matgenlab.io.cp2k.Keyword")&&~isa(value,"kssolv.analysis.matgenlab.io.cp2k.KeywordList"),value=kssolv.analysis.matgenlab.io.cp2k.Keyword(key,value);end;if ~strict||~isempty(obj.get_keyword(key)),obj.keywords.(matlab.lang.makeValidName(string(key)))=value;end,end;out=obj;end
  function value=add(obj,other),if isa(other,"kssolv.analysis.matgenlab.io.cp2k.Keyword"),old=obj.get_keyword(other.name);if isempty(old),obj.setitem(other.name,other);elseif isa(old,"kssolv.analysis.matgenlab.io.cp2k.KeywordList"),old.append(other);else,obj.setitem(other.name,kssolv.analysis.matgenlab.io.cp2k.KeywordList({old,other}));end;else,obj.insert(other);end;value=obj;end
  function value=get(obj,d,default),if nargin<3,default=[];end;value=obj.get_keyword(d);if isempty(value),value=obj.get_section(d);end;if isempty(value),value=default;end,end
  function value=get_section(obj,d,default),if nargin<3,default=[];end;value=ciGet(obj.subsections,d,default);end
  function value=get_keyword(obj,d,default),if nargin<3,default=[];end;value=ciGet(obj.keywords,d,default);end
  function value=update(obj,dct,strict),if nargin<3,strict=false;end;n=fieldnames(dct);for i=1:numel(n),k=n{i};v=dct.(k);if isstruct(v),sec=obj.get_section(k);if isempty(sec),if strict,continue,end;sec=kssolv.analysis.matgenlab.io.cp2k.Section(k);obj.insert(sec);end;sec.update(v,strict);elseif isa(v,"kssolv.analysis.matgenlab.io.cp2k.Section"),obj.insert(v);else,obj.setitem(k,v,strict);end,end;value=obj;end
  function value=set(obj,d),obj.update(d);value=obj;end
  function value=safeset(obj,d),obj.update(d,true);value=obj;end
  function value=unset(obj,d),n=fieldnames(d);for i=1:numel(n),sec=obj.get_section(n{i});if isstruct(d.(n{i}))&&~isempty(sec),sec.unset(d.(n{i}));else,obj.removeName(n{i},d.(n{i}));end,end;value=obj;end
  function value=inc(obj,d),n=fieldnames(d);for i=1:numel(n),v=d.(n{i});if isstruct(v),sec=obj.get_section(n{i});if isempty(sec),sec=kssolv.analysis.matgenlab.io.cp2k.Section(n{i});obj.insert(sec);end;sec.inc(v);else,obj.add(kssolv.analysis.matgenlab.io.cp2k.Keyword(n{i},v));end,end;value=obj;end
  function value=insert(obj,d),key=string(d.name);if ~isempty(d.alias),key=string(d.alias);end;obj.subsections.(matlab.lang.makeValidName(key))=d;value=obj;end
  function value=check(obj,path),parts=split(string(path),"/");cur=obj;value=true;for p=reshape(parts,1,[]),if strlength(p)==0||upper(p)==upper(cur.name),continue,end;cur=cur.get_section(p);if isempty(cur),value=false;return,end;if isa(cur,"kssolv.analysis.matgenlab.io.cp2k.SectionList"),cur=cur.sections{end};end,end,end
  function value=by_path(obj,path),parts=split(string(path),"/");value=obj;for p=reshape(parts,1,[]),if strlength(p)==0||upper(p)==upper(value.name),continue,end;value=value.get_section(p);end,end
  function value=get_str(obj),value=obj.render(0);end
  function value=render(obj,indent),tabs=repmat(sprintf('\t'),1,indent);line=tabs+"&"+obj.name;if ~isempty(obj.section_parameters),line=line+" "+join(string(obj.section_parameters)," ");end;lines=line;n=fieldnames(obj.keywords);for i=1:numel(n),kw=obj.keywords.(n{i});if isa(kw,"kssolv.analysis.matgenlab.io.cp2k.KeywordList"),lines(end+1)=string(kw.get_str(indent+1));else,lines(end+1)=repmat(sprintf('\t'),1,indent+1)+string(kw.get_str());end,end;n=fieldnames(obj.subsections);for i=1:numel(n),s=obj.subsections.(n{i});if isa(s,"kssolv.analysis.matgenlab.io.cp2k.SectionList"),for j=1:numel(s.sections),lines(end+1)=string(s.sections{j}.render(indent+1));end;else,lines(end+1)=string(s.render(indent+1));end,end;lines(end+1)=tabs+"&END "+obj.name;value=char(join(lines,newline)+newline);end
  function value=verbosity(obj,v),obj.verbose=v;n=fieldnames(obj.keywords);for i=1:numel(n),obj.keywords.(n{i}).verbosity(v);end;n=fieldnames(obj.subsections);for i=1:numel(n),obj.subsections.(n{i}).verbosity(v);end;value=obj;end
  function value=silence(obj),n=fieldnames(obj.subsections);for i=1:numel(n),if upper(string(n{i}))=="PRINT",obj.subsections=rmfield(obj.subsections,n{i});else,obj.subsections.(n{i}).silence();end,end;value=obj;end
  function value=char(obj),value=obj.get_str();end
  function value=string(obj),value=string(obj.get_str());end
  function value=as_dict(obj),value=struct("x_module","pymatgen.io.cp2k.inputs","x_class",classShort(obj),"name",obj.name,"subsections",encodeMap(obj.subsections),"keywords",encodeMap(obj.keywords),"repeats",obj.repeats,"description",obj.description,"section_parameters",obj.section_parameters,"location",obj.location,"verbose",obj.verbose,"alias",obj.alias);end
  function value=subsref(obj,s),if strcmp(s(1).type,"()")&&numel(s(1).subs)==1,value=obj.get(s(1).subs{1});if isempty(value),error("KSSOLV:Matgenlab:Cp2k:Key","Missing key.");end;if numel(s)>1,value=builtin("subsref",value,s(2:end));end;else,value=builtin("subsref",obj,s);end,end
 end
 methods(Access=private)
  function removeName(obj,name,~),f=fieldnames(obj.keywords);idx=find(strcmpi(f,name),1);if ~isempty(idx),obj.keywords=rmfield(obj.keywords,f{idx});return,end;f=fieldnames(obj.subsections);idx=find(strcmpi(f,name),1);if ~isempty(idx),obj.subsections=rmfield(obj.subsections,f{idx});end,end
 end
 methods(Static)
  function obj=from_dict(d)
   if isfield(d,"x_class")&&string(d.x_class)=="Cp2kInput",obj=kssolv.analysis.matgenlab.io.cp2k.Cp2kInput(d.name,struct());else,obj=kssolv.analysis.matgenlab.io.cp2k.Section(d.name);end
   copy=["repeats","description","section_parameters","location","verbose","alias"];for n=copy,if isfield(d,n),obj.(char(n))=d.(char(n));end,end
   if isfield(d,"keywords"),names=fieldnames(d.keywords);for i=1:numel(names),item=d.keywords.(names{i});obj.keywords.(names{i})=decodeItem(item);end,end
   if isfield(d,"subsections"),names=fieldnames(d.subsections);for i=1:numel(names),item=d.subsections.(names{i});obj.subsections.(names{i})=decodeItem(item);end,end
  end
 end
end
function v=ciGet(s,n,d),f=fieldnames(s);i=find(strcmpi(f,char(string(n))),1);if isempty(i),v=d;else,v=s.(f{i});end,end
function n=classShort(o),p=split(string(class(o)),".");n=p(end);end
function out=encodeMap(s),out=struct();n=fieldnames(s);for i=1:numel(n),if ismethod(s.(n{i}),"as_dict"),out.(n{i})=s.(n{i}).as_dict();else,out.(n{i})=s.(n{i});end,end,end
function value=decodeItem(item),if ~isstruct(item)||~isfield(item,"x_class"),value=item;return,end;switch string(item.x_class),case "Keyword",value=kssolv.analysis.matgenlab.io.cp2k.Keyword.from_dict(item);case "KeywordList",value=kssolv.analysis.matgenlab.io.cp2k.KeywordList.from_dict(item);case "SectionList",value=kssolv.analysis.matgenlab.io.cp2k.SectionList.from_dict(item);otherwise,value=kssolv.analysis.matgenlab.io.cp2k.Section.from_dict(item);end,end
