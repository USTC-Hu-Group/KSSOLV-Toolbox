classdef Atoms < handle
 %#ok<*AGROW,*CPROP>
 %ATOMS Atomic FEFF cluster centered on the absorber.
 properties,struct=[];absorbing_atom string="";center_index=1;radius=0;pot_dict struct=struct();end
 properties(Access=private),cluster_=[];end
 properties(Dependent),cluster;end
 methods
  function obj=Atoms(structure,absorbing_atom,radius)
   if nargin==0,return,end;obj.struct=structure;[obj.absorbing_atom,obj.center_index]=kssolv.analysis.matgenlab.io.feff.get_absorbing_atom_symbol_index(absorbing_atom,structure);obj.radius=radius;obj.cluster_=makeCluster(structure,obj.center_index,obj.absorbing_atom,radius);obj.pot_dict=kssolv.analysis.matgenlab.io.feff.get_atom_map(obj.cluster_,obj.absorbing_atom);
  end
  function v=get.cluster(obj),v=obj.cluster_;end
  function lines=get_lines(obj)
   n=obj.cluster_.num_sites;lines=cell(n,7);
   for i=1:n,site=obj.cluster_.sites{i};symbol=string(site.specie.symbol);if i==1,ipot=0;else,ipot=obj.pot_dict.(matlab.lang.makeValidName(symbol));end;distance=norm(site.coords);lines(i,:)={sprintf("%.12g",site.coords(1)),sprintf("%.12g",site.coords(2)),sprintf("%.12g",site.coords(3)),ipot,char(symbol),sprintf("%.12g",distance),i-1};end
   distances=cellfun(@str2double,lines(:,6));[~,order]=sort(distances);lines=lines(order,:);
  end
  function value=get_str(obj),rows=obj.get_lines();lines=["ATOMS";"*       x              y              z      ipot Atom Distance Number";"**********************************************************************"];for i=1:size(rows,1),lines(end+1)=sprintf("%14.6f %14.6f %14.6f %4d %-3s %12.6f %5d",str2double(rows{i,1}),str2double(rows{i,2}),str2double(rows{i,3}),rows{i,4},rows{i,5},str2double(rows{i,6}),rows{i,7});end;lines(end+1)="END";value=char(join(lines,newline)+newline);end
  function value=char(obj),value=obj.get_str();end
  function value=string(obj),value=string(obj.get_str());end
  function value=write_file(obj,filename),if nargin<2,filename="ATOMS";end;fid=fopen(filename,"w");c=onCleanup(@()fclose(fid));fprintf(fid,"%s",obj.get_str());value=string(filename);end
  function value=as_dict(obj),value=struct("x_module","pymatgen.io.feff.inputs","x_class","Atoms","struct",obj.struct.as_dict(),"absorbing_atom",obj.absorbing_atom,"radius",obj.radius);end
 end
 methods(Static)
  function value=atoms_string_from_file(filename),text=kssolv.analysis.matgenlab.io.feff.feff_read_text(filename);lines=splitlines(string(text));start=find(contains(upper(strtrim(lines)),"ATOMS")&startsWith(upper(strtrim(lines)),"ATOMS"),1);if isempty(start),value="";return,end;stop=find(upper(strtrim(lines(start+1:end)))=="END",1);if isempty(stop),last=numel(lines);else,last=start+stop-1;end;value=char(join(lines(start:last),newline)+newline);end
  function value=cluster_from_file(filename),text=kssolv.analysis.matgenlab.io.feff.Atoms.atoms_string_from_file(filename);lines=splitlines(string(text));species={};coords=zeros(0,3);for i=2:numel(lines),tok=split(strtrim(lines(i)));if numel(tok)>=5&&~startsWith(tok(1),"*")&&~isnan(str2double(tok(1))),coords(end+1,:)=str2double(tok(1:3));species{end+1}=char(tok(5));end,end;value=kssolv.analysis.matgenlab.core.Molecule(species,coords);end
  function obj=from_dict(d),if string(d.struct.x_class)=="Molecule",s=kssolv.analysis.matgenlab.core.Molecule.from_dict(d.struct);else,s=kssolv.analysis.matgenlab.core.Structure.from_dict(d.struct);end;obj=kssolv.analysis.matgenlab.io.feff.Atoms(s,d.absorbing_atom,d.radius);end
  function obj=from_cluster(structure,absorbingAtom,radius,cluster),obj=kssolv.analysis.matgenlab.io.feff.Atoms();obj.struct=structure;[obj.absorbing_atom,obj.center_index]=kssolv.analysis.matgenlab.io.feff.get_absorbing_atom_symbol_index(absorbingAtom,structure);obj.radius=radius;obj.cluster_=cluster;obj.pot_dict=kssolv.analysis.matgenlab.io.feff.get_atom_map(cluster,obj.absorbing_atom);end
 end
end
function cluster=makeCluster(structure,index,symbol,radius),center=structure.sites{index}.coords;neighbors=structure.get_neighbors(structure.sites{index},radius);species=cell(1,numel(neighbors)+1);species{1}=char(symbol);coords=zeros(numel(neighbors)+1,3);for i=1:numel(neighbors),species{i+1}=char(neighbors{i}.specie.symbol);coords(i+1,:)=neighbors{i}.coords-center;end;cluster=kssolv.analysis.matgenlab.core.Molecule(species,coords);end
