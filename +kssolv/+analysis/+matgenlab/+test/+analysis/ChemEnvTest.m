classdef ChemEnvTest < matlab.unittest.TestCase
    %CHEMENVTEST Frozen pymatgen ChemEnv acceptance and numerical oracles.
    methods (Test)
        function geometryRegistryAndAlgorithms(testCase)
            import kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.*
            registry=AllCoordinationGeometries();
            testCase.verifyNumElements(registry.cg_list,68);
            octahedron=registry.get_geometry_from_mp_symbol("O:6");
            testCase.verifyEqual(octahedron.coordination_number,6);
            testCase.verifyEqual(octahedron.number_of_permutations,3);
            restored=CoordinationGeometry.from_dict(octahedron.as_dict());
            testCase.verifyEqual(restored.mp_symbol,"O:6");
            testCase.verifyEqual(restored.points,octahedron.points,AbsTol=1e-14);
            meshes=octahedron.get_pmeshes(octahedron.points);
            testCase.verifyGreaterThan(strlength(meshes{1}.pmesh_string),700);
        end

        function structureEnvironmentFixtureAndStrategies(testCase)
            import kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.*
            se=fixtureStructureEnvironments();
            testCase.verifyNumElements(se.neighbors_sets{7}(4),1);
            testCase.verifyEqual(se.get_csm(7,"T:4").symmetry_measure, ...
                0.0098877842405411,AbsTol=1e-14);

            simplest=SimplestChemenvStrategy(se);
            simple=simplest.get_site_coordination_environment( ...
                se.structure.sites{7});
            testCase.verifyEqual(simple{1},"T:4");

            multi=MultiWeightsChemenvStrategy. ...
                stats_article_weights_parameters();
            multi.set_structure_environments(se);
            fractions=multi.get_site_coordination_environments_fractions( ...
                se.structure.sites{7});
            testCase.verifyEqual(fractions{1}.ce_symbol,"T:4");
            testCase.verifyEqual(fractions{1}.ce_fraction,1,AbsTol=1e-14);

            abundance=SimpleAbundanceChemenvStrategy(se);
            abundant=abundance.get_site_coordination_environment( ...
                se.structure.sites{7});
            testCase.verifyEqual(abundant{1},"A:2");
            targeted=TargetedPenaltiedAbundanceChemenvStrategy(se, ...
                "target_environments",{"T:4"},"max_csm",1);
            target=targeted.get_site_coordination_environment( ...
                se.structure.sites{7});
            testCase.verifyEqual(target{1},"T:4");
        end

        function voronoiMapsAndSerialization(testCase)
            import kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.*
            se=fixtureStructureEnvironments();
            entries=se.voronoi.maps_and_surfaces(7, ...
                "additional_conditions",1);
            maps=cellfun(@(x)x.map,entries,"UniformOutput",false);
            testCase.verifyEqual(maps,{[1 1],[2 1],[2 2],[4 1],[6 1]});
            testCase.verifyEqual(entries{4}.surface,0.987485,RelTol=2e-5);
            restored=DetailedVoronoiContainer.from_dict(se.voronoi.as_dict());
            testCase.verifyTrue(restored.is_close_to(se.voronoi));
            testCase.verifyNumElements(restored.neighbors(7,1.4,.3),4);
        end

        function perfectGeometryContinuousSymmetryMeasure(testCase)
            import kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.*
            finder=LocalGeometryFinder("only_symbols",{"T:4"});
            finder.setup_test_perfect_environment("T:4", ...
                "indices","RANDOM","random_translation","RANDOM", ...
                "random_rotation","RANDOM","random_scale","RANDOM");
            measures=finder.get_coordination_symmetry_measures();
            testCase.verifyTrue(isKey(measures,"T:4"));
            testCase.verifyLessThan(measures("T:4").csm,1e-20);

            rotation=[0 -1 0;1 0 0;0 0 1];
            registry=AllCoordinationGeometries("only_symbols",{"T:4"});
            cg=registry.get_geometry_from_mp_symbol("T:4");
            distorted=transpose(rotation*transpose(cg.points)*2);
            result=symmetry_measure(distorted,cg.points);
            testCase.verifyEqual(result.symmetry_measure,0,AbsTol=1e-20);
            testCase.verifyEqual(result.scaling_factor,.5,AbsTol=1e-14);
        end

        function lightEnvironmentsAndConnectivity(testCase)
            import kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.*
            import kssolv.analysis.matgenlab.analysis.chemenv.connectivity.*
            se=fixtureStructureEnvironments();
            strategy=SimplestChemenvStrategy(se);
            lse=LightStructureEnvironments.from_structure_environments( ...
                strategy,se,"valences","undefined");
            testCase.verifyEqual( ...
                lse.coordination_environments{7}{1}.ce_symbol,"T:4");
            connectivity=ConnectivityFinder().get_structure_connectivity(lse);
            graph=connectivity.environment_subgraph( ...
                "environments_symbols",{"T:4"});
            testCase.verifyNumElements(graph.nodes,3);
            components=connectivity.get_connected_components( ...
                "environments_symbols",{"T:4"});
            testCase.verifyNumElements(components,1);
            testCase.verifyEqual(components{1}.periodicity,3);
        end

        function oneDimensionalCoordinationSequence(testCase)
            import kssolv.analysis.matgenlab.analysis.chemenv.connectivity.*
            lattice=kssolv.analysis.matgenlab.core.Lattice.cubic(5);
            structure=kssolv.analysis.matgenlab.core.Structure( ...
                lattice,{"Si"},[0 0 0]);
            node=EnvironmentNode(structure.sites{1},1,"T:4");
            edge=struct("u",1,"v",1,"start",1,"end",1, ...
                "delta",[1 0 0],"ligands",{{}});
            component=ConnectedComponent.from_graph( ...
                struct(nodes={{node}},edges=edge));
            testCase.verifyTrue(component.is_1d);
            sequence=component.coordination_sequence(node,"path_size",4);
            testCase.verifyEqual(cell2mat(sequence),[2 2 2 2]);
            supergraph=component.make_supergraph(4);
            testCase.verifyNumElements(supergraph.nodes,4);
        end
    end
end

function value=fixtureStructureEnvironments()
path=fullfile(fileparts(mfilename("fullpath")),"+fixtures", ...
    "+chemenv","structure_environments","se_mp-7000.json");
data=jsondecode(fileread(path));
value=kssolv.analysis.matgenlab.analysis.chemenv. ...
    coordination_environments.StructureEnvironments.from_dict(data);
end
