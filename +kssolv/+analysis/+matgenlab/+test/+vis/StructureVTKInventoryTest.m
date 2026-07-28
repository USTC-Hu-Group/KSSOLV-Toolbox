classdef StructureVTKInventoryTest < matlab.unittest.TestCase
    %STRUCTUREVTKINVENTORYTEST Frozen native graphics parity coverage.

    methods (Test)
        function frozenInventoryHasAllThirtyEightApis(testCase)
            package="kssolv.analysis.matgenlab.vis.";
            classes=["StructureVis","StructureInteractorStyle", ...
                "MultiStructuresVis","MultiStructuresInteractorStyle"];
            specifications={
                "StructureVis",["rotate_view","write_image","redraw", ...
                    "orthogonalize_structure","display_help", ...
                    "set_structure","zoom","show","add_site", ...
                    "add_partial_sphere","add_text","add_line", ...
                    "add_polyhedron","add_triangle","add_faces", ...
                    "add_edges","add_bonds","add_picker_fixed", ...
                    "add_picker"]
                "StructureInteractorStyle", ...
                    ["leftButtonPressEvent","mouseMoveEvent", ...
                    "leftButtonReleaseEvent","keyPressEvent"]
                "MultiStructuresVis",["set_structures","set_structure", ...
                    "apply_tags","set_animated_movie_options", ...
                    "display_help","display_warning","erase_warning", ...
                    "display_info","erase_info"]
                "MultiStructuresInteractorStyle","keyPressEvent"
                };
            memberCount=sum(cellfun(@numel,specifications(:,2)));
            testCase.verifyEqual(numel(classes)+memberCount+1,38);
            for name=classes
                testCase.verifyNotEmpty(meta.class.fromName(package+name));
            end
            for index=1:size(specifications,1)
                testCase.verifyMembers(package+specifications{index,1}, ...
                    string(specifications{index,2}));
            end
            testCase.verifyNotEmpty(which(package+"make_movie"));
            oracle=testCase.oracle();
            testCase.verifyEqual(oracle.metadata.api_count,38);
            testCase.verifyEqual(string(oracle.metadata.tag),"v2026.5.4");
        end

        function headlessStructureSceneMatchesFrozenOracle(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.vis.*
            oracle=testCase.oracle();
            structure=Structure(Lattice.cubic(4), ...
                {"Na","Cl"},[0,0,0;.5,.5,.5]);
            vis=StructureVis([],true,false,false);
            testCase.addTeardown(@()delete(vis));
            testCase.verifyEqual(string(vis.figure_handle.Visible),"off");
            vis.set_structure(structure);
            testCase.verifyEqual(vis.title, ...
                string(oracle.cubic_nacl_scene.formula));
            testCase.verifyEqual(numel(vis.scene), ...
                oracle.cubic_nacl_scene.scene_count);
            kinds=cellfun(@(item)string(item.kind),vis.scene);
            names=fieldnames(oracle.cubic_nacl_scene.kind_counts);
            for index=1:numel(names)
                testCase.verifyEqual(nnz(kinds==names{index}), ...
                    oracle.cubic_nacl_scene.kind_counts.(names{index}));
            end
            testCase.verifyEqual(vis.camera_state.position, ...
                reshape(oracle.cubic_nacl_scene.camera_position,1,[]), ...
                AbsTol=1e-12);
            testCase.verifyEqual(vis.camera_state.target, ...
                reshape(oracle.cubic_nacl_scene.camera_target,1,[]), ...
                AbsTol=1e-12);
            testCase.verifyEqual(vis.camera_state.up, ...
                reshape(oracle.cubic_nacl_scene.camera_up,1,[]), ...
                AbsTol=1e-12);
            testCase.verifyTrue(all(isgraphics(vis.graphics_handles)));
        end

        function siteAndSphereGeometryIsDeterministic(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.vis.*
            oracle=testCase.oracle();
            structure=Structure(Lattice.cubic(4), ...
                {"Na+","Cl-"},[0,0,0;.5,.5,.5]);
            first=StructureVis([],false,false,false);
            second=StructureVis([],false,false,false);
            testCase.addTeardown(@()delete(first));
            testCase.addTeardown(@()delete(second));
            first.show_help=false;
            second.show_help=false;
            first.set_structure(structure);
            second.set_structure(structure);
            firstKinds=cellfun(@(item)string(item.kind),first.scene);
            siteRecords=first.scene(firstKinds=="site");
            sphereRecords=first.scene(firstKinds=="partial_sphere");
            testCase.verifyEqual(siteRecords{1}.radius, ...
                oracle.site_geometry.Na_plus_visual_radius, ...
                AbsTol=1e-14);
            testCase.verifyEqual(siteRecords{2}.radius, ...
                oracle.site_geometry.Cl_minus_visual_radius, ...
                AbsTol=1e-14);
            expectedColor= ...
                reshape(oracle.vesta_colors_255.Na,1,[])/255;
            testCase.verifyEqual(sphereRecords{1}.color, ...
                expectedColor,AbsTol=1e-14);
            secondKinds=cellfun(@(item)string(item.kind),second.scene);
            secondSphere=second.scene(secondKinds=="partial_sphere");
            testCase.verifyEqual(sphereRecords{1}.x, ...
                secondSphere{1}.x,AbsTol=0);

            handle=first.add_partial_sphere([1,2,3],2, ...
                [1,0,0],0,180,.5);
            testCase.verifyTrue(isgraphics(handle));
            record=first.scene{end};
            testCase.verifyEqual(size(record.x), ...
                reshape(oracle.partial_sphere.grid_size,1,[]));
            samples=[record.x(10,[1,10,19]).', ...
                record.y(10,[1,10,19]).', ...
                record.z(10,[1,10,19]).'];
            testCase.verifyEqual(samples, ...
                oracle.partial_sphere.equator_samples,AbsTol=1e-12);
        end

        function nativePrimitiveGeometryCoversAllAddMethods(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.vis.*
            vis=StructureVis([],false,false,false);
            testCase.addTeardown(@()delete(vis));
            vis.show_help=false;
            vis.redraw();
            center=Site("Fe",[0,0,0]);
            neighbors={Site("O",[1,0,0]),Site("O",[0,1,0]), ...
                Site("O",[0,0,1]),Site("O",[-1,-1,-1])};
            vis.add_text([0,0,0],"origin");
            vis.add_line([0,0,0],[1,1,1],[.2,.3,.4],3);
            poly=vis.add_polyhedron(neighbors,center,"element", ...
                .6,true,[0,0,0],1.5);
            testCase.verifyTrue(isgraphics(poly));
            triangle=vis.add_triangle([1,0,0;0,1,0;0,0,1], ...
                "element",center,.4,true);
            testCase.verifyTrue(isgraphics(triangle));
            faces=vis.add_faces({[0,0,0;1,0,0;0,1,0], ...
                [0,0,0;1,0,0;1,1,0;0,1,0]},[0,0,1],.3);
            testCase.verifyNumElements(faces,2);
            edges=vis.add_edges({[0,0,0;1,0,0], ...
                [0,0,0;0,1,0]},"line",2,[0,0,0]);
            testCase.verifyNumElements(edges,2);
            bonds=vis.add_bonds(neighbors,center,[.5,.5,.5],.8,.1);
            testCase.verifyNumElements(bonds,4);
            vis.add_picker_fixed();
            testCase.verifyEqual(vis.picker,"fixed");
            vis.add_picker();
            testCase.verifyEqual(vis.picker,"floating");
            kinds=cellfun(@(item)string(item.kind),vis.scene);
            for kind=["text","line","polyhedron","triangle", ...
                    "face","edges","bonds"]
                testCase.verifyTrue(any(kinds==kind));
            end
            faceRecords=vis.scene(kinds=="face");
            testCase.verifyEqual(size(faceRecords{1}.faces,1),1);
            testCase.verifyEqual(size(faceRecords{2}.faces,1),4);
        end

        function graphicsLifecycleAndImageExportAreHeadless(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.vis.*
            structure=Structure(Lattice( ...
                [3,0,0;1,3,0;0,0,4]),{"Si"},[0,0,0]);
            vis=StructureVis([],true,false,false);
            testCase.addTeardown(@()delete(vis));
            vis.set_structure(structure);
            before=vis.camera_state;
            vis.rotate_view(0,30);
            testCase.verifyNotEqual(vis.camera_state.up,before.up);
            angle=vis.camera_state.view_angle;
            vis.zoom(1.2);
            testCase.verifyLessThan(vis.camera_state.view_angle,angle);
            vis.redraw(true);
            vis.orthogonalize_structure();
            testCase.verifyEqual(vis.structure.formula,structure.formula);
            filename=string(tempname)+".png";
            testCase.addTeardown(@()testCase.deleteFile(filename));
            vis.write_image(filename,2,"png");
            info=dir(filename);
            testCase.verifyGreaterThan(info.bytes,1000);
            image=imread(filename);
            testCase.verifyEqual(size(image,3),3);
            vis.show();
            testCase.verifyEqual(string(vis.figure_handle.Visible),"on");
            vis.figure_handle.Visible="off";
        end

        function interactorCallbacksMatchKeyboardSemantics(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.vis.*
            structure=Structure(Lattice.cubic(4), ...
                {"Na","Cl"},[0,0,0;.5,.5,.5]);
            vis=StructureVis([],true,false,false);
            testCase.addTeardown(@()delete(vis));
            vis.set_structure(structure);
            style=vis.interactor_style;
            style.leftButtonPressEvent([],[]);
            testCase.verifyEqual(style.mouse_motion,0);
            style.mouseMoveEvent([],[]);
            testCase.verifyEqual(style.mouse_motion,1);
            style.leftButtonReleaseEvent([],[]);
            style.keyPressEvent([],"A");
            testCase.verifyEqual(vis.supercell(1,1),2);
            style.keyPressEvent([],"a");
            testCase.verifyEqual(vis.supercell(1,1),1);
            polyhedra=vis.show_polyhedron;
            style.keyPressEvent([],"#");
            testCase.verifyEqual(vis.show_polyhedron,~polyhedra);
            bonds=vis.show_bonds;
            style.keyPressEvent([],"-");
            testCase.verifyEqual(vis.show_bonds,~bonds);
            help=vis.show_help;
            style.keyPressEvent([],"h");
            testCase.verifyEqual(vis.show_help,~help);
            tolerance=vis.poly_radii_tol_factor;
            style.keyPressEvent([],"]");
            testCase.verifyEqual(vis.poly_radii_tol_factor, ...
                tolerance+.05,AbsTol=1e-15);
            style.keyPressEvent([],"[");
            testCase.verifyEqual(vis.poly_radii_tol_factor, ...
                tolerance,AbsTol=1e-15);
            style.keyPressEvent([],"uparrow");
            style.keyPressEvent([],"leftarrow");
            style.keyPressEvent([],"r");
        end

        function multiStructureTagsNavigationAndMessages(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.vis.*
            first=Structure(Lattice.cubic(4), ...
                {"Na","Cl"},[0,0,0;.5,.5,.5]);
            second=first.translate_sites(1,[.1,0,0]);
            tag=struct("istruct","all","site_index",1, ...
                "cell_index",[0,0,0],"radius_factor",2, ...
                "color",[1,0,0],"opacity",.25);
            vis=MultiStructuresVis([],true,false,false);
            testCase.addTeardown(@()delete(vis));
            vis.set_structures({first,second},{tag});
            testCase.verifyEqual(vis.istruct,1);
            kinds=cellfun(@(item)string(item.kind),vis.scene);
            testCase.verifyTrue(any(kinds=="tag"));
            tagRecord=vis.scene{find(kinds=="tag",1)};
            testCase.verifyEqual(tagRecord.radius, ...
                2*vis.all_vis_radii{1}(1),AbsTol=1e-14);
            style=vis.interactor_style;
            style.keyPressEvent([],"n");
            testCase.verifyEqual(vis.istruct,2);
            testCase.verifyEqual(vis.current_structure,second);
            style.keyPressEvent([],"n");
            testCase.verifyEqual(vis.warning_txt, ...
                "WARNING : LAST STRUCTURE");
            testCase.verifyEqual( ...
                string(vis.warning_txt_actor.Visible),"on");
            vis.erase_warning();
            testCase.verifyEqual( ...
                string(vis.warning_txt_actor.Visible),"off");
            style.keyPressEvent([],"p");
            testCase.verifyEqual(vis.istruct,1);
            style.keyPressEvent([],"p");
            testCase.verifyEqual(vis.warning_txt, ...
                "WARNING : FIRST STRUCTURE");
            vis.display_info("fixture");
            testCase.verifyEqual(vis.info_txt,"INFO : fixture");
            testCase.verifyEqual(string(vis.info_txt_actor.Visible),"on");
            vis.erase_info();
            testCase.verifyEqual(string(vis.info_txt_actor.Visible),"off");
        end

        function movieOptionsAnimationAndWriterAreNative(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.vis.*
            first=Structure(Lattice.cubic(4), ...
                {"Na","Cl"},[0,0,0;.5,.5,.5]);
            second=first.translate_sites(1,[.1,0,0]);
            vis=MultiStructuresVis([],false,false,false);
            testCase.addTeardown(@()delete(vis));
            vis.set_structures({first,second});
            defaults=vis.DEFAULT_ANIMATED_MOVIE_OPTIONS;
            testCase.verifyEqual(vis.animated_movie_options,defaults);
            testCase.verifyError(@()vis.set_animated_movie_options( ...
                struct("wrong",1)), ...
                "KSSOLV:Matgenlab:MultiStructuresVis:MovieOption");
            invalid=defaults;
            invalid.looping_type="invalid";
            vis.set_animated_movie_options(invalid);
            testCase.verifyError(@()vis.interactor_style. ...
                keyPressEvent([],"m"), ...
                "KSSOLV:Matgenlab:MultiStructuresVis:LoopingType");
            options=struct("time_between_frames",0, ...
                "looping_type","palindrome","number_of_loops",1, ...
                "time_between_loops",0);
            vis.set_animated_movie_options(options);
            vis.interactor_style.keyPressEvent([],"m");
            testCase.verifyEqual(vis.info_txt, ...
                "INFO : Ended animated movie ...");

            filename=string(tempname)+".avi";
            testCase.addTeardown(@()testCase.deleteFile(filename));
            make_movie({first,second},filename,1,2,"1000k",80, ...
                "show_polyhedron",false);
            info=dir(filename);
            testCase.verifyGreaterThan(info.bytes,10000);
            testCase.verifyError(@()make_movie({},filename), ...
                "KSSOLV:Matgenlab:StructureVis:EmptyMovie");
        end

        function officialFixtureRendersWithoutVtk(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.vis.*
            oracle=testCase.oracle();
            structure=Structure.from_file( ...
                testCase.fixture("LiFePO4.cif"));
            testCase.verifyEqual(structure.num_sites, ...
                oracle.official_fixture.num_sites);
            testCase.verifyEqual(structure.formula, ...
                string(oracle.official_fixture.formula));
            vis=StructureVis([],true,false,false);
            testCase.addTeardown(@()delete(vis));
            vis.show_help=false;
            vis.set_structure(structure);
            kinds=cellfun(@(item)string(item.kind),vis.scene);
            testCase.verifyEqual(nnz(kinds=="site"), ...
                structure.num_sites);
            testCase.verifyEqual(nnz(kinds=="partial_sphere"), ...
                structure.num_sites);
            testCase.verifyEqual(nnz(kinds=="line"),15);
        end

        function invalidGeometryAndInputsRaiseStableErrors(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.vis.*
            vis=StructureVis([],false,false,false);
            testCase.addTeardown(@()delete(vis));
            testCase.verifyError(@()vis.zoom(0), ...
                "KSSOLV:Matgenlab:StructureVis:Zoom");
            testCase.verifyError(@()vis.write_image( ...
                "unused.png",0), ...
                "KSSOLV:Matgenlab:StructureVis:Magnification");
            testCase.verifyError(@()vis.add_partial_sphere( ...
                [0,0,0],-1,[1,0,0]), ...
                "KSSOLV:Matgenlab:StructureVis:Radius");
            testCase.verifyError(@()vis.add_partial_sphere( ...
                [0,0,0],1,[2,0,0],0,360,1.2), ...
                "KSSOLV:Matgenlab:StructureVis:Opacity");
            testCase.verifyError(@()vis.add_line( ...
                [0,0],[1,1,1]), ...
                "KSSOLV:Matgenlab:StructureVis:Point");
            testCase.verifyError(@()vis.add_faces( ...
                {[0,0,0;1,0,0]},[1,0,0]), ...
                "KSSOLV:Matgenlab:StructureVis:Face");
            testCase.verifyError(@()vis.add_triangle( ...
                [0,0,0;1,0,0;0,1,0],"element"), ...
                "KSSOLV:Matgenlab:StructureVis:TriangleCenter");
            testCase.verifyError(@()vis.add_polyhedron( ...
                [0,0,0;1,0,0;0,1,0], ...
                Site("Fe",[0,0,0]),[1,0,0]), ...
                "KSSOLV:Matgenlab:StructureVis:Polyhedron");
            multi=MultiStructuresVis();
            testCase.addTeardown(@()delete(multi));
            testCase.verifyError(@()multi.set_structures({}), ...
                "KSSOLV:Matgenlab:MultiStructuresVis:Empty");
            testCase.verifyError(@() ...
                StructureInteractorStyle([]), ...
                "KSSOLV:Matgenlab:StructureInteractor:Parent");
        end
    end

    methods (Static,Access=private)
        function value=oracle()
            value=jsondecode(fileread(fullfile(pwd,"dev", ...
                "matgenlab","oracles", ...
                "structure_vtk_2026.5.4.json")));
        end

        function value=fixture(name)
            folder=fileparts(mfilename("fullpath"));
            value=fullfile(folder,"+fixtures","structure_vtk",name);
        end

        function deleteFile(path)
            if isfile(path),delete(path);end
        end

        function verifyMembers(className,expected)
            metadata=meta.class.fromName(className);
            available=[string({metadata.MethodList.Name}), ...
                string({metadata.PropertyList.Name})];
            if ~all(ismember(expected,available))
                error("KSSOLV:Matgenlab:StructureVTK:Inventory", ...
                    "Missing members in %s: %s",className, ...
                    strjoin(expected(~ismember(expected,available)),", "));
            end
        end
    end
end
