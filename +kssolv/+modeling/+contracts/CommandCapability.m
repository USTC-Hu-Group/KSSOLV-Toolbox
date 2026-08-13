classdef CommandCapability
    %COMMANDCAPABILITY Declarative applicability for modeling commands.
    %
    % The capability contract is deliberately independent of the desktop UI.
    % CommandExecutor and every presentation surface use the same model-kind
    % decision so an unavailable action is disabled before execution.

    methods (Static)
        function value = forCommand(commandId)
            commandId = string(commandId);
            if ~isscalar(commandId) || commandId == ""
                error("KSSOLV:Modeling:CapabilityCommand", ...
                    "A scalar modeling command identifier is required.");
            end
            % Validate that the identifier belongs to the public catalog.
            kssolv.modeling.CommandCatalog.find(commandId);

            sharedGeometryCommands = [ ...
                "measure_geometry", "set_distance", "set_angle", ...
                "set_dihedral", "align_geometry"];
            sharedCommands = [ ...
                "add_atom", "center_atoms", "delete_atoms", ...
                "mirror_atoms", "move_atoms", "perturb_atoms", ...
                "rotate_atoms", "substitute_atoms", "translate_atoms", ...
                sharedGeometryCommands];
            moleculeGeometryCommands = setdiff( ...
                reshape(kssolv.modeling.geometry. ...
                    MolecularGeometryCommands.commandIds(), 1, []), ...
                sharedGeometryCommands, "stable");
            moleculeOnlyCommands = [ ...
                reshape(kssolv.modeling.chemistry. ...
                    MoleculeChemistryCommands.commandIds(), 1, []), ...
                moleculeGeometryCommands, ...
                reshape(kssolv.modeling.fragments. ...
                    FragmentCommands.commandIds(), 1, []), ...
                reshape(kssolv.modeling.polymers. ...
                    PolymerCommands.commandIds(), 1, []), ...
                reshape(kssolv.modeling.packing. ...
                    PackingCommands.commandIds(), 1, [])];
            if any(commandId == [ ...
                    "pack_into_existing_box","pack_around_nanoparticle"])
                modelKinds = "crystal";
            elseif any(commandId == sharedCommands)
                modelKinds = ["crystal", "molecule"];
            elseif any(commandId == moleculeOnlyCommands)
                modelKinds = "molecule";
            else
                modelKinds = "crystal";
            end

            [minimumSelection, maximumSelection] = selectionBounds(commandId);
            commandResultKind = resultKind(commandId);
            value = struct( ...
                "commandId", commandId, ...
                "modelKinds", modelKinds, ...
                "minimumSelection", minimumSelection, ...
                "maximumSelection", maximumSelection, ...
                "supportsPreview", commandResultKind == "model", ...
                "resultKind", commandResultKind);

            function [minimum, maximum] = selectionBounds(id)
                switch id
                    case {"delete_atoms", "substitute_atoms", ...
                            "translate_atoms", ...
                            "center_atoms", "mirror_atoms", ...
                            "rotate_atoms"}
                        minimum = 1;
                        maximum = Inf;
                    case "fix_atoms"
                        minimum = 0;
                        maximum = Inf;
                    case "move_atoms"
                        minimum = 1;
                        maximum = 1;
                    case {"add_bond", "delete_bond", "set_bond_order", ...
                            "set_distance"}
                        minimum = 2;
                        maximum = 2;
                    case "set_angle"
                        minimum = 3;
                        maximum = 3;
                    case "set_dihedral"
                        minimum = 4;
                        maximum = 4;
                    case {"set_atom_chemistry", "attach_fragment"}
                        minimum = 1;
                        maximum = Inf;
                    otherwise
                        minimum = 0;
                        maximum = Inf;
                end
            end

            function kind = resultKind(id)
                if id == "interpolate_neb"
                    kind = "collection";
                elseif any(id == ["find_adsorption_sites", ...
                        "locate_adsorbate", ...
                        "diagnose_molecule", "measure_geometry", ...
                        "find_symmetry", "wigner_seitz_cell", ...
                        "enumerate_point_defects"])
                    kind = "analysis";
                else
                    kind = "model";
                end
            end
        end

        function kind = modelKind(model)
            if isa(model, "kssolv.analysis.matgenlab.core.IStructure")
                kind = "crystal";
            elseif isa(model, "kssolv.analysis.matgenlab.core.IMolecule")
                kind = "molecule";
            else
                kind = "unsupported";
            end
        end

        function [supported, reason] = supportsModel(commandId, model)
            capability = ...
                kssolv.modeling.contracts.CommandCapability. ...
                forCommand(commandId);
            kind = ...
                kssolv.modeling.contracts.CommandCapability.modelKind(model);
            supported = any(capability.modelKinds == kind);
            if supported
                reason = "";
            elseif kind == "unsupported"
                reason = "Modeling commands require a crystal or molecule.";
            else
                reason = sprintf("Command '%s' does not support %s models.", ...
                    commandId, kind);
            end
        end

        function validateModel(commandId, model)
            [supported, reason] = ...
                kssolv.modeling.contracts.CommandCapability. ...
                supportsModel(commandId, model);
            if ~supported
                error("KSSOLV:Modeling:UnsupportedModelKind", "%s", reason);
            end
        end
    end
end
