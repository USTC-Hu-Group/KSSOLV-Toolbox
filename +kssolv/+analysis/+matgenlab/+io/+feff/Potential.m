classdef Potential < handle
 %#ok<*AGROW,*CPROP>
 %POTENTIAL FEFF unique atomic potentials.
 properties,struct=[];absorbing_atom string="";center_index=1;radius=0;pot_dict struct=struct();end
 properties(Access=private),cluster_=[];end
 methods
  function obj=Potential(structure,absorbing_atom,radius)
   if nargin==0,return,end;if nargin<3||isempty(radius),radius=max(structure.distance_matrix,[],"all");end
   obj.struct=structure;obj.radius=radius;[obj.absorbing_atom,obj.center_index]=kssolv.analysis.matgenlab.io.feff.get_absorbing_atom_symbol_index(absorbing_atom,structure);a=kssolv.analysis.matgenlab.io.feff.Atoms(structure,absorbing_atom,radius);obj.cluster_=a.cluster;obj.pot_dict=kssolv.analysis.matgenlab.io.feff.get_atom_map(obj.cluster_,obj.absorbing_atom);
  end
  function value=get_str(obj)
   lines=["POTENTIALS";"*ipot Z tag lmax1 lmax2 xnatph(stoichometry) spinph";"*********************************************************"];
   element=kssolv.analysis.matgenlab.core.Element(obj.absorbing_atom);lines(end+1)=sprintf("%d %d %s %d %d %.4f %d",0,element.Z,element.symbol,-1,-1,0.0001,0);
   symbols=string(cellfun(@(s)s.specie.symbol,obj.cluster_.sites,"UniformOutput",false));uniqueSymbols=sort(unique(symbols));
   for symbol=uniqueSymbols,count=sum(symbols==symbol);if symbol==obj.absorbing_atom&&count==1,continue,end;ipot=obj.pot_dict.(matlab.lang.makeValidName(symbol));el=kssolv.analysis.matgenlab.core.Element(symbol);lines(end+1)=sprintf("%d %d %s %d %d %.4f %d",ipot,el.Z,el.symbol,-1,-1,count,0);end
   value=char(join(lines,newline));
  end
  function value=char(obj),value=obj.get_str();end
  function value=string(obj),value=string(obj.get_str());end
  function value=write_file(obj,filename),if nargin<2,filename="POTENTIALS";end;fid=fopen(filename,"w");c=onCleanup(@()fclose(fid));fprintf(fid,"%s\n",obj.get_str());value=string(filename);end
  function value=as_dict(obj),value=struct("x_module","pymatgen.io.feff.inputs","x_class","Potential","struct",obj.struct.as_dict(),"absorbing_atom",obj.absorbing_atom,"radius",obj.radius);end
 end
 methods(Static)
  function value=pot_string_from_file(filename),if nargin<1,filename="feff.inp";end;text=kssolv.analysis.matgenlab.io.feff.feff_read_text(filename);lines=splitlines(string(text));start=find(startsWith(upper(strtrim(lines)),"POTENTIALS"),1);if isempty(start),value="";return,end;out=lines(start);for i=start+1:numel(lines),line=lines(i);tok=split(strtrim(line));if strlength(strtrim(line))==0||upper(strtrim(line))=="ATOMS"||upper(strtrim(line))=="END",break,end;if startsWith(strtrim(line),"*")||(numel(tok)>=3&&~isnan(str2double(tok(1)))),out(end+1)=line;elseif numel(out)>1,break,end;end;value=char(join(out,newline));end
  function [forward,reverse]=pot_dict_from_str(text),forward=struct();reverse=containers.Map("KeyType","double","ValueType","char");lines=splitlines(string(text));for line=reshape(lines,1,[]),tok=split(strtrim(line));if numel(tok)>=3,idx=str2double(tok(1));if ~isnan(idx),symbol=char(tok(3));reverse(idx)=symbol;if idx>0,forward.(matlab.lang.makeValidName(symbol))=idx;end,end,end,end,end
  function obj=from_dict(d),if string(d.struct.x_class)=="Molecule",s=kssolv.analysis.matgenlab.core.Molecule.from_dict(d.struct);else,s=kssolv.analysis.matgenlab.core.Structure.from_dict(d.struct);end;obj=kssolv.analysis.matgenlab.io.feff.Potential(s,d.absorbing_atom,d.radius);end
 end
end
