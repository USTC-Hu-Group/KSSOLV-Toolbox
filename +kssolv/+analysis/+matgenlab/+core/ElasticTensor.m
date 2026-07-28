classdef ElasticTensor < ...
        kssolv.analysis.matgenlab.core.NthOrderElasticTensor
    %ELASTICTENSOR Rank-four elastic stiffness tensor in GPa.

    properties (Dependent, SetAccess = private)
        compliance_tensor
        k_voigt
        g_voigt
        k_reuss
        g_reuss
        k_vrh
        g_vrh
        y_mod
        universal_anisotropy
        homogeneous_poisson
        property_dict
    end

    methods
        function obj = ElasticTensor(inputArray, tol)
            if nargin < 2, tol = 1e-4; end
            obj@kssolv.analysis.matgenlab.core.NthOrderElasticTensor( ...
                inputArray, 4, tol);
        end

        function value = get.compliance_tensor(obj)
            value = kssolv.analysis.matgenlab.core.ComplianceTensor. ...
                from_voigt(inv(obj.voigt));
        end

        function value = get.k_voigt(obj)
            matrix = obj.voigt;
            value = mean(matrix(1:3, 1:3), "all");
        end

        function value = get.g_voigt(obj)
            matrix = obj.voigt;
            block = matrix(1:3, 1:3);
            value = (2 * trace(block) - sum(triu(block), "all") + ...
                3 * trace(matrix(4:6, 4:6))) / 15;
        end

        function value = get.k_reuss(obj)
            compliance = obj.compliance_tensor.voigt;
            value = 1 / sum(compliance(1:3, 1:3), "all");
        end

        function value = get.g_reuss(obj)
            compliance = obj.compliance_tensor.voigt;
            block = compliance(1:3, 1:3);
            value = 15 / (8 * trace(block) - 4 * ...
                sum(triu(block), "all") + ...
                3 * trace(compliance(4:6, 4:6)));
        end

        function value = get.k_vrh(obj)
            value = (obj.k_voigt + obj.k_reuss) / 2;
        end

        function value = get.g_vrh(obj)
            value = (obj.g_voigt + obj.g_reuss) / 2;
        end

        function value = get.y_mod(obj)
            value = 9e9 * obj.k_vrh * obj.g_vrh / ...
                (3 * obj.k_vrh + obj.g_vrh);
        end

        function value = directional_poisson_ratio(obj, first, second, tol)
            if nargin < 4, tol = 1e-8; end
            first = kssolv.analysis.matgenlab.core.get_uvec(first);
            second = kssolv.analysis.matgenlab.core.get_uvec(second);
            if abs(dot(first, second)) >= tol
                error("KSSOLV:Matgenlab:ElasticTensor:Directions", ...
                    "n and m must be orthogonal.");
            end
            compliance = obj.compliance_tensor;
            numerator = compliance.einsum_sequence( ...
                {first, first, second, second});
            denominator = compliance.einsum_sequence( ...
                {first, first, first, first});
            value = -numerator / denominator;
        end

        function value = directional_elastic_mod(obj, direction)
            direction = ...
                kssolv.analysis.matgenlab.core.get_uvec(direction);
            value = obj.einsum_sequence(repmat({direction}, 1, 4));
        end

        function value = trans_v(obj, structure)
            obj.ensurePhysical();
            density = obj.massDensity(structure);
            value = sqrt(1e9 * obj.g_vrh / density);
        end

        function value = long_v(obj, structure)
            obj.ensurePhysical();
            density = obj.massDensity(structure);
            value = sqrt(1e9 * (obj.k_vrh + 4 / 3 * obj.g_vrh) / ...
                density);
        end

        function value = snyder_ac(obj, structure)
            obj.ensurePhysical();
            numberSites = structure.num_sites;
            numberAtoms = structure.composition.num_atoms;
            siteDensity = numberSites / (structure.volume * 1e-30);
            totalMass = obj.totalSiteMass(structure);
            averageMass = totalMass / numberAtoms;
            averageVelocity = ...
                (obj.long_v(structure) + 2 * obj.trans_v(structure)) / 3;
            value = 0.38483 * averageMass * averageVelocity^3 / ...
                (300 * siteDensity^(-2/3) * numberSites^(1/3));
        end

        function value = snyder_opt(obj, structure)
            obj.ensurePhysical();
            numberSites = structure.num_sites;
            siteDensity = numberSites / (structure.volume * 1e-30);
            averageVelocity = ...
                (obj.long_v(structure) + 2 * obj.trans_v(structure)) / 3;
            value = 1.66914e-23 * averageVelocity / ...
                siteDensity^(-2/3) * (1 - numberSites^(-1/3));
        end

        function value = snyder_total(obj, structure)
            obj.ensurePhysical();
            value = obj.snyder_ac(structure) + ...
                obj.snyder_opt(structure);
        end

        function value = clarke_thermalcond(obj, structure)
            obj.ensurePhysical();
            numberAtoms = structure.composition.num_atoms;
            totalMass = obj.totalSiteMass(structure);
            averageMass = totalMass / numberAtoms;
            density = obj.massDensity(structure);
            value = 0.87 * 1.380649e-23 * averageMass^(-2/3) * ...
                density^(1/6) * sqrt(obj.y_mod);
        end

        function value = cahill_thermalcond(obj, structure)
            obj.ensurePhysical();
            siteDensity = structure.num_sites / ...
                (structure.volume * 1e-30);
            coefficient = 0.5 * (pi / 6)^(1/3);
            value = 1.380649e-23 * coefficient * siteDensity^(2/3) * ...
                (obj.long_v(structure) + 2 * obj.trans_v(structure));
        end

        function value = agne_diffusive_thermalcond(obj, structure)
            obj.ensurePhysical();
            siteDensity = structure.num_sites / ...
                (structure.volume * 1e-30);
            value = 0.76 * siteDensity^(2/3) * 1.380649e-23 * ...
                (2 * obj.trans_v(structure) + obj.long_v(structure)) / 3;
        end

        function value = debye_temperature(obj, structure)
            obj.ensurePhysical();
            volumePerSite = structure.volume / ...
                structure.num_sites * 1e-30;
            longitudinal = obj.long_v(structure);
            transverse = obj.trans_v(structure);
            meanVelocity = 3^(1/3) * ...
                (longitudinal^-3 + 2 * transverse^-3)^(-1/3);
            value = 1.0545718176461565e-34 / 1.380649e-23 * ...
                meanVelocity * (6 * pi^2 / volumePerSite)^(1/3);
        end

        function value = get.universal_anisotropy(obj)
            value = 5 * obj.g_voigt / obj.g_reuss + ...
                obj.k_voigt / obj.k_reuss - 6;
        end

        function value = get.homogeneous_poisson(obj)
            ratio = obj.g_vrh / obj.k_vrh;
            value = (1 - 2 / 3 * ratio) / (2 + 2 / 3 * ratio);
        end

        function value = green_kristoffel(obj, direction)
            direction = reshape(double(direction), 1, 3);
            tensor = double(obj);
            value = zeros(3);
            for second = 1:3
                for third = 1:3
                    for first = 1:3
                        for fourth = 1:3
                            value(second, third) = value(second, third) + ...
                                tensor(first, second, third, fourth) * ...
                                direction(first) * direction(fourth);
                        end
                    end
                end
            end
        end

        function value = get.property_dict(obj)
            value = struct( ...
                "k_voigt", obj.k_voigt, ...
                "k_reuss", obj.k_reuss, ...
                "k_vrh", obj.k_vrh, ...
                "g_voigt", obj.g_voigt, ...
                "g_reuss", obj.g_reuss, ...
                "g_vrh", obj.g_vrh, ...
                "universal_anisotropy", obj.universal_anisotropy, ...
                "homogeneous_poisson", obj.homogeneous_poisson, ...
                "y_mod", obj.y_mod);
        end

        function value = get_structure_property_dict( ...
                obj, structure, includeBaseProperties, ignoreErrors)
            if nargin < 3, includeBaseProperties = true; end
            if nargin < 4, ignoreErrors = false; end
            names = ["trans_v", "long_v", "snyder_ac", "snyder_opt", ...
                "snyder_total", "clarke_thermalcond", ...
                "cahill_thermalcond", "debye_temperature"];
            value = struct();
            for name = names
                if ignoreErrors && (obj.k_vrh < 0 || obj.g_vrh < 0)
                    value.(name) = [];
                else
                    value.(name) = obj.(name)(structure);
                end
            end
            value.structure = structure;
            if includeBaseProperties
                base = obj.property_dict;
                names = string(fieldnames(base));
                for name = names.'
                    value.(name) = base.(name);
                end
            end
        end

        function value = asDict(obj, voigt)
            if nargin < 2, voigt = false; end
            value = asDict@kssolv.analysis.matgenlab.core. ...
                NthOrderElasticTensor(obj, voigt);
            value.x_class = "ElasticTensor";
        end
    end

    methods (Static)
        function obj = from_voigt(values)
            tensor = ...
                kssolv.analysis.matgenlab.core.Tensor.from_voigt(values);
            obj = kssolv.analysis.matgenlab.core. ...
                ElasticTensor(double(tensor));
        end

        function obj = from_pseudoinverse(strains, stresses)
            warning("KSSOLV:Matgenlab:ElasticTensor:Pseudoinverse", ...
                "Pseudo-inverse fitting of Strain/Stress lists may " + ...
                "yield questionable results from vasp data, use with caution.");
            [strainValues, stressValues] = ...
                kssolv.analysis.matgenlab.core.ElasticTensor. ...
                voigtLists(strains, stresses);
            fitValues = (pinv(strainValues) * stressValues).';
            obj = kssolv.analysis.matgenlab.core. ...
                ElasticTensor.from_voigt(fitValues);
        end

        function obj = from_independent_strains( ...
                strains, stresses, equilibriumStress, vasp, tol)
            if nargin < 3, equilibriumStress = []; end
            if nargin < 4, vasp = false; end
            if nargin < 5, tol = 1e-10; end
            groups = kssolv.analysis.matgenlab.core. ...
                get_strain_state_dict(strains, stresses, ...
                equilibriumStress, tol, true, true);
            matrix = zeros(6);
            independentStates = eye(6);
            isIndependent = arrayfun(@(item) any(all(abs( ...
                independentStates - item.state) < 1e-8, 2)), groups);
            if any(~isIndependent)
                warning("KSSOLV:Matgenlab:ElasticTensor:ExtraStates", ...
                    "Extra strain states in strain-stress pairs are " + ...
                    "neglected in independent strain fitting.");
            end
            for mode = 1:6
                target = zeros(1, 6); target(mode) = 1;
                index = find(arrayfun(@(item) ...
                    max(abs(item.state - target)) < 1e-8, groups), 1);
                if isempty(index)
                    error("KSSOLV:Matgenlab:ElasticTensor:MissingStates", ...
                        "Missing independent strain state %d.", mode);
                end
                x = groups(index).strains(:, mode);
                for stressIndex = 1:6
                    coefficients = polyfit(x, ...
                        groups(index).stresses(:, stressIndex), 1);
                    matrix(mode, stressIndex) = coefficients(1);
                end
            end
            if vasp, matrix = -0.1 * matrix; end
            obj = kssolv.analysis.matgenlab.core. ...
                ElasticTensor.from_voigt(matrix).zeroed(tol);
        end

        function obj = from_dict(value)
            if isfield(value, "voigt") && value.voigt
                obj = kssolv.analysis.matgenlab.core. ...
                    ElasticTensor.from_voigt(value.input_array);
            else
                obj = kssolv.analysis.matgenlab.core. ...
                    ElasticTensor(value.input_array);
            end
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.core.ElasticTensor.from_dict(value);
        end
    end

    methods (Access = private)
        function ensurePhysical(obj)
            if obj.k_vrh < 0 || obj.g_vrh < 0
                error("KSSOLV:Matgenlab:ElasticTensor:Unphysical", ...
                    "Bulk or shear modulus is negative, property cannot " + ...
                    "be determined.");
            end
        end

        function value = massDensity(~, structure)
            numberSites = structure.num_sites;
            numberAtoms = structure.composition.num_atoms;
            weight = structure.composition.weight * 1.66053906892e-27;
            volume = structure.volume * 1e-30;
            value = numberSites * weight / (numberAtoms * volume);
        end

        function value = totalSiteMass(~, structure)
            value = 0;
            for index = 1:structure.num_sites
                value = value + structure(index).species.weight * ...
                    1.66053906892e-27;
            end
        end
    end

    methods (Static, Access = private)
        function [strainValues, stressValues] = ...
                voigtLists(strains, stresses)
            count = kssolv.analysis.matgenlab.core.ElasticTensor. ...
                sequenceLength(strains);
            if count ~= kssolv.analysis.matgenlab.core. ...
                    ElasticTensor.sequenceLength(stresses)
                error("KSSOLV:Matgenlab:ElasticTensor:Length", ...
                    "Strain and stress lists must have equal lengths.");
            end
            strainValues = zeros(count, 6);
            stressValues = zeros(count, 6);
            for index = 1:count
                strainValues(index, :) = ...
                    kssolv.analysis.matgenlab.core.Strain( ...
                    kssolv.analysis.matgenlab.core.ElasticTensor. ...
                    sequenceItem(strains, index)).voigt;
                stressValues(index, :) = ...
                    kssolv.analysis.matgenlab.core.Stress( ...
                    kssolv.analysis.matgenlab.core.ElasticTensor. ...
                    sequenceItem(stresses, index)).voigt;
            end
        end

        function value = sequenceLength(items)
            if iscell(items), value = numel(items);
            else, value = size(items, 1);
            end
        end

        function value = sequenceItem(items, index)
            if iscell(items)
                value = items{index};
            else
                dimensions = repmat({':'}, 1, ndims(items));
                dimensions{1} = index;
                value = squeeze(items(dimensions{:}));
            end
        end
    end
end
