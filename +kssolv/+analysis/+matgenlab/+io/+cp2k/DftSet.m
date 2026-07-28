classdef DftSet < kssolv.analysis.matgenlab.io.cp2k.Cp2kInput
%#ok<*AGROW,*ISCL>
 %DFTSET Production-oriented CP2K Quickstep input-set builder.
 properties
  structure=[];basis_and_potential struct=struct();element_defaults struct=struct()
  project_name string="CP2K";charge=0;multiplicity=0;ot=true;qs_method string="GPW"
  energy_gap=-1;eps_default=1e-12;eps_scf=1e-6;max_scf=[];cutoff=[]
  rel_cutoff=50;ngrids=5;progression_factor=3;kpoints=[];smearing=false
  xc_functionals string="PBE";cell struct=struct();kwargs struct=struct()
 end
 methods
  function obj=DftSet(structure,varargin)
   obj@kssolv.analysis.matgenlab.io.cp2k.Cp2kInput("CP2K_INPUT",struct());
   if nargin==0,return,end
   obj.structure=structure;
   opt=defaults();opt=parseOptions(opt,varargin{:});obj.kwargs=opt;
   copyNames=["project_name","multiplicity","ot","qs_method","energy_gap","eps_default", ...
    "eps_scf","max_scf","cutoff","rel_cutoff","ngrids","progression_factor","kpoints","smearing","cell"];
   for n=copyNames,obj.(char(n))=opt.(char(n));end
   if isprop(structure,"charge"),obj.charge=double(structure.charge);end
   if obj.multiplicity==0&&isa(structure,"kssolv.analysis.matgenlab.core.Molecule")&&isprop(structure,"spin_multiplicity")
    obj.multiplicity=structure.spin_multiplicity;
   end
   obj.element_defaults=opt.element_defaults;
   obj.basis_and_potential=obj.get_basis_and_potential(structure,opt.basis_and_potential,opt.cp2k_data_dir);
   obj.xc_functionals=obj.get_xc_functionals(opt.xc_functionals);
   obj.insert(kssolv.analysis.matgenlab.io.cp2k.ForceEval());
   obj.insert(kssolv.analysis.matgenlab.io.cp2k.Global(obj.project_name,opt.run_type));
   obj.create_subsys(structure);
   bases=collectBases(obj.basis_and_potential);
   if isempty(obj.cutoff),obj.cutoff=obj.get_cutoff_from_basis(bases,obj.rel_cutoff);end
   dft=kssolv.analysis.matgenlab.io.cp2k.Dft("MULTIPLICITY",obj.multiplicity,"CHARGE",obj.charge, ...
    "UKS",opt.spin_polarized);
   qs=kssolv.analysis.matgenlab.io.cp2k.QS(obj.qs_method,obj.eps_default);
   scfMax=obj.max_scf;if isempty(scfMax),if obj.ot,scfMax=20;else,scfMax=400;end,end
   scf=kssolv.analysis.matgenlab.io.cp2k.Scf(scfMax,obj.eps_scf,"RESTART");
   if obj.ot
    scf.insert(kssolv.analysis.matgenlab.io.cp2k.OrbitalTransformation( ...
     "MINIMIZER",opt.minimizer,"PRECONDITIONER",opt.preconditioner, ...
     "ENERGY_GAP",obj.energy_gap,"ALGORITHM",opt.algorithm,"LINESEARCH",opt.linesearch, ...
     "ROTATION",opt.rotation,"OCCUPATION_PRECONDITIONER",opt.occupation_preconditioner));
    scf.insert(kssolv.analysis.matgenlab.io.cp2k.Section("OUTER_SCF", ...
     "keywords",struct("MAX_SCF",kssolv.analysis.matgenlab.io.cp2k.Keyword("MAX_SCF",opt.outer_max_scf), ...
     "EPS_SCF",kssolv.analysis.matgenlab.io.cp2k.Keyword("EPS_SCF",opt.outer_eps_scf))));
   else
    scf.insert(kssolv.analysis.matgenlab.io.cp2k.Diagonalization());
    scf.insert(kssolv.analysis.matgenlab.io.cp2k.Section("MIXING", ...
     "ALPHA",opt.alpha,"BETA",opt.beta,"NBUFFER",opt.nbuffer,"N_SIMPLE_MIX",opt.n_simple_mix, ...
     "METHOD",opt.mixing_method));
   end
   dft.insert(qs);dft.insert(scf);
   dft.insert(kssolv.analysis.matgenlab.io.cp2k.Mgrid(obj.cutoff,obj.rel_cutoff,obj.ngrids,obj.progression_factor));
   if ~isempty(obj.kpoints),dft.insert(kssolv.analysis.matgenlab.io.cp2k.Kpoints.from_kpoints(obj.kpoints,structure));end
   xc=kssolv.analysis.matgenlab.io.cp2k.Section("XC");
   xcf=kssolv.analysis.matgenlab.io.cp2k.XCFunctional();
   for i=1:numel(obj.xc_functionals),xcf.insert(kssolv.analysis.matgenlab.io.cp2k.Section(obj.xc_functionals(i)));end
   xc.insert(xcf);dft.insert(xc);dft.insert(kssolv.analysis.matgenlab.io.cp2k.Section("PRINT"));
   forceEval=obj.get_section("FORCE_EVAL");forceEval.insert(dft);
   if isa(structure,"kssolv.analysis.matgenlab.core.Molecule"),obj.activate_nonperiodic();end
   if opt.print_forces,obj.print_forces();end
   if opt.print_dos,obj.print_dos();end
   if opt.print_pdos,obj.print_pdos();end
   if opt.print_ldos,obj.print_ldos();end
   if opt.print_mo_cubes,obj.print_mo_cubes();end
   if opt.print_v_hartree,obj.print_v_hartree();end
   if opt.print_e_density,obj.print_e_density();end
   if opt.print_bandstructure,obj.print_bandstructure(opt.kpoints_line_density);end
   if ~isempty(fieldnames(opt.override_default_params)),obj.update(opt.override_default_params);end
   if opt.validate,obj.validate();end
  end

  function data=get_basis_and_potential(~,structure,spec,cp2kDataDir)
   if nargin<3||isempty(spec),spec=struct();end
   if nargin<4,cp2kDataDir="";end
   if strlength(string(cp2kDataDir))==0,cp2kDataDir=string(getenv("PMG_CP2K_DATA_DIR"));end
   if strlength(string(cp2kDataDir))==0,cp2kDataDir=string(getenv("CP2K_DATA_DIR"));end
   symbols=siteSymbols(structure);data=struct("basis_filenames",strings(0,1),"potential_filename","GTH_POTENTIALS");
   for i=1:numel(symbols)
    symbol=symbols(i);entry=struct();field=matlab.lang.makeValidName(symbol);
    if isfield(spec,field),entry=spec.(field);end
    if ~isfield(entry,"basis")
     entry.basis=resolveAtomicName(symbol,spec,"basis",cp2kDataDir,"DZVP-MOLOPT-GTH");
    elseif ischar(entry.basis)||isstring(entry.basis)
     entry.basis=resolveHashName(symbol,string(entry.basis),cp2kDataDir,"basis_sets");
    end
    if ~isfield(entry,"potential")
     entry.potential=resolveAtomicName(symbol,spec,"potential",cp2kDataDir,"GTH-PBE");
    elseif ischar(entry.potential)||isstring(entry.potential)
     entry.potential=resolveHashName(symbol,string(entry.potential),cp2kDataDir,"potentials");
    end
    if isfield(entry,"aux_basis")&&(ischar(entry.aux_basis)||isstring(entry.aux_basis))
     entry.aux_basis=resolveHashName(symbol,string(entry.aux_basis),cp2kDataDir,"basis_sets");
    end
    data.(field)=entry;
   end
   if isfield(spec,"basis_filenames"),data.basis_filenames=string(spec.basis_filenames);end
   if isfield(spec,"potential_filename"),data.potential_filename=string(spec.potential_filename);end
  end

  function value=get_cutoff_from_basis(~,basisSets,relCutoff)
   if nargin<3,relCutoff=50;end;largest=0;
   if ~iscell(basisSets),basisSets={basisSets};end
   for i=1:numel(basisSets)
    basis=basisSets{i};
    if isa(basis,"kssolv.analysis.matgenlab.io.cp2k.GaussianTypeOrbitalBasisSet")
     for j=1:numel(basis.exponents),if ~isempty(basis.exponents{j}),largest=max(largest,max(basis.exponents{j}));end,end
    end
   end
   if largest==0,value=400;else,value=ceil(largest)*relCutoff;end
  end

  function value=get_xc_functionals(~,value)
   if nargin<2||isempty(value),value="PBE";end;names=reshape(upper(string(value)),1,[]);value=strings(0,1);
   for name=names
    switch name
     case {"LDA","LSDA"},value(end+1)="PADE";
     case "SCAN",value=[value;"MGGA_X_SCAN";"MGGA_C_SCAN"];
     case "SCANL",value=[value;"MGGA_X_SCANL";"MGGA_C_SCANL"];
     case "R2SCAN",value=[value;"MGGA_X_R2SCAN";"MGGA_C_R2SCAN"];
     case "R2SCANL",value=[value;"MGGA_X_R2SCANL";"MGGA_C_R2SCANL"];
     otherwise,value(end+1)=name;
    end
   end
   value=reshape(value,1,[]);
  end

  function value=write_basis_set_file(~,basisSets,fn),if nargin<3,fn="BASIS";end;kssolv.analysis.matgenlab.io.cp2k.BasisFile(flattenObjects(basisSets)).write_file(fn);value=string(fn);end
  function value=write_potential_file(~,potentials,fn),if nargin<3,fn="POTENTIAL";end;kssolv.analysis.matgenlab.io.cp2k.PotentialFile(flattenObjects(potentials)).write_file(fn);value=string(fn);end
  function value=print_forces(obj),ensure(obj,"FORCE_EVAL/PRINT").insert(kssolv.analysis.matgenlab.io.cp2k.Section("FORCES"));value=obj;end
  function value=print_dos(obj,ndigits),if nargin<2,ndigits=6;end;if ~isempty(obj.kpoints),s=kssolv.analysis.matgenlab.io.cp2k.DOS();s.setitem("NDIGITS",ndigits);ensure(obj,"FORCE_EVAL/DFT/PRINT").insert(s);end;value=obj;end
  function value=print_pdos(obj,nlumo),if nargin<2,nlumo=-1;end;s=kssolv.analysis.matgenlab.io.cp2k.PDOS();s.setitem("NLUMO",nlumo);ensure(obj,"FORCE_EVAL/DFT/PRINT").insert(s);value=obj;end
  function value=print_ldos(obj,nlumo),if nargin<2,nlumo=-1;end;s=kssolv.analysis.matgenlab.io.cp2k.LDOS();s.setitem("NLUMO",nlumo);ensure(obj,"FORCE_EVAL/DFT/PRINT").insert(s);value=obj;end
  function value=print_mo_cubes(obj,writeCube,nlumo,nhomo),if nargin<2,writeCube=false;end;if nargin<3,nlumo=-1;end;if nargin<4,nhomo=-1;end;s=kssolv.analysis.matgenlab.io.cp2k.MOCubes();s.setitem("WRITE_CUBE",writeCube);s.setitem("NLUMO",nlumo);s.setitem("NHOMO",nhomo);ensure(obj,"FORCE_EVAL/DFT/PRINT").insert(s);value=obj;end
  function value=print_mo(obj),ensure(obj,"FORCE_EVAL/DFT/PRINT").insert(kssolv.analysis.matgenlab.io.cp2k.Section("MO"));value=obj;end
  function value=print_v_hartree(obj,stride),if nargin<2,stride=[2,2,2];end;s=kssolv.analysis.matgenlab.io.cp2k.VHartreeCube();s.setitem("STRIDE",stride);ensure(obj,"FORCE_EVAL/DFT/PRINT").insert(s);value=obj;end
  function value=print_e_density(obj,stride),if nargin<2,stride=[2,2,2];end;s=kssolv.analysis.matgenlab.io.cp2k.EDensityCube();s.setitem("STRIDE",stride);ensure(obj,"FORCE_EVAL/DFT/PRINT").insert(s);value=obj;end
  function value=print_bandstructure(obj,kpointsLineDensity),if nargin<2,kpointsLineDensity=20;end;s=kssolv.analysis.matgenlab.io.cp2k.BandStructure();s.setitem("KPOINTS_LINE_DENSITY",kpointsLineDensity);ensure(obj,"FORCE_EVAL/DFT/PRINT").insert(s);value=obj;end
  function value=print_hirshfeld(obj,on),if nargin<2,on=true;end;s=kssolv.analysis.matgenlab.io.cp2k.Section("HIRSHFELD","SECTION_PARAMETERS",string(on));ensure(obj,"FORCE_EVAL/DFT/PRINT").insert(s);value=obj;end
  function value=print_mulliken(obj,on),if nargin<2,on=false;end;s=kssolv.analysis.matgenlab.io.cp2k.Section("MULLIKEN","SECTION_PARAMETERS",string(on));ensure(obj,"FORCE_EVAL/DFT/PRINT").insert(s);value=obj;end
  function value=set_charge(obj,charge),obj.charge=charge;sec=obj.by_path("FORCE_EVAL/DFT");sec.setitem("CHARGE",charge);value=obj;end

  function value=activate_hybrid(obj,varargin)
   opt=struct("hybrid_functional","PBE0","hf_fraction",0.25,"max_memory",2000,"cutoff_radius",8, ...
    "admm",true,"eps_schwarz",1e-7,"eps_schwarz_forces",1e-6);opt=parseOptions(opt,varargin{:});
   xc=ensure(obj,"FORCE_EVAL/DFT/XC");hf=kssolv.analysis.matgenlab.io.cp2k.Section("HF","FRACTION",opt.hf_fraction);
   hf.insert(kssolv.analysis.matgenlab.io.cp2k.Section("SCREENING","EPS_SCHWARZ",opt.eps_schwarz, ...
    "EPS_SCHWARZ_FORCES",opt.eps_schwarz_forces));
   hf.insert(kssolv.analysis.matgenlab.io.cp2k.Section("INTERACTION_POTENTIAL", ...
    "POTENTIAL_TYPE",chooseHybridPotential(opt.hybrid_functional,obj.structure),"CUTOFF_RADIUS",opt.cutoff_radius));
   hf.insert(kssolv.analysis.matgenlab.io.cp2k.Section("MEMORY","MAX_MEMORY",opt.max_memory));
   xc.insert(hf);
   if opt.admm,ensure(obj,"FORCE_EVAL/DFT").insert(kssolv.analysis.matgenlab.io.cp2k.Section("AUXILIARY_DENSITY_MATRIX_METHOD","METHOD","BASIS_PROJECTION"));end;value=obj;
  end

  function value=activate_motion(obj,varargin)
   opt=struct("max_drift",3e-3,"rms_drift",1.5e-3,"max_force",4.5e-4,"rms_force",3e-4, ...
    "max_iter",200,"optimizer","BFGS","trust_radius",0.25);opt=parseOptions(opt,varargin{:});
   motion=ensure(obj,"MOTION");pr=ensure(obj,"MOTION/PRINT");
   for name=["TRAJECTORY","CELL","FORCES","STRESS"],pr.insert(kssolv.analysis.matgenlab.io.cp2k.Section(name));end
   globalSec=obj.get_section("GLOBAL");runKw=globalSec.get_keyword("RUN_TYPE");run=upper(string(runKw.values{1}));
   if ismember(run,["GEO_OPT","CELL_OPT"])
    sec=kssolv.analysis.matgenlab.io.cp2k.Section(run,"MAX_DR",opt.max_drift,"RMS_DR",opt.rms_drift, ...
     "MAX_FORCE",opt.max_force,"RMS_FORCE",opt.rms_force,"MAX_ITER",opt.max_iter,"OPTIMIZER",opt.optimizer);
    if upper(string(opt.optimizer))=="BFGS",sec.insert(kssolv.analysis.matgenlab.io.cp2k.Section("BFGS","TRUST_RADIUS",opt.trust_radius));end
    motion.insert(sec);
   end;value=obj;
  end
  function value=activate_tddfpt(obj,varargin),ensure(obj,"FORCE_EVAL/PROPERTIES").insert(sectionWithOptions("TDDFPT",varargin{:}));value=obj;end
  function value=activate_epr(obj,varargin),obj.activate_localize();s=sectionWithOptions("EPR",varargin{:});ensureNested(s,"PRINT/G_TENSOR");ensure(obj,"FORCE_EVAL/PROPERTIES/LINRES").insert(s);value=obj;end
  function value=activate_nmr(obj,varargin),obj.activate_localize();s=sectionWithOptions("NMR",varargin{:});ensureNested(s,"PRINT/CHI_TENSOR");ensureNested(s,"PRINT/SHIELDING_TENSOR");ensure(obj,"FORCE_EVAL/PROPERTIES/LINRES").insert(s);value=obj;end
  function value=activate_spinspin(obj,varargin),obj.activate_localize();ensure(obj,"FORCE_EVAL/PROPERTIES/LINRES").insert(sectionWithOptions("SPINSPIN",varargin{:}));value=obj;end
  function value=activate_polar(obj,varargin),ensure(obj,"FORCE_EVAL/PROPERTIES/LINRES").insert(sectionWithOptions("POLAR",varargin{:}));value=obj;end
  function value=activate_hyperfine(obj),ensure(obj,"FORCE_EVAL/DFT/PRINT").insert(kssolv.analysis.matgenlab.io.cp2k.Section("HYPERFINE_COUPLING_TENSOR","FILENAME","HYPERFINE"));value=obj;end
  function value=activate_localize(obj,states,preconditioner,restart)
   if nargin<2,states="OCCUPIED";end;if nargin<3,preconditioner="FULL_ALL";end;if nargin<4,restart=false;end
   s=kssolv.analysis.matgenlab.io.cp2k.Section("LOCALIZE","STATES",states,"PRECONDITIONER",preconditioner,"RESTART",restart);
   ensureNested(s,"PRINT/LOC_RESTART");ensure(obj,"FORCE_EVAL/PROPERTIES/LINRES").insert(s);value=obj;
  end
  function value=activate_vdw_potential(obj,dispersionFunctional,potentialType)
   v=kssolv.analysis.matgenlab.io.cp2k.Section("VDW_POTENTIAL","DISPERSION_FUNCTIONAL",dispersionFunctional);
   v.insert(kssolv.analysis.matgenlab.io.cp2k.Section(dispersionFunctional,"TYPE",potentialType));
   ensure(obj,"FORCE_EVAL/DFT/XC").insert(v);value=obj;
  end
  function value=activate_fast_minimization(obj,on),if on,replaceOT(obj,"DIIS","FULL_ALL","IRAC","2PNT");end;value=obj;end
  function value=activate_robust_minimization(obj),replaceOT(obj,"CG","FULL_ALL","STRICT","3PNT");value=obj;end
  function value=activate_very_strict_minimization(obj),replaceOT(obj,"CG","FULL_ALL","STRICT","GOLD");value=obj;end
  function value=activate_nonperiodic(obj,solver),if nargin<2,solver="ANALYTIC";end;ensure(obj,"FORCE_EVAL/DFT").insert(kssolv.analysis.matgenlab.io.cp2k.Section("POISSON","POISSON_SOLVER",solver,"PERIODIC","NONE"));value=obj;end

  function value=create_subsys(obj,structure)
   subsys=kssolv.analysis.matgenlab.io.cp2k.Subsys();
   if isa(structure,"kssolv.analysis.matgenlab.core.Structure")
    cellSec=kssolv.analysis.matgenlab.io.cp2k.Cell(structure.lattice);
   else
    xyz=structure.cart_coords;span=max(max(abs(xyz),[],1),1);cellSec=kssolv.analysis.matgenlab.io.cp2k.Cell(diag(10*span));cellSec.setitem("PERIODIC","NONE");
   end
   names=fieldnames(obj.cell);for i=1:numel(names),cellSec.setitem(names{i},obj.cell.(names{i}));end;subsys.insert(cellSec);
   uniqueKinds=kssolv.analysis.matgenlab.io.cp2k.get_unique_site_indices(structure);kindNames=fieldnames(uniqueKinds);
   props=structure.site_properties;
   for i=1:numel(kindNames)
    alias=string(kindNames{i});ids=uniqueKinds.(kindNames{i});symbol=extractBefore(alias,"_");entry=obj.basis_and_potential.(matlab.lang.makeValidName(symbol));
    args={"alias",alias,"basis_set",entry.basis,"potential",entry.potential};
    mag=propertyAt(props,"magmom",ids(1),[]);if isempty(mag)&&isfield(obj.element_defaults,matlab.lang.makeValidName(symbol)),d=obj.element_defaults.(matlab.lang.makeValidName(symbol));if isfield(d,"magnetization"),mag=d.magnetization;end,end
    if ~isempty(mag),args=[args,{"magnetization",mag}];end
    ghost=propertyAt(props,"ghost",ids(1),[]);if ~isempty(ghost),args=[args,{"ghost",ghost}];end
    if isfield(entry,"aux_basis"),args=[args,{"aux_basis",entry.aux_basis}];end
    subsys.insert(kssolv.analysis.matgenlab.io.cp2k.Kind(symbol,args{:}));
   end
   subsys.insert(kssolv.analysis.matgenlab.io.cp2k.Coord(structure,"aliases",uniqueKinds));forceEval=obj.get_section("FORCE_EVAL");forceEval.insert(subsys);value=obj;
  end

  function value=modify_dft_print_iters(obj,iters,addLast)
   if nargin<3,addLast="no";end;pr=ensure(obj,"FORCE_EVAL/DFT/PRINT");names=fieldnames(pr.subsections);
   globalSec=obj.get_section("GLOBAL");runKw=globalSec.get_keyword("RUN_TYPE");run=upper(string(runKw.values{1}));
   for i=1:numel(names),s=pr.subsections.(names{i});each=kssolv.analysis.matgenlab.io.cp2k.Section("EACH");each.setitem(run,iters);s.insert(each);s.setitem("ADD_LAST",addLast);end;value=obj;
  end
  function value=validate(obj)
   if obj.check("FORCE_EVAL/DFT/KPOINTS")&&obj.check("FORCE_EVAL/DFT/XC/HF")
    error("KSSOLV:Matgenlab:Cp2k:Validation","CP2K v2022.1: Does not support hartree fock with kpoints");
   end
   value=true;
  end
 end
end

function opt=defaults()
opt=struct("project_name","CP2K","basis_and_potential",struct(),"element_defaults",struct(), ...
 "xc_functionals","PBE","multiplicity",0,"ot",true,"energy_gap",-1,"qs_method","GPW", ...
 "eps_default",1e-12,"eps_scf",1e-6,"max_scf",[],"minimizer","DIIS", ...
 "preconditioner","FULL_SINGLE_INVERSE","algorithm","IRAC","linesearch","2PNT", ...
 "rotation",true,"occupation_preconditioner",false,"cutoff",[],"rel_cutoff",50, ...
 "ngrids",5,"progression_factor",3,"override_default_params",struct(), ...
 "kpoints",[],"smearing",false,"cell",struct(),"run_type","ENERGY_FORCE", ...
 "spin_polarized",true,"outer_max_scf",20,"outer_eps_scf",1e-6,"alpha",0.05, ...
 "beta",0.01,"nbuffer",10,"n_simple_mix",3,"mixing_method","BROYDEN_MIXING", ...
 "print_forces",true,"print_dos",true,"print_pdos",true,"print_ldos",false, ...
 "print_mo_cubes",true,"print_v_hartree",true,"print_e_density",true, ...
 "print_bandstructure",false,"kpoints_line_density",20,"validate",true,"cp2k_data_dir","");
end
function opt=parseOptions(opt,varargin),if numel(varargin)==1&&isstruct(varargin{1}),d=varargin{1};n=fieldnames(d);for i=1:numel(n),opt.(n{i})=d.(n{i});end;return,end;for i=1:2:numel(varargin),opt.(char(lower(string(varargin{i}))))=varargin{i+1};end,end
function symbols=siteSymbols(s),symbols=string(cellfun(@(x)x.specie.symbol,s.sites,"UniformOutput",false));symbols=unique(symbols,"stable");end
function value=resolveAtomicName(symbol,spec,kind,folder,fallback)
value=fallback;needle="";
if kind=="basis"&&isfield(spec,"basis_type"),needle=string(spec.basis_type);value=needle;end
if kind=="potential",functional="PBE";if isfield(spec,"functional")&&~isempty(spec.functional),functional=string(spec.functional);end;needle="GTH-"+functional;value=needle;end
if strlength(folder)>0&&isfile(fullfile(folder,symbol)),value=findMatchingName(fullfile(folder,symbol),kind,needle,value);end
end
function value=resolveHashName(symbol,value,folder,group),if strlength(folder)==0,folder=string(getenv("CP2K_DATA_DIR"));end;if strlength(folder)>0&&isfile(fullfile(folder,symbol))&&strlength(value)==32,value=findHashName(fullfile(folder,symbol),value,group);end,end
function value=findMatchingName(file,kind,needle,fallback),text=string(fileread(file));if kind=="basis",anchor="basis_sets:";part=extractAfter(text,anchor);else,part=extractBefore(extractAfter(text,"potentials:"),"basis_sets:");end;matches=regexp(part,'(?m)^\s{4}name:\s*(\S+)','tokens');names=string(cellfun(@(x)x{1},matches,"UniformOutput",false));if isempty(names),value=fallback;elseif strlength(needle)>0&&any(contains(upper(names),upper(needle))),value=names(find(contains(upper(names),upper(needle)),1));else,value=names(1);end,end
function value=findHashName(file,hash,group),text=string(fileread(file));pos=strfind(text,hash+":");if isempty(pos),value=hash;return,end;stop=min(strlength(text),pos(1)+8000);block=extractBetween(text,pos(1),stop);n=regexp(block,'(?m)^\s{4}name:\s*(\S+)','tokens','once');if isempty(n),value=hash;else,value=string(n{1});end;if group=="potentials"&&contains(value,"SZV"),value=hash;end,end
function bases=collectBases(data),bases={};n=fieldnames(data);for i=1:numel(n),if isstruct(data.(n{i}))&&isfield(data.(n{i}),"basis"),bases{end+1}=data.(n{i}).basis;end,end,end
function out=flattenObjects(data),if isstruct(data),n=fieldnames(data);out={};for i=1:numel(n),if isobject(data.(n{i})),out{end+1}=data.(n{i});end,end;elseif iscell(data),out=data;else,out=num2cell(data);end,end
function sec=ensure(root,path),parts=split(string(path),"/");sec=root;for p=reshape(parts,1,[]),if strlength(p)==0||upper(p)==upper(sec.name),continue,end;next=sec.get_section(p);if isempty(next),next=kssolv.analysis.matgenlab.io.cp2k.Section(p);sec.insert(next);end;sec=next;end,end
function ensureNested(sec,path),ensure(sec,path);end
function sec=sectionWithOptions(name,varargin),sec=kssolv.analysis.matgenlab.io.cp2k.Section(name);for i=1:2:numel(varargin),sec.setitem(varargin{i},varargin{i+1});end,end
function value=propertyAt(props,name,index,default),if ~isfield(props,name),value=default;return,end;v=props.(name);if iscell(v),value=v{index};elseif isvector(v),value=v(index);else,value=v(index,:);end,end
function replaceOT(obj,minimizer,preconditioner,algorithm,linesearch),scf=ensure(obj,"FORCE_EVAL/DFT/SCF");scf.insert(kssolv.analysis.matgenlab.io.cp2k.OrbitalTransformation("MINIMIZER",minimizer,"PRECONDITIONER",preconditioner,"ALGORITHM",algorithm,"LINESEARCH",linesearch));end
function value=chooseHybridPotential(name,structure),if isa(structure,"kssolv.analysis.matgenlab.core.Molecule"),value="COULOMB";elseif upper(string(name))=="HSE06",value="SHORTRANGE";else,value="TRUNCATED";end,end
