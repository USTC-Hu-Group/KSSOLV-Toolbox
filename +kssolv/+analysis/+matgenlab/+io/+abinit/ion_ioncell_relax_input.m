function multi=ion_ioncell_relax_input(structure,pseudos,varargin)
o=struct("kppa",1000,"nband",[],"ecut",[],"pawecutdg",[],"accuracy","normal","spin_mode","polarized","smearing","fermi_dirac:0.1 eV","charge",0,"scf_algorithm",[],"shift_mode","Monkhorst-pack");
for i=1:2:numel(varargin),o.(char(string(varargin{i})))=varargin{i+1};end
base=kssolv.analysis.matgenlab.io.abinit.gs_input(structure,pseudos,"kppa",o.kppa,"ecut",o.ecut,"pawecutdg",o.pawecutdg,"scf_nband",o.nband,"accuracy",o.accuracy,"spin_mode",o.spin_mode,"smearing",o.smearing,"charge",o.charge,"scf_algorithm",o.scf_algorithm);
multi=kssolv.analysis.matgenlab.io.abinit.BasicMultiDataset.replicate_input(base,2);
multi(1).set_vars(kssolv.analysis.matgenlab.io.abinit.RelaxationMethod.atoms_only().to_abivars());multi(1).set_vars("tolrff",0.02);
multi(2).set_vars(kssolv.analysis.matgenlab.io.abinit.RelaxationMethod.atoms_and_cell().to_abivars());multi(2).set_vars("tolrff",0.02);
end
