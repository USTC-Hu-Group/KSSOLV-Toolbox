classdef Paths < handle
 %#ok<*AGROW,*NOCOMMA>
 properties,atoms=[];paths cell={};degeneracies=[];end
 methods
  function obj=Paths(atoms,paths,degeneracies),if nargin==0,return,end;obj.atoms=atoms;if iscell(paths),obj.paths=paths;else,obj.paths=num2cell(paths,2);end;if nargin<3||isempty(degeneracies),degeneracies=ones(1,numel(obj.paths));end;if numel(degeneracies)~=numel(obj.paths),error("KSSOLV:Matgenlab:Feff:Paths","Path and degeneracy counts differ.");end;obj.degeneracies=degeneracies;end
  function value=get_str(obj),lines=["PATH";"---------------"];pathIndex=9999;for i=1:numel(obj.paths),legs=obj.paths{i};lines(end+1)=sprintf("%d %d %g",pathIndex,numel(legs),obj.degeneracies(i));lines(end+1)="x y z ipot label";for leg=reshape(legs,1,[]),site=obj.atoms.cluster.sites{leg+1};coords=site.coords;symbol=string(site.specie.symbol);if norm(coords)<=1e-6,ipot=0;else,ipot=obj.atoms.pot_dict.(matlab.lang.makeValidName(symbol));end;lines(end+1)=sprintf("%.6f %.6f %.6f %d %s",coords(1),coords(2),coords(3),ipot,symbol);end;pathIndex=pathIndex-1;end;value=char(join(lines,newline));end
  function value=char(obj),value=obj.get_str();end
  function value=string(obj),value=string(obj.get_str());end
  function value=write_file(obj,filename),if nargin<2,filename="paths.dat";end;fid=fopen(filename,"w");c=onCleanup(@()fclose(fid));fprintf(fid,"%s\n",obj.get_str());value=string(filename);end
  function value=as_dict(obj),value=struct("x_module","pymatgen.io.feff.inputs","x_class","Paths","atoms",obj.atoms.as_dict(),"paths",{obj.paths},"degeneracies",obj.degeneracies);end
 end
 methods(Static),function obj=from_dict(d),obj=kssolv.analysis.matgenlab.io.feff.Paths(kssolv.analysis.matgenlab.io.feff.Atoms.from_dict(d.atoms),d.paths,d.degeneracies);end,end
end
