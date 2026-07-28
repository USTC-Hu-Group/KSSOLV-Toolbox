function multi = ebands_input(structure, pseudos, varargin)
o=struct("kppa",1000,"nscf_nband",[],"ndivsm",15,"ecut",[],"pawecutdg",[],"scf_nband",[],"accuracy","normal","spin_mode","polarized","smearing","fermi_dirac:0.1 eV","charge",0,"scf_algorithm",[],"dos_kppa",[]);
for i=1:2:numel(varargin),o.(char(string(varargin{i})))=varargin{i+1};end
if isempty(o.kppa),o.kppa=1000;end
nExtra=numel(o.dos_kppa);if isempty(o.dos_kppa),nExtra=0;end
multi=kssolv.analysis.matgenlab.io.abinit.BasicMultiDataset(structure,pseudos,"ndtset",max(1,2+nExtra));
if isempty(o.ecut),error("KSSOLV:Matgenlab:Abinit:Cutoff","ecut is required when pseudopotentials provide no hints.");end
multi.set_vars("ecut",o.ecut);if ~isempty(o.pawecutdg),multi.set_vars("pawecutdg",o.pawecutdg);end
elec=kssolv.analysis.matgenlab.io.abinit.Electrons(o.spin_mode,o.smearing,o.scf_algorithm,o.scf_nband,[],o.charge);
if isempty(elec.nband)
    nv=kssolv.analysis.matgenlab.io.abinit.num_valence_electrons(multi(1).structure,multi.pseudos)-o.charge;
    if isempty(elec.smearing)||elec.smearing.occopt==1,nb=max(ceil(nv/2*1.1),nv/2+4);else,nb=max(ceil(nv/2*1.2),nv/2+10);end
    elec.nband=ceil(nb/2)*2;
end
ks=kssolv.analysis.matgenlab.io.abinit.KSampling.automatic_density(multi(1).structure,o.kppa,"chksymbreak",0);
multi(1).set_vars(ks.to_abivars());multi(1).set_vars(elec.to_abivars());multi(1).set_vars("tolvrs",1e-8);
if o.ndivsm==0
    if multi.ndtset>1,multi=kssolv.analysis.matgenlab.io.abinit.BasicMultiDataset.from_inputs({multi(1)});end
    return
end
nscf=elec.nband+10;if ~isempty(o.nscf_nband),nscf=o.nscf_nband;end
multi(2).set_kpath(o.ndivsm);multi(2).set_spin_mode(o.spin_mode);multi(2).set_vars("nband",nscf,"iscf",-2,"charge",o.charge,"tolwfr",1e-17);
for i=1:nExtra
    kdos=kssolv.analysis.matgenlab.io.abinit.KSampling.automatic_density(multi(i+2).structure,o.dos_kppa(i),"chksymbreak",0);
    multi(i+2).set_vars(kdos.to_abivars());multi(i+2).set_spin_mode(o.spin_mode);multi(i+2).set_vars("nband",nscf,"iscf",-2,"charge",o.charge,"tolwfr",1e-17);
end
end
