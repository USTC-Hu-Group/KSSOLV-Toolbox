classdef GthPotential < kssolv.analysis.matgenlab.io.cp2k.AtomicMetadata
%#ok<*IFBDUP>
 properties,n_elecs=[];r_loc=[];nexp_ppl=[];c_exp_ppl=[];radii=[];nprj=[];nprj_ppnl=[];hprj_ppnl=[];end
 methods
  function obj=GthPotential(varargin),obj@kssolv.analysis.matgenlab.io.cp2k.AtomicMetadata(varargin{:});end
  function value=get_keyword(obj),name=obj.name;if string(obj.potential)=="All Electron",if any(upper(obj.alias_names)=="ALL"),name="ALL";else,name="ALL";end,end;value=kssolv.analysis.matgenlab.io.cp2k.Keyword("POTENTIAL",name);end
  function value=get_section(obj),value=kssolv.analysis.matgenlab.io.cp2k.Section(obj.name);value.setitem("POTENTIAL",obj.get_str());end
  function value=get_str(obj),value=char(obj.raw);end
  function value=eq(a,b),value=isa(b,class(a))&&strtrim(string(a.get_str()))==strtrim(string(b.get_str()))&&isequal(a.filename,b.filename);end
 end
 methods(Static)
  function obj=from_str(text),lines=splitlines(strtrim(string(text)));head=split(strtrim(lines(1)));obj=kssolv.analysis.matgenlab.io.cp2k.GthPotential();obj.element=kssolv.analysis.matgenlab.core.Element(head(1));obj.name=head(2);obj.alias_names=head(3:end);obj.info=kssolv.analysis.matgenlab.io.cp2k.PotentialInfo.from_str(obj.name);obj.raw=string(text);obj.potential="Pseudopotential";if contains(upper(obj.name),"ALL"),obj.potential="All Electron";end;obj.n_elecs=reshape(str2double(split(strtrim(lines(2)))),1,[]);third=reshape(str2double(split(strtrim(lines(3)))),1,[]);obj.r_loc=third(1);obj.nexp_ppl=third(2);obj.c_exp_ppl=third(3:end);if numel(lines)>3,obj.nprj=str2double(strtrim(lines(4)));else,obj.nprj=0;end,end
  function obj=from_section(section),obj=kssolv.analysis.matgenlab.io.cp2k.GthPotential.from_str(section.get_keyword("POTENTIAL").values{1});end
  function obj=from_dict(d),if isfield(d,"raw")&&strlength(string(d.raw))>0,obj=kssolv.analysis.matgenlab.io.cp2k.GthPotential.from_str(d.raw);else,obj=kssolv.analysis.matgenlab.io.cp2k.GthPotential();n=fieldnames(d);for i=1:numel(n),if isprop(obj,n{i}),obj.(n{i})=d.(n{i});end,end;end,end
 end
end
