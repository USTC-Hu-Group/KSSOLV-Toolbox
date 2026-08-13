classdef PackingWorkflowTemplate
    %PACKINGWORKFLOWTEMPLATE Explicit post-packing equilibration templates.
    methods (Static)
        function value=create(kind,options)
            arguments
                kind {mustBeTextScalar} = "density_ramp_npt"
                options.temperature (1,1) double {mustBePositive} = 300
                options.pressure (1,1) double {mustBePositive} = 1
                options.steps (1,1) double {mustBeInteger,mustBePositive} = 100000
            end
            kind=lower(string(kind));
            if ~any(kind==["density_ramp_npt","anneal_nvt","equilibrate_npt"])
                error("KSSOLV:Modeling:PackingWorkflow", ...
                    "Unknown packing workflow template '%s'.",kind);
            end
            value=struct("schemaVersion",1,"kind",kind, ...
                "temperatureKelvin",options.temperature, ...
                "pressureBar",options.pressure,"steps",options.steps, ...
                "inputState","packed_not_equilibrated", ...
                "completionState","equilibrated_only_after_success", ...
                "engine","unassigned");
        end
    end
end
