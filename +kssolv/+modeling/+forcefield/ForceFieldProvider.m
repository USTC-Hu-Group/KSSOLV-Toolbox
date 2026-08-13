classdef ForceFieldProvider
    %FORCEFIELDPROVIDER Validation boundary for pluggable energy models.
    %
    % Evaluators receive (model, coordinates) and must return a scalar
    % state with finite energy and N-by-3 gradient values. The contract
    % keeps GeometryOptimizer independent of a particular implementation
    % while rejecting incomplete or mislabeled external models.

    properties (Constant)
        SchemaVersion = 1
    end

    methods (Static)
        function state = evaluate(model, coordinates, evaluator)
            arguments
                model
                coordinates double
                evaluator = []
            end
            if isempty(evaluator)
                evaluator = @(value, points) ...
                    kssolv.modeling.forcefield. ...
                    MolecularMechanicsForceField.evaluate(value, points);
            end
            if ~isa(evaluator, "function_handle")
                error("KSSOLV:Modeling:ForceFieldEvaluator", ...
                    "ForceFieldEvaluator must be a function handle.");
            end
            state = evaluator(model, coordinates);
            kssolv.modeling.forcefield. ...
                ForceFieldProvider.validateState(state, model.num_sites);
        end

        function validateState(state, atomCount)
            arguments
                state
                atomCount (1,1) double {mustBeNonnegative, mustBeInteger}
            end
            required = ["parameterSet", "source", "isEnergyModel", ...
                "energy", "energyUnit", "gradient", "gradientUnit", ...
                "fallbackCount", "termEnergy", "termCount", "limitations"];
            if ~isstruct(state) || ~isscalar(state)
                error("KSSOLV:Modeling:ForceFieldContract", ...
                    "A force-field evaluator must return a scalar struct.");
            end
            missing = required(~isfield(state, required));
            if ~isempty(missing)
                error("KSSOLV:Modeling:ForceFieldContract", ...
                    "Force-field result is missing: %s.", ...
                    strjoin(missing, ", "));
            end
            if ~isscalar(state.energy) || ~isnumeric(state.energy) || ...
                    ~isfinite(state.energy)
                error("KSSOLV:Modeling:ForceFieldContract", ...
                    "Force-field energy must be a finite numeric scalar.");
            end
            if ~islogical(state.isEnergyModel) || ...
                    ~isscalar(state.isEnergyModel) || ~state.isEnergyModel
                error("KSSOLV:Modeling:ForceFieldContract", ...
                    "Force-field result must explicitly identify an energy model.");
            end
            if ~isnumeric(state.fallbackCount) || ...
                    ~isscalar(state.fallbackCount) || ...
                    ~isfinite(state.fallbackCount) || ...
                    state.fallbackCount < 0 || ...
                    state.fallbackCount ~= fix(state.fallbackCount)
                error("KSSOLV:Modeling:ForceFieldContract", ...
                    "Force-field fallbackCount must be a nonnegative integer.");
            end
            if ~isstruct(state.termEnergy) || ~isscalar(state.termEnergy) || ...
                    ~isstruct(state.termCount) || ~isscalar(state.termCount)
                error("KSSOLV:Modeling:ForceFieldContract", ...
                    "Force-field term energy and count data must be scalar structs.");
            end
            if ~isnumeric(state.gradient) || ...
                    ~isequal(size(state.gradient), [atomCount, 3]) || ...
                    any(~isfinite(state.gradient), "all")
                error("KSSOLV:Modeling:ForceFieldContract", ...
                    "Force-field gradient must be a finite N-by-3 array.");
            end
            textFields = ["parameterSet", "source", ...
                "energyUnit", "gradientUnit"];
            for field = textFields
                value = string(state.(field));
                if ~isscalar(value) || ismissing(value) || strlength(value) == 0
                    error("KSSOLV:Modeling:ForceFieldContract", ...
                        "Force-field %s must be nonempty text.", field);
                end
            end
        end
    end
end
