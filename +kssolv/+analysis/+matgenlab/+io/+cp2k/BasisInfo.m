classdef BasisInfo < handle
 properties,electrons=[];core=[];valence=[];polarization=[];diffuse=[];cc=false;pc=false;sr=false;molopt=false;admm=false;lri=false;contracted=[];xc=[];end
 methods
  function obj=BasisInfo(varargin),for i=1:2:numel(varargin),obj.(char(varargin{i}))=varargin{i+1};end,end
  function value=softmatch(obj,other),value=isa(other,class(obj));n=properties(obj);for i=1:numel(n),v=obj.(n{i});if ~isempty(v)&&~isequal(v,other.(n{i})),value=false;return,end,end,end
  function value=as_dict(obj),value=struct();n=properties(obj);for i=1:numel(n),value.(n{i})=obj.(n{i});end,end
 end
 methods(Static)
  function obj=from_str(text),s=upper(string(text));obj=kssolv.analysis.matgenlab.io.cp2k.BasisInfo();obj.cc=contains(s,"CC");s=replace(s,"CC","");obj.pc=contains(s,"PC");s=replace(s,"PC","");obj.sr=contains(s,"SR");s=replace(s,"SR","");obj.molopt=contains(s,"MOLOPT");s=replace(s,"MOLOPT","");obj.admm=contains(s,"ADMM")||contains(s,"FIT");obj.contracted=obj.admm&&contains(s,"C");obj.lri=contains(s,"LRI");for x=["SCAN","B3LYP","BLYP","PBE0","PBE","GGA","MGGA","LDA","HF"],if contains(s,x),obj.xc=x;s=replace(s,x,"");break,end,end;obj.polarization=count(s,"P");obj.diffuse=count(s,"X")+count(s,"AUG");z=regexp(s,'([SDTQ]|\d)Z','tokens','once');if ~isempty(z),map=struct("S",1,"D",2,"T",3,"Q",4);if isfield(map,z{1}),obj.valence=map.(z{1});else,obj.valence=str2double(z{1});end;if ~contains(s,"V")||contains(s,"ALL"),obj.core=obj.valence;end;end;q=regexp(s,'Q(\d+)','tokens','once');if ~isempty(q),obj.electrons=str2double(q{1});end;if obj.admm,n=regexp(s,'\d+','match');if ~isempty(n),obj.valence=str2double(n{end});end;if contains(s,"FIT")&&obj.polarization==0,obj.polarization=1;end;end,end
  function obj=from_dict(d),obj=kssolv.analysis.matgenlab.io.cp2k.BasisInfo();n=fieldnames(d);for i=1:numel(n),if isprop(obj,n{i}),obj.(n{i})=d.(n{i});end,end,end
 end
end
