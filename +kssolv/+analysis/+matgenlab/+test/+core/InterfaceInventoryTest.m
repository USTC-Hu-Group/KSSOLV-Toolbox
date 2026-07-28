classdef InterfaceInventoryTest < matlab.unittest.TestCase
    methods (Test)
        function officialInterfaceFixtureMatches(testCase)
            import kssolv.analysis.matgenlab.core.*
            value=Interface.from_dict(interfaceFixture());
            testCase.verifyEqual(value.num_sites,50);
            testCase.verifyEqual(numel(value.substrate_indices),14);
            testCase.verifyEqual(numel(value.film_indices),36);
            testCase.verifyEqual(numel(value.substrate_sites),14);
            testCase.verifyEqual(numel(value.film_sites),36);
            testCase.verifyEqual(value.substrate.num_sites,14);
            testCase.verifyEqual(value.film.num_sites,36);
            testCase.verifyEqual(value.in_plane_offset,[0,0]);
            testCase.verifyEqual(value.gap,2);
            testCase.verifyEqual(value.vacuum_over_film,20);
            testCase.verifyEqual(value.substrate_termination,"Si_P6/mmm_7");
            testCase.verifyEqual(value.film_termination,"O2_P6/mmm_4");
            testCase.verifyEqual(value.substrate_layers,2);
            testCase.verifyEqual(value.film_layers,6);
            testCase.verifySize(value.get_shifts_based_on_adsorbate_sites(), ...
                [42,2]);
            testCase.verifySize( ...
                value.get_shifts_based_on_adsorbate_sites(20),[1,2]);
            restored=Interface.from_dict(value.as_dict());
            copied=value.copy();
            testCase.verifyEqual(restored.lattice.matrix, ...
                value.lattice.matrix,AbsTol=1e-12);
            testCase.verifyEqual(restored.frac_coords, ...
                value.frac_coords,AbsTol=1e-12);
            testCase.verifyEqual(copied.frac_coords, ...
                value.frac_coords,AbsTol=1e-12);
            testCase.verifyClass(value.get_sorted_structure(), ...
                "kssolv.analysis.matgenlab.core.Structure");
        end

        function interfaceSettersPreserveGeometry(testCase)
            import kssolv.analysis.matgenlab.core.*
            value=Interface.from_dict(interfaceFixture());
            substrate=value.substrate_indices;
            film=value.film_indices;
            substrateCartesian=value.cart_coords(substrate,:);
            oldFilmFractional=value.frac_coords(film,1:2);
            value.in_plane_offset=[.25,.4];
            testCase.verifyEqual(value.in_plane_offset,[.25,.4]);
            expected=mod(oldFilmFractional+[.25,.4],1);
            testCase.verifyEqual(value.frac_coords(film,1:2), ...
                expected,AbsTol=1e-10);
            testCase.verifyEqual(value.cart_coords(substrate,:), ...
                substrateCartesian,AbsTol=1e-10);

            oldC=value.lattice.lengths(3);
            oldCartesian=value.cart_coords;
            normal=planeNormal(value.lattice.matrix);
            value.gap=3.25;
            testCase.verifyEqual(value.lattice.lengths(3), ...
                oldC+1.25,AbsTol=1e-10);
            testCase.verifyEqual(value.cart_coords(substrate,:), ...
                oldCartesian(substrate,:),AbsTol=1e-9);
            displacement=value.cart_coords(film,:)-oldCartesian(film,:);
            testCase.verifyEqual(displacement, ...
                repmat(1.25*normal,numel(film),1),AbsTol=1e-9);

            oldC=value.lattice.lengths(3);
            oldCartesian=value.cart_coords;
            value.vacuum_over_film=22.5;
            testCase.verifyEqual(value.lattice.lengths(3), ...
                oldC+2.5,AbsTol=1e-10);
            testCase.verifyEqual(value.cart_coords,oldCartesian,AbsTol=1e-9);
            testCase.verifyError(@() setNegativeGap(value), ...
                "KSSOLV:Matgenlab:Interface:Gap");
            testCase.verifyError(@() setNegativeVacuum(value), ...
                "KSSOLV:Matgenlab:Interface:Vacuum");
            testCase.verifyError(@() setBadShift(value), ...
                "KSSOLV:Matgenlab:Interface:Shift");
        end

        function officialCslDeterminantsMatch(testCase)
            import kssolv.analysis.matgenlab.core.*
            transform=[.5,.5,0;0,.5,.5;.5,0,.5];
            cases={ ...
                {[1,2,3],123.74898859588858,"c",[],20,transform,9}; ...
                {[1,1,1],147.36310249644626,"h",[5,2],20,eye(3),19}; ...
                {[1,1,1],151.92751306414706,"t",[2,3],10,eye(3),17}; ...
                {[1,1,1],131.5023374652235,"o", ...
                    [21,20,5],10,eye(3),83}; ...
                {[1,2,0],63.310675060280246,"r", ...
                    [19,5],5,eye(3),59}};
            for index=1:numel(cases)
                item=cases{index};
                [first,second]=GrainBoundaryGenerator.get_trans_mat( ...
                    item{1},item{2},lat_type=item{3},ratio=item{4}, ...
                    max_search=item{5},trans_cry=item{6});
                testCase.verifyEqual(abs(det(first)),item{7}, ...
                    AbsTol=1e-8);
                testCase.verifyEqual(abs(det(second)),item{7}, ...
                    AbsTol=1e-8);
            end
        end

        function officialBoundaryVolumesAndPlanesMatch(testCase)
            import kssolv.analysis.matgenlab.core.*
            primitive=readBoundaryFixture("Cu_mp-30_primitive.cif");
            generator=GrainBoundaryGenerator(primitive);
            boundary=generator.gb_from_parameters( ...
                [1,2,3],123.74898859588858,expand_times=2,rm_ratio=0);
            testCase.verifyEqual(boundary.volume/primitive.volume,36, ...
                AbsTol=1e-8);
            testCase.verifyEqual(boundary.sigma,9);

            conventional=readBoundaryFixture( ...
                "Cu_mp-30_conventional_standard.cif");
            generator=GrainBoundaryGenerator(conventional);
            boundary=generator.gb_from_parameters( ...
                [1,2,3],123.74898859588858,expand_times=2, ...
                plane=[1,3,1],rm_ratio=0);
            transform=boundary.lattice.matrix/conventional.lattice.matrix;
            testCase.verifyEqual(transform(1:2,:)*[1;3;1], ...
                [0;0],AbsTol=1e-8);

            normalBoundary=GrainBoundaryGenerator(primitive). ...
                gb_from_parameters([1,2,3],123.74898859588858, ...
                expand_times=2,normal=true,rm_ratio=0);
            matrix=normalBoundary.lattice.matrix;
            normal=planeNormal(matrix);
            testCase.verifyEqual(norm(cross(matrix(3,:),normal)),0, ...
                AbsTol=1e-8);
        end

        function ratiosEnumerationsAndHelpersMatch(testCase)
            import kssolv.analysis.matgenlab.core.*
            be=GrainBoundaryGenerator(readBoundaryFixture( ...
                "Be_mp-87_conventional_standard.cif"));
            pa=GrainBoundaryGenerator(readBoundaryFixture( ...
                "Pa_mp-62_conventional_standard.cif"));
            br=GrainBoundaryGenerator(readBoundaryFixture( ...
                "Br_mp-23154_conventional_standard.cif"));
            bi=GrainBoundaryGenerator(readBoundaryFixture( ...
                "Bi_mp-23152_primitive.cif"));
            testCase.verifyEqual(be.get_ratio(2),[5,2]);
            testCase.verifyEqual(be.get_ratio(5),[12,5]);
            testCase.verifyEqual(pa.get_ratio(5),[2,3]);
            testCase.verifyEqual(br.get_ratio(5),[21,20,5]);
            testCase.verifyEqual(bi.get_ratio(5),[19,5]);

            testCase.verifyEqual( ...
                GrainBoundaryGenerator.vec_to_surface([1,.5,0]),[2,1,0]);
            testCase.verifyEqual(GrainBoundaryGenerator.reduce_mat( ...
                2*eye(3),2,eye(3)),[1,-4,-4;0,2,0;0,0,2]);
            testCase.verifyEqual(GrainBoundaryGenerator.slab_from_csl( ...
                eye(3),[0,0,1],false,eye(3)),eye(3));
            equivalents=kssolv.analysis.matgenlab.core. ...
                symm_group_cubic([1,0,0;1,1,0]);
            testCase.verifySize(equivalents,[18,3]);
            [first,second]=GrainBoundaryGenerator.get_trans_mat( ...
                [1,1,1],95.55344419565849,lat_type="o", ...
                ratio=[10,20,21],surface=[21,20,10],normal=true);
            testCase.verifyEqual(first(1:2,:)*[21;20;10], ...
                [0;0],AbsTol=1e-8);
            testCase.verifyEqual(det(first),det(second),AbsTol=1e-8);
            testCase.verifyEqual(norm(cross(first(3,:),[1,1,1])), ...
                0,AbsTol=1e-8);
            testCase.verifyEqual( ...
                GrainBoundaryGenerator.get_rotation_angle_from_sigma( ...
                41,[1,0,0],lat_type="o",ratio=[270,30,29]), ...
                [12.680383491819821,167.3196165081802],AbsTol=1e-8);
            testCase.verifyEqual( ...
                GrainBoundaryGenerator.get_rotation_angle_from_sigma( ...
                6,[1,0,0],lat_type="o",ratio=[270,30,29]), ...
                [36.86989764584403,143.13010235415598],AbsTol=1e-8);
            testCase.verifyError(@() ...
                GrainBoundaryGenerator.vec_to_surface([1,pi,0]), ...
                "KSSOLV:Matgenlab:GrainBoundary:Vector");

            planes=GrainBoundaryGenerator.enum_possible_plane_cubic( ...
                4,[1,1,1],60);
            testCase.verifyEqual(numel(planes.Twist),1);
            testCase.verifyEqual(numel(planes.Symmetric_tilt),6);
            testCase.verifyEqual(numel(planes.Normal_tilt),12);
            testCase.verifyEqual(numel(planes.Mixed),54);

            structure=kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice.cubic(3), ...
                {"Si","Si"},[-1e-9,1,1.2;.5,.5,-.2]);
            wrapped=kssolv.analysis.matgenlab.core.fix_pbc(structure);
            testCase.verifyGreaterThanOrEqual(wrapped.frac_coords,0);
            testCase.verifyLessThan(wrapped.frac_coords,1);
        end
    end
end

function value=interfaceFixture()
root=fileparts(fileparts(mfilename("fullpath")));
value=jsondecode(fileread(fullfile(root,"+fixtures","+core", ...
    "Si_SiO2_Interface.json")));
end

function structure=readBoundaryFixture(name)
root=fileparts(fileparts(mfilename("fullpath")));
parser=kssolv.analysis.matgenlab.io.cif.CifParser(fullfile( ...
    root,"+fixtures","+core","grain_boundary",name));
values=parser.parse_structures();
structure=values{1};
end

function normal=planeNormal(matrix)
normal=cross(matrix(1,:),matrix(2,:));
normal=normal/norm(normal);
if dot(normal,matrix(3,:))<0,normal=-normal;end
end

function setNegativeGap(value)
value.gap=-1;
end

function setNegativeVacuum(value)
value.vacuum_over_film=-1;
end

function setBadShift(value)
value.in_plane_offset=[1,2,3];
end
