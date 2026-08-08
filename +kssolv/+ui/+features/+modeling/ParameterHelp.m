classdef ParameterHelp
    %PARAMETERHELP Collapsible technical guidance for Modeling dialogs.

    methods (Static)
        function value = describe(commandId)
            key = ...
                kssolv.ui.features.modeling.ParameterHelp.topic(commandId);
            value = struct( ...
                "key", key, "title", "", "text", "", ...
                "formula", "", "symbols", "");
            if key == ""
                return
            end
            value.title = kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:HelpTitle_" + key);
            value.text = kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:HelpText_" + key);
            if any(key == ...
                    kssolv.ui.features.modeling.ParameterHelp.formulaTopics())
                value.formula = kssolv.ui.util.Localizer.message( ...
                    "KSSOLV:modeling:HelpFormula_" + key);
                value.symbols = kssolv.ui.util.Localizer.message( ...
                    "KSSOLV:modeling:HelpSymbols_" + key);
            end
        end

        function keys = formulaTopics()
            keys = [
                "CenterAtoms"
                "MirrorAtoms"
                "RotateAtoms"
                "Strain"
                "EditLattice"
                "MirrorLattice"
                "BuildSupercell"
                "Nanotube"
                "Nanowire"
                "Slab"
                "AddVacuum"
                "NEB"
                ];
        end
    end

    methods (Static, Access = private)
        function key = topic(commandId)
            commandId = string(commandId);
            switch commandId
                case "center_atoms"
                    key = "CenterAtoms";
                case "merge_atoms"
                    key = "MergeAtoms";
                case "mirror_atoms"
                    key = "MirrorAtoms";
                case {"perturb_atoms", "perturb_structure"}
                    key = "Perturbation";
                case "rotate_atoms"
                    key = "RotateAtoms";
                case "translate_atoms"
                    key = "TranslationCoordinates";
                case {"apply_strain", "strain_structure"}
                    key = "Strain";
                case "edit_lattice"
                    key = "EditLattice";
                case "mirror_lattice"
                    key = "MirrorLattice";
                case "rotate_lattice"
                    key = "RotateLattice";
                case "swap_axes"
                    key = "SwapAxes";
                case "build_supercell"
                    key = "BuildSupercell";
                case "redefine_lattice"
                    key = "RedefineLattice";
                case "orthogonalize_cell"
                    key = "OrthogonalizeCell";
                case "create_point_defects"
                    key = "PointDefects";
                case "generate_sqs_model"
                    key = "SQS";
                case "roll_nanotube"
                    key = "Nanotube";
                case "cut_nanoribbon"
                    key = "Nanoribbon";
                case "cut_nanowire"
                    key = "Nanowire";
                case "quantum_dot_void"
                    key = "QuantumDotVoid";
                case "build_slab"
                    key = "Slab";
                case "add_vacuum"
                    key = "AddVacuum";
                case "stack_heterostructure"
                    key = "Heterostructure";
                case "twist_moire"
                    key = "Moire";
                case "interpolate_neb"
                    key = "NEB";
                case "find_adsorption_sites"
                    key = "AdsorptionSites";
                case "passivate_surface"
                    key = "Passivation";
                case "add_solvent_layer"
                    key = "SolventLayer";
                case {"find_symmetry", "primitive_cell", ...
                        "conventional_cell"}
                    key = "Symmetry";
                otherwise
                    key = "";
            end
        end
    end
end
