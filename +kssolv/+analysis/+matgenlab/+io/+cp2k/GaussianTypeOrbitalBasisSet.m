classdef GaussianTypeOrbitalBasisSet < kssolv.analysis.matgenlab.io.cp2k.AtomicMetadata
 properties,nset=[];n=[];lmax=[];lmin=[];nshell={};exponents={};coefficients={};end
 properties(Dependent),nexp,end
 methods
  function obj=GaussianTypeOrbitalBasisSet(varargin),obj@kssolv.analysis.matgenlab.io.cp2k.AtomicMetadata(varargin{:});end
  function value=get.nexp(obj),value=cellfun(@numel,obj.exponents);end
  function value=get_keyword(obj),vals={};if ~isempty(obj.info)&&obj.info.admm,vals{end+1}="AUX_FIT";end;vals{end+1}=obj.name;value=kssolv.analysis.matgenlab.io.cp2k.Keyword("BASIS_SET",vals{:});end
  function value=get_str(obj),value=char(obj.raw);end
 end
 methods(Static)
  function obj=from_str(text),lines=splitlines(strtrim(string(text)));head=split(strtrim(lines(1)));obj=kssolv.analysis.matgenlab.io.cp2k.GaussianTypeOrbitalBasisSet();obj.element=kssolv.analysis.matgenlab.core.Element(head(1));obj.name=head(2);obj.alias_names=head(3:end);obj.info=kssolv.analysis.matgenlab.io.cp2k.BasisInfo.from_str(obj.name);obj.potential="Pseudopotential";obj.raw=string(text);obj.nset=str2double(strtrim(lines(2)));idx=3;obj.exponents=cell(1,obj.nset);obj.coefficients=cell(1,obj.nset);obj.n=zeros(1,obj.nset);obj.lmin=obj.n;obj.lmax=obj.n;for s=1:obj.nset,a=str2double(split(strtrim(lines(idx))));idx=idx+1;obj.n(s)=a(1);obj.lmin(s)=a(2);obj.lmax(s)=a(3);ne=a(4);obj.nshell{s}=a(5:end);e=zeros(1,ne);c=cell(1,ne);for j=1:ne,row=str2double(split(strtrim(lines(idx))));idx=idx+1;e(j)=row(1);c{j}=row(2:end);end;obj.exponents{s}=e;obj.coefficients{s}=c;end,end
  function obj=from_dict(d),if isfield(d,"raw")&&strlength(string(d.raw))>0,obj=kssolv.analysis.matgenlab.io.cp2k.GaussianTypeOrbitalBasisSet.from_str(d.raw);else,obj=kssolv.analysis.matgenlab.io.cp2k.GaussianTypeOrbitalBasisSet();n=fieldnames(d);for i=1:numel(n),if isprop(obj,n{i}),obj.(n{i})=d.(n{i});end,end;end,end
 end
end
