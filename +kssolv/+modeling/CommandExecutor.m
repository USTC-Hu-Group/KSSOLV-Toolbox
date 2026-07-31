classdef CommandExecutor
    %COMMANDEXECUTOR Validate and execute a modeling command transaction.

    methods (Static)
        function result = execute(model, commandId, parameters)
            arguments
                model
                commandId {mustBeTextScalar}
                parameters (1,1) struct = struct()
            end
            if ~isa(model, ...
                    "kssolv.analysis.matgenlab.core.IStructure")
                error("KSSOLV:Modeling:CrystalRequired", ...
                    "This modeling command currently requires a crystal structure.");
            end

            commandId = string(commandId);
            if ~kssolv.modeling.CommandExecutor.supports(commandId)
                error("KSSOLV:Modeling:NotImplemented", ...
                    "The modeling command '%s' is not implemented yet.", ...
                    commandId);
            end

            workingCopy = model.copy();
            if kssolv.modeling.AtomicEditorCommands.supports(commandId)
                result = kssolv.modeling.AtomicEditorCommands.execute( ...
                    workingCopy, commandId, parameters);
            elseif kssolv.modeling.LatticeEditorCommands.supports(commandId)
                result = kssolv.modeling.LatticeEditorCommands.execute( ...
                    workingCopy, commandId, parameters);
            elseif kssolv.modeling.SupercellCommands.supports(commandId)
                result = kssolv.modeling.SupercellCommands.execute( ...
                    workingCopy, commandId, parameters);
            elseif kssolv.modeling.DefectCommands.supports(commandId)
                result = kssolv.modeling.DefectCommands.execute( ...
                    workingCopy, commandId, parameters);
            elseif kssolv.modeling.SurfaceCommands.supports(commandId)
                result = kssolv.modeling.SurfaceCommands.execute( ...
                    workingCopy, commandId, parameters);
            elseif kssolv.modeling.NanostructureCommands.supports(commandId)
                result = kssolv.modeling.NanostructureCommands.execute( ...
                    workingCopy, commandId, parameters);
            else
                result = kssolv.modeling.SymmetryCommands.execute( ...
                    workingCopy, commandId, parameters);
            end
            result.commandId = commandId;
        end

        function value = supports(commandId)
            commandId = string(commandId);
            value = ...
                kssolv.modeling.AtomicEditorCommands.supports(commandId) || ...
                kssolv.modeling.LatticeEditorCommands.supports(commandId) || ...
                kssolv.modeling.SupercellCommands.supports(commandId) || ...
                kssolv.modeling.DefectCommands.supports(commandId) || ...
                kssolv.modeling.SurfaceCommands.supports(commandId) || ...
                kssolv.modeling.NanostructureCommands.supports(commandId) || ...
                kssolv.modeling.SymmetryCommands.supports(commandId);
        end

        function ids = supportedCommandIds()
            ids = [
                kssolv.modeling.AtomicEditorCommands.commandIds()
                kssolv.modeling.LatticeEditorCommands.commandIds()
                kssolv.modeling.SupercellCommands.commandIds()
                kssolv.modeling.DefectCommands.commandIds()
                kssolv.modeling.SurfaceCommands.commandIds()
                kssolv.modeling.NanostructureCommands.commandIds()
                kssolv.modeling.SymmetryCommands.commandIds()
                ];
        end
    end
end
