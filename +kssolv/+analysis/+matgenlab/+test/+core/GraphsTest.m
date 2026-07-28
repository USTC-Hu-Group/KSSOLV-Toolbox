classdef GraphsTest < matlab.unittest.TestCase
    methods (Test)
        function periodicEdgesImagesAndSupercell(testCase)
            structure=kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice.tetragonal(5,50), ...
                {"H"},[0,0,0]);
            graph=kssolv.analysis.matgenlab.core.StructureGraph. ...
                from_empty_graph(structure,"edge_weight_name","", ...
                "edge_weight_units","");
            graph.add_edge(1,1,"to_jimage",[1,0,0]);
            graph.add_edge(1,1,"to_jimage",[-1,0,0]);
            graph.add_edge(1,1,"to_jimage",[0,1,0]);
            graph.add_edge(1,1,"to_jimage",[0,-1,0]);
            testCase.verifyEqual(graph.graph.number_of_edges(),2);
            testCase.verifyEqual(graph.get_coordination_of_site(1),4);
            connected=graph.get_connected_sites(1,[0,0,100]);
            testCase.verifyTrue(all(cellfun(@(x)x.jimage(3)==100,connected)));

            supercell=graph*[2,1,1];
            testCase.verifyEqual(supercell.structure.num_sites,2);
            testCase.verifyEqual(supercell.graph.number_of_edges(),4);
            testCase.verifyEqual([supercell.get_coordination_of_site(1), ...
                supercell.get_coordination_of_site(2)],[4,4]);
            roundtrip=kssolv.analysis.matgenlab.core.StructureGraph. ...
                from_dict(supercell.as_dict());
            testCase.verifyEqual(roundtrip,supercell);
        end

        function edgeEditingAndLocalEnvironment(testCase)
            structure=kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice.cubic(4.2), ...
                {"Cs","Cl"},[0,0,0;.5,.5,.5]);
            strategy=kssolv.analysis.matgenlab.core.MinimumDistanceNN();
            graph=strategy.get_bonded_structure(structure);
            testCase.verifyEqual(graph.graph.number_of_edges(),8);
            testCase.verifyEqual(graph.get_coordination_of_site(1),8);
            edge=graph.graph.edges(1);
            graph.alter_edge(edge.from_index,edge.to_index, ...
                "to_jimage",edge.to_jimage,"new_weight",2, ...
                "new_edge_properties",struct(kind="bond"));
            testCase.verifyEqual(graph.graph.edges(1).weight,2);
            testCase.verifyEqual(graph.graph.edges(1).edge_properties.kind,"bond");
            graph.break_edge(edge.from_index,edge.to_index, ...
                "to_jimage",edge.to_jimage);
            testCase.verifyEqual(graph.graph.number_of_edges(),7);
        end

        function moleculeFragmentsRingsAndMSON(testCase)
            coordinates=[cos((0:5)'*pi/3),sin((0:5)'*pi/3),zeros(6,1)];
            molecule=kssolv.analysis.matgenlab.core.Molecule( ...
                repmat({"C"},1,6),coordinates);
            edges=[1,2;2,3;3,4;4,5;5,6;6,1];
            graph=kssolv.analysis.matgenlab.core.MoleculeGraph. ...
                from_edges(molecule,edges);
            rings=graph.find_rings(1);
            testCase.verifyNumElements(rings,1);
            testCase.verifyEqual(size(rings{1},1),6);
            testCase.verifyTrue(graph.isomorphic_to( ...
                kssolv.analysis.matgenlab.core.MoleculeGraph. ...
                from_dict(graph.as_dict())));

            fragments=graph.split_molecule_subgraphs([1,2;4,5]);
            testCase.verifyNumElements(fragments,2);
            testCase.verifyEqual(sort(cellfun(@length,fragments)),[3,3]);
            testCase.verifyError(@()graph.split_molecule_subgraphs([1,2]), ...
                "KSSOLV:Matgenlab:MolGraphSplitError");
        end

        function covalentBondedPathAndGraphHash(testCase)
            molecule=kssolv.analysis.matgenlab.core.Molecule( ...
                {"H","H"},[0,0,0;.75,0,0]);
            graph=kssolv.analysis.matgenlab.core.CovalentBondNN( ...
                "order",false).get_bonded_structure(molecule);
            testCase.verifyEqual(graph.graph.number_of_edges(),1);
            connected=graph.get_connected_sites(1);
            testCase.verifyEqual(connected{1}.dist,.75, ...
                AbsTol=1e-12);

            store=kssolv.analysis.matgenlab.core.GraphStore(4);
            store.add_edge(1,2,"edge_properties",struct(label="A"));
            store.add_edge(2,3,"edge_properties",struct(label="A"));
            store.add_edge(3,1,"edge_properties",struct(label="A"));
            store.add_edge(1,4,"edge_properties",struct(label="B"));
            testCase.verifyEqual(kssolv.analysis.matgenlab.util. ...
                weisfeiler_lehman_graph_hash(store,"edge_attr","label"), ...
                "c653d85538bcf041d88c011f4f905f10");
            hashes=kssolv.analysis.matgenlab.util. ...
                weisfeiler_lehman_subgraph_hashes(store, ...
                "iterations",3,"digest_size",8);
            testCase.verifyEqual(numel(hashes(1)),3);
        end
    end
end
