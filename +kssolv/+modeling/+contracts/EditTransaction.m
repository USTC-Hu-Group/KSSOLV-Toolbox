classdef EditTransaction < handle
    %EDITTRANSACTION Revision-guarded preview and atomic modeling commit.

    % A transaction owns defensive copies only.  Creating one computes a
    % preview without mutating the document model.  Commit succeeds exactly
    % once and only while the document revision still matches BaseRevision.

    properties (SetAccess = private)
        Id string
        CommandId string
        Parameters struct
        BaseRevision (1,1) double
        State string = "preview"
    end

    properties (Access = private)
        PreviewResult struct
    end

    methods
        function this = EditTransaction( ...
                model, revision, commandId, parameters)
            arguments
                model
                revision (1,1) double {mustBeInteger, mustBeNonnegative}
                commandId {mustBeTextScalar}
                parameters (1,1) struct = struct()
            end
            this.Id = string(matlab.lang.internal.uuid);
            this.CommandId = string(commandId);
            this.Parameters = parameters;
            this.BaseRevision = revision;
            this.PreviewResult = ...
                kssolv.modeling.CommandExecutor.execute( ...
                model, this.CommandId, parameters);
        end

        function result = preview(this)
            this.requireState("preview");
            result = this.copyResult(this.PreviewResult);
        end

        function result = commit(this, currentRevision)
            arguments
                this
                currentRevision (1,1) double ...
                    {mustBeInteger, mustBeNonnegative}
            end
            this.requireState("preview");
            if currentRevision ~= this.BaseRevision
                error("KSSOLV:Modeling:StaleTransaction", ...
                    "The model changed after this preview was created. " + ...
                    "Create a new preview before applying the command.");
            end
            result = this.copyResult(this.PreviewResult);
            this.State = "committed";
            this.PreviewResult = struct();
        end

        function cancel(this)
            this.requireState("preview");
            this.State = "cancelled";
            this.PreviewResult = struct();
        end
    end

    methods (Access = private)
        function requireState(this, expected)
            if this.State ~= expected
                error("KSSOLV:Modeling:TransactionState", ...
                    "Transaction '%s' is already %s.", ...
                    this.Id, this.State);
            end
        end

        function result = copyResult(~, source)
            result = source;
            if isfield(result, "model") && ~isempty(result.model)
                result.model = result.model.copy();
            end
            if isfield(result, "models") && ~isempty(result.models)
                models = result.models;
                if iscell(models)
                    for index = 1:numel(models)
                        models{index} = models{index}.copy();
                    end
                else
                    for index = 1:numel(models)
                        models(index) = models(index).copy();
                    end
                end
                result.models = models;
            end
        end
    end
end
