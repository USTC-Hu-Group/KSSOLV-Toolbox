classdef RemoteBackend < handle
    %REMOTEBACKEND Common lifecycle contract for remote execution modes.

    properties (SetAccess = immutable)
        ExecutionMode (1, 1) string
    end

    methods
        function this = RemoteBackend(executionMode)
            arguments
                executionMode (1, 1) string
            end
            if ~any(executionMode == ...
                    kssolv.services.remote.config.RemoteConfiguration.ExecutionModes)
                error("KSSOLV:Remote:InvalidExecutionMode", ...
                    "Unsupported remote execution mode %s.", executionMode);
            end
            this.ExecutionMode = executionMode;
        end

        function record = submitWorkflow(~, ~, ~, record, ~)
            unsupported(record, "submitWorkflow");
        end

        function record = submitFunction(~, ~, record, varargin)
            unsupported(record, "submitFunction");
        end

        function record = refresh(~, ~, record)
            unsupported(record, "refresh");
        end

        function record = cancel(~, ~, record)
            unsupported(record, "cancel");
        end

        function [outputs, record] = fetch(~, ~, record)
            outputs = {};
            unsupported(record, "fetch");
        end

        function cleanup(~, ~, ~)
        end

        function varargout = testConnection(~, ~, ~) %#ok<STOUT>
            error("KSSOLV:Remote:BackendOperationUnsupported", ...
                "This backend does not implement testConnection.");
        end
    end
end

function unsupported(record, operation)
mode = "Unknown";
if isstruct(record) && isfield(record, "ExecutionMode")
    mode = string(record.ExecutionMode);
end
error("KSSOLV:Remote:BackendOperationUnsupported", ...
    "Remote %s backend does not implement %s.", mode, operation);
end
