classdef MagnetismTest < matlab.unittest.TestCase
    %MAGNETISMTEST Frozen pymatgen magnetism acceptance and numerical oracles.
    methods (Test)
        function analyzerModesAndProperties(testCase)
            structure=niOAntiferromagnet();
            Analyzer=@kssolv.analysis.matgenlab.analysis.magnetism. ...
                CollinearMagneticStructureAnalyzer;
            analyzer=Analyzer(structure,"overwrite_magmom_mode","respect_sign");
            testCase.verifyEqual(string(analyzer.ordering),"AFM");
            testCase.verifyEqual(analyzer.magmoms,[-5,5,0,0]);
            testCase.verifyTrue(analyzer.is_magnetic);
            testCase.verifyEqual(analyzer.number_of_magnetic_sites,2);
            testCase.verifyEqual(analyzer.number_of_unique_magnetic_sites(),1);
            testCase.verifyEqual(string(analyzer.types_of_magnetic_species{1}),"Ni");
            testCase.verifyEqual(analyzer.magnetic_species_and_magmoms("Ni"),5);
            testCase.verifyTrue(analyzer.matches_ordering(structure));
            spinStructure=analyzer.get_structure_with_spin();
            testCase.verifyFalse(isfield(spinStructure.site_properties,"magmom"));
            testCase.verifyEqual(spinStructure(1).specie.spin,-5);
            magneticOnly=analyzer.get_structure_with_only_magnetic_atoms(false);
            testCase.verifyEqual(magneticOnly.num_sites,2);
            testCase.verifyFalse(isfield( ...
                analyzer.get_nonmagnetic_structure(false).site_properties,"magmom"));
            testCase.verifyEqual( ...
                analyzer.get_ferromagnetic_structure(false).site_properties.magmom, ...
                num2cell([5,5,0,0]));

            unphysical=structure.copy();
            unphysical=unphysical.add_site_property("magmom",[-3,0,0,0]);
            testCase.verifyEqual(Analyzer(unphysical).magmoms,[3,0,0,0]);
            testCase.verifyEqual(Analyzer(unphysical, ...
                "overwrite_magmom_mode","respect_sign").magmoms,[-5,0,0,0]);
            testCase.verifyEqual(Analyzer(unphysical, ...
                "overwrite_magmom_mode","respect_zeros").magmoms,[5,0,0,0]);
            testCase.verifyEqual(Analyzer(unphysical, ...
                "overwrite_magmom_mode","replace_all", ...
                "make_primitive",false).magmoms,[5,5,0,0]);
            testCase.verifyEqual(Analyzer(unphysical, ...
                "overwrite_magmom_mode","normalize").magmoms,[1,0,0,0]);
        end

        function deformationFrozenOracle(testCase)
            data=jsondecode(fileread(fullfile(magnetismFixtureRoot(), ...
                "magnetic_deformation.json")));
            first=kssolv.analysis.matgenlab.core.Structure.from_dict(data(1));
            second=kssolv.analysis.matgenlab.core.Structure.from_dict(data(2));
            result=kssolv.analysis.matgenlab.analysis.magnetism. ...
                magnetic_deformation(first,second);
            testCase.verifyEqual(result.type,"NM-FM");
            testCase.verifyEqual(result.deformation,5.0130859485170971, ...
                AbsTol=2e-12);
        end

        function jahnTellerSpeciesAndStructureOracle(testCase)
            Analyzer=kssolv.analysis.matgenlab.analysis.magnetism. ...
                JahnTellerAnalyzer();
            expected=["weak","weak","none","strong","weak","none","weak", ...
                "weak","none","weak","strong","none","strong","none"];
            inputs={
                "Ti3+","","oct";"V3+","","oct";"Cr3+","","oct";
                "Mn3+","high","oct";"Mn3+","low","oct";
                "Fe3+","high","oct";"Fe3+","low","oct";
                "Fe2+","high","oct";"Fe2+","low","oct";
                "Co2+","high","oct";"Co2+","low","oct";
                "Ni2+","","oct";"Cu2+","","oct";"Zn2+","","oct"};
            actual=strings(1,size(inputs,1));
            for index=1:size(inputs,1)
                actual(index)=Analyzer.get_magnitude_of_effect_from_species( ...
                    inputs{index,1},inputs{index,2},inputs{index,3});
            end
            testCase.verifyEqual(actual,expected);
            testCase.verifyEqual(Analyzer.mu_so("Co4+","oct","low"),sqrt(3), ...
                AbsTol=1e-14);
            testCase.verifyEqual(Analyzer.mu_so("Co4+","oct","high"),sqrt(35), ...
                AbsTol=1e-14);
            testCase.verifyEmpty(Analyzer.mu_so("Na+","oct","high"));

            structure=fixtureStructure("LiFePO4.json");
            analysis=Analyzer.get_analysis(structure);
            testCase.verifyTrue(analysis.active);
            testCase.verifyEqual(analysis.strength,"weak");
            site=analysis.sites{1};
            testCase.verifyEqual(site.motif,"oct");
            testCase.verifyEqual(site.motif_order_parameter,.1441,AbsTol=1e-12);
            testCase.verifyEqual(site.ligand_bond_length_spread,.2111, ...
                AbsTol=1e-12);
            testCase.verifyEqual(sort(site.ligand_bond_lengths), ...
                sort([2.2951,2.2215,2.2383,2.1382,2.084,2.0863]));
            testCase.verifyEqual(site.site_indices,[5,6,7,8]);
            testCase.verifyTrue(Analyzer.is_jahn_teller_active( ...
                fixtureStructure("Fe3O4.json")));
            tagged=Analyzer.tag_structure(structure);
            testCase.verifyEqual(nnz(cellfun(@logical, ...
                tagged.site_properties.possible_jt_active)),4);
        end

        function heisenbergFrozenOracle(testCase)
            [structures,energies]=mn3AlFixture();
            mapper=kssolv.analysis.matgenlab.analysis.magnetism. ...
                HeisenbergMapper(structures,energies,5,.02);
            testCase.verifyNumElements(mapper.sgraphs,7);
            testCase.verifyEqual(mapper.unique_site_ids("1,2"),0);
            testCase.verifyEqual(mapper.dists.nn,2.51,AbsTol=1e-12);
            exchange=mapper.get_exchange();
            testCase.verifyEqual(exchange("0-1-nn"), ...
                18.052116895702852,AbsTol=1e-8);
            average=mapper.estimate_exchange();
            testCase.verifyEqual(average,52.54997149705518,AbsTol=1e-9);
            testCase.verifyEqual(mapper.get_mft_temperature(average), ...
                292.90252668100584,AbsTol=1e-6);
            graph=mapper.get_interaction_graph();
            testCase.verifyEqual(length(graph),6);
            testCase.verifyEqual(graph.graph.number_of_edges(),112);
            model=mapper.get_heisenberg_model();
            testCase.verifyEqual(string(model.formula),"Mn3Al");
            restored=kssolv.analysis.matgenlab.analysis.magnetism. ...
                HeisenbergModel.from_dict(model.as_dict());
            twice=kssolv.analysis.matgenlab.analysis.magnetism. ...
                HeisenbergModel.from_dict(restored.as_dict());
            testCase.verifyEqual(restored.ex_mat,twice.ex_mat);
        end

        function nativeOrderingEnumeration(testCase)
            lattice=kssolv.analysis.matgenlab.core.Lattice.cubic(4.17);
            structure=kssolv.analysis.matgenlab.core.Structure. ...
                from_spacegroup(225,lattice,{"Ni","O"}, ...
                [0,0,0;.5,.5,.5]);
            enumerator=kssolv.analysis.matgenlab.analysis.magnetism. ...
                MagneticStructureEnumerator(structure, ...
                "truncate_by_symmetry",false,"max_orderings",8);
            testCase.verifyEqual(enumerator.ordered_structure_origins, ...
                ["fm","afm"]);
            testCase.verifyNumElements(enumerator.ordered_structures,2);
        end

        function frozenApiAudit(testCase)
            classes=["Ordering","OverwriteMagmomMode", ...
                "CollinearMagneticStructureAnalyzer", ...
                "MagneticStructureEnumerator","MagneticDeformation", ...
                "HeisenbergMapper","HeisenbergScreener","HeisenbergModel", ...
                "JahnTellerAnalyzer"];
            package="kssolv.analysis.matgenlab.analysis.magnetism.";
            for name=classes
                testCase.verifyNotEmpty(meta.class.fromName(package+name),name);
            end
            testCase.verifyNotEmpty(which(package+"magnetic_deformation"));
            analyzer=meta.class.fromName(package+ ...
                "CollinearMagneticStructureAnalyzer");
            expected=["get_structure_with_spin", ...
                "get_structure_with_only_magnetic_atoms", ...
                "get_nonmagnetic_structure","get_ferromagnetic_structure", ...
                "number_of_unique_magnetic_sites","get_exchange_group_info", ...
                "matches_ordering"];
            testCase.verifyTrue(all(ismember(expected,string({analyzer.MethodList.Name}))));
            properties=["is_magnetic","magmoms","types_of_magnetic_species", ...
                "types_of_magnetic_specie","magnetic_species_and_magmoms", ...
                "number_of_magnetic_sites","ordering"];
            testCase.verifyTrue(all(ismember(properties, ...
                string({analyzer.PropertyList.Name}))));
        end
    end
end

function root=magnetismFixtureRoot()
root=fullfile(fileparts(mfilename("fullpath")),"+fixtures","+magnetism");
end
function structure=fixtureStructure(name)
structure=kssolv.analysis.matgenlab.core.Structure.from_dict( ...
    jsondecode(fileread(fullfile(magnetismFixtureRoot(),name))));
end
function structure=niOAntiferromagnet()
lattice=kssolv.analysis.matgenlab.core.Lattice( ...
    [2.085,2.085,0;0,0,-4.17;-2.085,2.085,0]);
structure=kssolv.analysis.matgenlab.core.Structure(lattice, ...
    {"Ni","Ni","O","O"},[.5,.5,.5;0,0,0;0,.5,0;.5,0,.5], ...
    "site_properties",struct(magmom=[-5,5,0,0]));
end
function [structures,energies]=mn3AlFixture()
data=jsondecode(fileread(fullfile(magnetismFixtureRoot(),"Mn3Al.json")));
names=fieldnames(data.structure);structures=cell(1,numel(names));
energies=zeros(1,numel(names));
for index=1:numel(names)
    structures{index}=kssolv.analysis.matgenlab.core.Structure. ...
        from_dict(data.structure.(names{index}));
    energies(index)=data.energy_per_atom.(names{index})* ...
        structures{index}.num_sites;
end
end
