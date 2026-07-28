classdef FEFFDictSet < kssolv.analysis.matgenlab.io.feff.AbstractFeffInputSet
 %#ok<*AGROW,*ISCL>
 %FEFFDICTSET Configurable FEFF input set.
 properties,absorbing_atom=[];structure=[];radius=10;config_dict struct=struct();edge string="K";spectrum string="EXAFS";nkpts=1000;user_tag_settings struct=struct();small_system=false;spacegroup_analyzer_settings struct=struct();end
 properties(Access=private),atoms_override=[];end
 methods
  function obj=FEFFDictSet(absorbingAtom,structure,radius,configDict,varargin)
   if nargin==0,return,end;obj.absorbing_atom=absorbingAtom;obj.structure=structure;obj.radius=radius;obj.config_dict=configDict;opt=struct("edge","K","spectrum","EXAFS","nkpts",1000,"user_tag_settings",struct(),"spacegroup_analyzer_settings",struct());opt=parseOpts(opt,varargin{:});obj.edge=string(opt.edge);obj.spectrum=string(opt.spectrum);obj.nkpts=opt.nkpts;obj.user_tag_settings=opt.user_tag_settings;obj.spacegroup_analyzer_settings=opt.spacegroup_analyzer_settings;
   if isa(structure,"kssolv.analysis.matgenlab.core.Structure")
    charge=structure.charge;
    if isfinite(charge)&&charge~=0,error("KSSOLV:Matgenlab:Feff:ChargedPeriodic","Periodic structures with net charge are not supported.");end
   end
   obj.config_dict.EDGE=obj.edge;n=fieldnames(obj.user_tag_settings);for i=1:numel(n),if ~strcmp(n{i},"_del")&&~strcmp(n{i},"x_del"),obj.config_dict.(n{i})=obj.user_tag_settings.(n{i});end,end
   if isfield(obj.user_tag_settings,"_del"),remove=string(obj.user_tag_settings.("_del"));elseif isfield(obj.user_tag_settings,"x_del"),remove=string(obj.user_tag_settings.x_del);else,remove=strings(0,1);end
   for name=reshape(remove,1,[]),if isfield(obj.config_dict,name),obj.config_dict=rmfield(obj.config_dict,name);end,end
   obj.small_system=structure.num_sites<14&&~isfield(obj.config_dict,"EXAFS");
  end
  function value=header(obj,source,comment),if nargin<2,source="";end;if nargin<3,comment="";end;value=kssolv.analysis.matgenlab.io.feff.Header(obj.structure,source,comment,obj.spacegroup_analyzer_settings);end
  function value=build_tags(obj)
   config=obj.config_dict;
   if isfield(config,"RECIPROCAL")
    if obj.small_system
     formula=erase(obj.structure.composition.formula," ");config.CIF=formula+".cif";a=obj.atoms;config.TARGET=a.center_index;config.COREHOLE="RPA";
     if ~isfield(config,"KMESH")||isempty(config.KMESH),abc=obj.structure.lattice.abc;mult=(obj.nkpts*prod(abc))^(1/3);config.KMESH=round(mult./abc);end
    else
     for name=["RECIPROCAL","CIF","TARGET","KMESH","STRFAC"],if isfield(config,name),config=rmfield(config,name);end,end
    end
   end
   value=kssolv.analysis.matgenlab.io.feff.Tags(config);
  end
  function value=build_potential(obj),value=kssolv.analysis.matgenlab.io.feff.Potential(obj.structure,obj.absorbing_atom,obj.radius);end
  function value=build_atoms(obj),if isempty(obj.atoms_override),value=kssolv.analysis.matgenlab.io.feff.Atoms(obj.structure,obj.absorbing_atom,obj.radius);else,value=obj.atoms_override;end,end
  function value=char(obj),lines=obj.spectrum;names=fieldnames(obj.config_dict);for i=1:numel(names),lines(end+1)=string(names{i})+" = "+valString(obj.config_dict.(names{i}));end;lines(end+1)="";value=char(join(lines,newline));end
  function value=string(obj),value=string(char(obj));end
  function value=as_dict(obj),p=split(string(class(obj)),".");value=struct("x_module","pymatgen.io.feff.sets","x_class",p(end),"absorbing_atom",obj.absorbing_atom,"structure",obj.structure.as_dict(),"radius",obj.radius,"config_dict",obj.config_dict,"edge",obj.edge,"spectrum",obj.spectrum,"nkpts",obj.nkpts,"user_tag_settings",obj.user_tag_settings,"spacegroup_analyzer_settings",obj.spacegroup_analyzer_settings);if isa(obj,"kssolv.analysis.matgenlab.io.feff.MPEELSDictSet"),value.beam_energy=obj.beam_energy;value.beam_direction=obj.beam_direction;value.collection_angle=obj.collection_angle;value.convergence_angle=obj.convergence_angle;value.user_eels_settings=obj.user_eels_settings;end,end
 end
 methods(Static)
  function obj=from_directory(inputDir),header=kssolv.analysis.matgenlab.io.feff.Header.from_file(fullfile(inputDir,"HEADER"));tags=kssolv.analysis.matgenlab.io.feff.Tags.from_file(fullfile(inputDir,"PARAMETERS"));cluster=[];if tags.has("RECIPROCAL"),absorber=double(tags("TARGET"))-1;radius=10;else,cluster=kssolv.analysis.matgenlab.io.feff.Atoms.cluster_from_file(fullfile(inputDir,"feff.inp"));absorber=string(cluster.sites{1}.specie.symbol);radius=ceil(max(cluster.distance_matrix(1,:)));end;config=tags.to_struct();if ~tags.has("XANES"),error("KSSOLV:Matgenlab:Feff:Directory","Only XANES FEFF directories are supported by the frozen upstream.");end;obj=kssolv.analysis.matgenlab.io.feff.FEFFDictSet(absorber,header.struct,radius,config,"edge",tags("EDGE"),"spectrum","XANES","user_tag_settings",config);if ~isempty(cluster),obj.atoms_override=kssolv.analysis.matgenlab.io.feff.Atoms.from_cluster(header.struct,absorber,radius,cluster);end;end
  function obj=from_dict(d),s=decodeStructure(d.structure);cls=string(d.x_class);switch cls,case "MPXANESSet",obj=kssolv.analysis.matgenlab.io.feff.MPXANESSet(d.absorbing_atom,s,"edge",d.edge,"radius",d.radius,"nkpts",d.nkpts,"user_tag_settings",d.user_tag_settings);case "MPEXAFSSet",obj=kssolv.analysis.matgenlab.io.feff.MPEXAFSSet(d.absorbing_atom,s,"edge",d.edge,"radius",d.radius,"nkpts",d.nkpts,"user_tag_settings",d.user_tag_settings);case "MPELNESSet",obj=kssolv.analysis.matgenlab.io.feff.MPELNESSet(d.absorbing_atom,s,"edge",d.edge,"radius",d.radius,"beam_energy",d.beam_energy,"beam_direction",d.beam_direction,"collection_angle",d.collection_angle,"convergence_angle",d.convergence_angle,"user_eels_settings",d.user_eels_settings,"nkpts",d.nkpts,"user_tag_settings",d.user_tag_settings);case "MPEXELFSSet",obj=kssolv.analysis.matgenlab.io.feff.MPEXELFSSet(d.absorbing_atom,s,"edge",d.edge,"radius",d.radius,"beam_energy",d.beam_energy,"beam_direction",d.beam_direction,"collection_angle",d.collection_angle,"convergence_angle",d.convergence_angle,"user_eels_settings",d.user_eels_settings,"nkpts",d.nkpts,"user_tag_settings",d.user_tag_settings);otherwise,obj=kssolv.analysis.matgenlab.io.feff.FEFFDictSet(d.absorbing_atom,s,d.radius,d.config_dict,"edge",d.edge,"spectrum",d.spectrum,"nkpts",d.nkpts,"user_tag_settings",d.user_tag_settings,"spacegroup_analyzer_settings",d.spacegroup_analyzer_settings);end,end
 end
end
function opt=parseOpts(opt,varargin),if numel(varargin)==1&&isstruct(varargin{1}),d=varargin{1};n=fieldnames(d);for i=1:numel(n),opt.(n{i})=d.(n{i});end;else,for i=1:2:numel(varargin),opt.(char(lower(string(varargin{i}))))=varargin{i+1};end,end,end
function value=valString(v),if isnumeric(v),value=join(string(v)," ");elseif isstruct(v),value="";else,value=string(v);end,end
function s=decodeStructure(d),if string(d.x_class)=="Molecule",s=kssolv.analysis.matgenlab.core.Molecule.from_dict(d);else,s=kssolv.analysis.matgenlab.core.Structure.from_dict(d);end,end
