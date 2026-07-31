classdef CommandCatalog
    %COMMANDCATALOG Declarative AtomKit-compatible modeling command catalog.

    methods (Static)
        function categories = categories()
            categories = [
                category("atomic_editor", "AtomicEditor", [
                    command("add_atom", "AddAtom")
                    command("center_atoms", "CenterAtoms")
                    command("delete_atoms", "DeleteAtoms")
                    command("merge_atoms", "MergeAtoms")
                    command("fix_atoms", "FixAtoms")
                    command("mirror_atoms", "MirrorAtoms")
                    command("move_atoms", "MoveAtoms")
                    command("perturb_atoms", "PerturbAtoms")
                    command("sort_atoms", "SortAtoms")
                    command("rotate_atoms", "RotateAtoms")
                    command("substitute_atoms", "SubstituteAtoms")
                    command("translate_atoms", "TranslateAtoms")
                    ])
                category("lattice_editor", "LatticeEditor", [
                    command("apply_strain", "ApplyStrain")
                    command("edit_lattice", "EditLattice")
                    command("mirror_lattice", "MirrorLattice")
                    command("rotate_lattice", "RotateLattice")
                    command("swap_axes", "SwapAxes")
                    ])
                category("supercell_lattice", "SupercellLattice", [
                    command("build_supercell", "BuildSupercell")
                    command("redefine_lattice", "RedefineLattice")
                    command("orthogonalize_cell", "OrthogonalizeCell")
                    command("strain_structure", "StrainStructure")
                    command("perturb_structure", "PerturbStructure")
                    ])
                category("defects_alloys", "DefectsAlloys", [
                    command("create_point_defects", "CreatePointDefects")
                    command("generate_sqs_model", "GenerateSQSModel")
                    ])
                category("nanostructures", "Nanostructures", [
                    command("roll_nanotube", "RollNanotube")
                    command("cut_nanoribbon", "CutNanoribbon")
                    command("cut_nanowire", "CutNanowire")
                    command("quantum_dot_void", "QuantumDotVoid")
                    ])
                category("surfaces_interfaces", "SurfacesInterfaces", [
                    command("build_slab", "BuildSlab")
                    command("add_vacuum", "AddVacuum")
                    command("insert_structure", "InsertStructure")
                    command("stack_heterostructure", "StackHeterostructure")
                    command("twist_moire", "TwistMoire")
                    command("interpolate_neb", "InterpolateNEB")
                    command("find_adsorption_sites", "FindAdsorptionSites")
                    command("passivate_surface", "PassivateSurface")
                    command("add_solvent_layer", "AddSolventLayer")
                    ])
                category("symmetry_tools", "SymmetryTools", [
                    command("find_symmetry", "FindSymmetry")
                    command("primitive_cell", "PrimitiveCell")
                    command("conventional_cell", "ConventionalCell")
                    command("wigner_seitz_cell", "WignerSeitzCell")
                    ])
                ];

            function value = category(id, key, commands)
                value = struct( ...
                    "id", string(id), ...
                    "labelKey", "KSSOLV:modeling:" + key, ...
                    "commands", commands);
            end

            function value = command(id, key)
                value = struct( ...
                    "id", string(id), ...
                    "labelKey", "KSSOLV:modeling:" + key, ...
                    "tooltipKey", "KSSOLV:modeling:" + key + "Tooltip");
            end
        end

        function commandInfo = find(commandId)
            commandId = string(commandId);
            categories = kssolv.modeling.CommandCatalog.categories();
            for categoryIndex = 1:numel(categories)
                commands = categories(categoryIndex).commands;
                position = find([commands.id] == commandId, 1);
                if ~isempty(position)
                    commandInfo = commands(position);
                    commandInfo.categoryId = categories(categoryIndex).id;
                    return
                end
            end
            error("KSSOLV:Modeling:UnknownCommand", ...
                "Unknown modeling command '%s'.", commandId);
        end

        function ids = commandIds()
            categories = kssolv.modeling.CommandCatalog.categories();
            ids = strings(0, 1);
            for categoryIndex = 1:numel(categories)
                ids = [ids; reshape( ...
                    [categories(categoryIndex).commands.id], [], 1)]; %#ok<AGROW>
            end
        end
    end
end
