classdef ElasticTensorExpansion < ...
        kssolv.analysis.matgenlab.core.TensorCollection
    %ELASTICTENSOREXPANSION Sequence of second- and higher-order constants.

    properties (Dependent, SetAccess = private)
        order
    end

    methods
        function obj = ElasticTensorExpansion(constants)
            if isa(constants, ...
                    "kssolv.analysis.matgenlab.core.TensorCollection")
                constants = constants.tensors;
            elseif ~iscell(constants)
                constants = {constants};
            end
            converted = cell(1, numel(constants));
            for index = 1:numel(constants)
                expectedRank = 2 * (index + 1);
                value = constants{index};
                if isa(value, ...
                        "kssolv.analysis.matgenlab.core.NthOrderElasticTensor")
                    if value.rank ~= expectedRank
                        error("KSSOLV:Matgenlab:ElasticExpansion:Rank", ...
                            "Elastic constant %d must have rank %d.", ...
                            index, expectedRank);
                    end
                    converted{index} = value;
                else
                    converted{index} = ...
                        kssolv.analysis.matgenlab.core. ...
                        NthOrderElasticTensor(double(value), expectedRank);
                end
            end
            obj@kssolv.analysis.matgenlab.core.TensorCollection( ...
                converted, ...
                "kssolv.analysis.matgenlab.core.NthOrderElasticTensor");
        end

        function value = get.order(obj)
            value = obj.tensors{end}.order;
        end

        function value = calculate_stress(obj, strain)
            total = zeros(3);
            for index = 1:numel(obj.tensors)
                total = total + ...
                    double(obj.tensors{index}.calculate_stress(strain));
            end
            value = kssolv.analysis.matgenlab.core.Stress(total);
        end

        function value = energy_density(obj, strain, convertGPaToEV)
            if nargin < 3, convertGPaToEV = true; end
            value = 0;
            for index = 1:numel(obj.tensors)
                value = value + obj.tensors{index}.energy_density( ...
                    strain, convertGPaToEV);
            end
        end

        function value = get_ggt(obj, direction, polarization)
            direction = reshape(double(direction), 1, 3);
            polarization = reshape(double(polarization), 1, 3);
            second = obj.tensors{1};
            third = obj.tensors{2};
            secondValues = double(second);
            thirdValues = double(third);
            kristoffel = 0;
            secondContraction = zeros(3);
            thirdContraction = zeros(3);
            for first = 1:3
                for secondIndex = 1:3
                    for thirdIndex = 1:3
                        for fourth = 1:3
                            factor = direction(thirdIndex) * ...
                                direction(fourth);
                            secondContraction(first, secondIndex) = ...
                                secondContraction(first, secondIndex) + ...
                                secondValues(first, secondIndex, ...
                                thirdIndex, fourth) * factor;
                            kristoffel = kristoffel + ...
                                secondValues(first, secondIndex, ...
                                thirdIndex, fourth) * ...
                                direction(first) * ...
                                polarization(secondIndex) * ...
                                direction(thirdIndex) * ...
                                polarization(fourth);
                            for fifth = 1:3
                                for sixth = 1:3
                                    thirdContraction(first, secondIndex) = ...
                                        thirdContraction(first, secondIndex) + ...
                                        thirdValues(first, secondIndex, ...
                                        thirdIndex, fourth, fifth, sixth) * ...
                                        direction(thirdIndex) * ...
                                        polarization(fourth) * ...
                                        direction(fifth) * ...
                                        polarization(sixth);
                                end
                            end
                        end
                    end
                end
            end
            value = -(2 * kristoffel * ...
                (polarization.' * polarization) + ...
                secondContraction + thirdContraction) / ...
                (2 * kristoffel);
        end

        function value = get_tgt(obj, temperature, structure, quadrature)
            if nargin < 2, temperature = []; end
            if nargin < 3, structure = []; end
            if nargin < 4 || isempty(quadrature)
                quadrature = ...
                    kssolv.analysis.matgenlab.core. ...
                    ElasticTensorExpansion.defaultQuadrature();
            end
            if ~isempty(temperature) && temperature ~= 0 && isempty(structure)
                error("KSSOLV:Matgenlab:ElasticExpansion:Structure", ...
                    "Temperature-dependent TGT requires a structure.");
            end
            numerator = zeros(3);
            denominator = 0;
            for pointIndex = 1:size(quadrature.points, 1)
                direction = quadrature.points(pointIndex, :);
                weight = quadrature.weights(pointIndex);
                green = kssolv.analysis.matgenlab.core.ElasticTensor( ...
                    double(obj.tensors{1})).green_kristoffel(direction);
                [vectors, ~] = eig(green);
                for mode = 1:3
                    polarization = vectors(:, mode).';
                    polarization = polarization / norm(polarization);
                    capacity = 1;
                    if ~isempty(temperature) && temperature ~= 0 && ...
                            ~isempty(structure)
                        capacity = obj.get_heat_capacity( ...
                            temperature, structure, direction, polarization);
                    end
                    numerator = numerator + capacity * ...
                        obj.get_ggt(direction, polarization) * weight;
                    denominator = denominator + capacity * weight;
                end
            end
            value = kssolv.analysis.matgenlab.core. ...
                SquareTensor(numerator / denominator);
        end

        function value = get_gruneisen_parameter( ...
                obj, temperature, structure, quadrature)
            if nargin < 2, temperature = []; end
            if nargin < 3, structure = []; end
            if nargin < 4, quadrature = []; end
            value = trace(double(obj.get_tgt( ...
                temperature, structure, quadrature))) / 3;
        end

        function value = get_heat_capacity( ...
                obj, temperature, structure, direction, ...
                polarization, cutoff)
            if nargin < 7, cutoff = 100; end
            thermalEnergy = 1.380649e-23 * temperature;
            quantum = 1.0545718176461565e-34 * ...
                obj.omega(structure, direction, polarization);
            if temperature <= 0 || quantum > thermalEnergy * cutoff
                value = 0;
                return
            end
            ratio = quantum / thermalEnergy;
            value = 1.380649e-23 * ratio^2 * exp(ratio) / ...
                (exp(ratio) - 1)^2 * 6.02214076e23;
        end

        function value = omega(obj, structure, direction, polarization)
            direction = reshape(double(direction), 1, 3);
            polarization = reshape(double(polarization), 1, 3);
            lengthScale = dot(sum(structure.lattice.matrix, 1), ...
                direction) * 1e-10;
            mass = structure.composition.weight * ...
                1.66053906892e-27;
            volume = structure.volume * 1e-30;
            stiffness = obj.tensors{1}.einsum_sequence( ...
                {direction, polarization, direction, polarization});
            velocity = sqrt(1e9 * stiffness / (mass / volume));
            value = velocity / lengthScale;
        end

        function value = thermal_expansion_coeff( ...
                obj, structure, temperature, mode)
            if nargin < 4, mode = "debye"; end
            second = kssolv.analysis.matgenlab.core.ElasticTensor( ...
                double(obj.tensors{1}));
            volumePerAtom = structure.volume * 1e-30 / ...
                structure.num_sites;
            switch lower(string(mode))
                case "debye"
                    ratio = temperature / ...
                        second.debye_temperature(structure);
                    integrand = @(x) x.^4 .* exp(x) ./ ...
                        (exp(x) - 1).^2;
                    heatCapacity = 9 * 8.31446261815324 * ratio^3 * ...
                        integral(integrand, 0, 1 / ratio);
                case "dulong-petit"
                    heatCapacity = 3 * 8.31446261815324;
                otherwise
                    error("KSSOLV:Matgenlab:ElasticExpansion:ThermalMode", ...
                        "mode must be 'debye' or 'dulong-petit'.");
            end
            tgt = double(obj.get_tgt(temperature, structure));
            compliance = second.compliance_tensor;
            alpha = compliance.einsum_sequence( ...
                {tgt}, "ijkl,ij->kl");
            alpha = alpha * heatCapacity / ...
                (1e9 * volumePerAtom * 6.02214076e23);
            value = kssolv.analysis.matgenlab.core.SquareTensor(alpha);
        end

        function value = get_compliance_expansion(obj)
            if obj.order > 4
                error("KSSOLV:Matgenlab:ElasticExpansion:ComplianceOrder", ...
                    "Compliance tensor expansion is only supported for " + ...
                    "fourth order and lower.");
            end
            compliance = kssolv.analysis.matgenlab.core.ElasticTensor( ...
                double(obj.tensors{1})).compliance_tensor;
            values = {compliance};
            negativeCompliance = -compliance;
            thirdCompliance = negativeCompliance.einsum_sequence( ...
                {obj.tensors{2}, compliance, compliance}, ...
                "ijpq,pqrsuv,rskl,uvmn->ijklmn");
            values{2} = kssolv.analysis.matgenlab.core.Tensor( ...
                thirdCompliance);
            if obj.order == 4
                fourth = negativeCompliance.einsum_sequence( ...
                    {compliance, compliance, compliance, ...
                    obj.tensors{3}}, ...
                    "pqab,cdij,efkl,ghmn,abcdefgh->pqijklmn");
                expressions = [ ...
                    "pqab,abcdef,cdijmn,efkl->pqijklmn"
                    "pqab,abcdef,efklmn,cdij->pqijklmn"
                    "pqab,abcdef,cdijkl,efmn->pqijklmn"];
                for expression = expressions.'
                    fourth = fourth - compliance.einsum_sequence( ...
                        {obj.tensors{2}, values{2}, compliance}, ...
                        expression);
                end
                values{3} = ...
                    kssolv.analysis.matgenlab.core.Tensor(fourth);
            end
            value = kssolv.analysis.matgenlab.core.TensorCollection(values);
        end

        function value = get_strain_from_stress(obj, stress)
            target = kssolv.analysis.matgenlab.core.Stress(stress).voigt;
            second = kssolv.analysis.matgenlab.core.ElasticTensor( ...
                double(obj.tensors{1}));
            estimate = (second.compliance_tensor.voigt * target.').';
            for iteration = 1:20
                current = kssolv.analysis.matgenlab.core.Strain. ...
                    from_voigt(estimate);
                residual = obj.calculate_stress(current).voigt - target;
                if norm(residual) < 1e-10, break; end
                jacobian = zeros(6);
                step = 1e-7;
                for component = 1:6
                    perturbed = estimate;
                    perturbed(component) = perturbed(component) + step;
                    trial = obj.calculate_stress( ...
                        kssolv.analysis.matgenlab.core.Strain. ...
                        from_voigt(perturbed)).voigt;
                    jacobian(:, component) = ...
                        (trial - (residual + target)).' / step;
                end
                update = (jacobian \ residual.').';
                estimate = estimate - update;
                if norm(update) < 1e-12, break; end
            end
            value = kssolv.analysis.matgenlab.core.Strain. ...
                from_voigt(estimate);
        end

        function value = get_effective_ecs(obj, strain, order)
            if nargin < 3, order = 2; end
            start = order - 1;
            value = [];
            strainVector = reshape(double(strain), 9, 1);
            for index = start:numel(obj.tensors)
                contractions = index - start;
                term = double(obj.tensors{index});
                currentRank = ndims(term);
                for contraction = 1:contractions
                    term = reshape(term, 3^(currentRank - 2), 9) * ...
                        strainVector;
                    currentRank = currentRank - 2;
                    term = reshape(term, repmat(3, 1, currentRank));
                end
                term = term / factorial(contractions);
                if isempty(value), value = term; else, value = value + term; end
            end
        end

        function value = get_wallace_tensor(obj, stress)
            stress = double(stress);
            identity = eye(3);
            correction = zeros(3, 3, 3, 3);
            for k = 1:3
                for l = 1:3
                    for m = 1:3
                        for n = 1:3
                            correction(k,l,m,n) = 0.5 * ( ...
                                stress(m,l) * identity(k,n) + ...
                                stress(k,m) * identity(l,n) + ...
                                stress(n,l) * identity(k,m) + ...
                                stress(k,n) * identity(l,m) - ...
                                2 * stress(k,l) * identity(m,n));
                        end
                    end
                end
            end
            strain = obj.get_strain_from_stress(stress);
            value = correction + obj.get_effective_ecs(strain);
        end

        function value = get_symmetric_wallace_tensor(obj, stress)
            wallace = obj.get_wallace_tensor(stress);
            value = kssolv.analysis.matgenlab.core.Tensor( ...
                0.5 * (wallace + permute(wallace, [3, 4, 1, 2])));
        end

        function value = get_stability_criteria(obj, stressValue, direction)
            direction = ...
                kssolv.analysis.matgenlab.core.get_uvec(direction);
            stress = stressValue * (direction.' * direction);
            wallace = obj.get_symmetric_wallace_tensor(stress);
            value = det(wallace.voigt);
        end

        function varargout = get_yield_stress(obj, direction)
            compression = obj.findStabilityRoot(direction, -1);
            tension = obj.findStabilityRoot(direction, 1);
            if nargout <= 1
                varargout{1} = [compression, tension];
            else
                varargout = {compression, tension};
            end
        end

        function value = asDict(obj, voigt)
            if nargin < 2, voigt = false; end
            if voigt
                list = obj.voigt;
            else
                list = cellfun(@double, obj.tensors, ...
                    "UniformOutput", false);
            end
            value = struct( ...
                "x_module", "pymatgen.core.elasticity.elastic", ...
                "x_class", "ElasticTensorExpansion", ...
                "tensor_list", {list});
            if voigt, value.voigt = true; end
        end
    end

    methods (Static)
        function obj = from_diff_fit( ...
                strains, stresses, equilibriumStress, tol, order)
            if nargin < 3, equilibriumStress = []; end
            if nargin < 4, tol = 1e-10; end
            if nargin < 5, order = 3; end
            values = kssolv.analysis.matgenlab.core.diff_fit( ...
                strains, stresses, equilibriumStress, order, tol);
            obj = kssolv.analysis.matgenlab.core. ...
                ElasticTensorExpansion(values);
        end

        function obj = from_voigt(values)
            if ~iscell(values), values = {values}; end
            tensors = cellfun(@(value) ...
                kssolv.analysis.matgenlab.core. ...
                NthOrderElasticTensor.from_voigt(value), ...
                values, "UniformOutput", false);
            obj = kssolv.analysis.matgenlab.core. ...
                ElasticTensorExpansion(tensors);
        end

        function obj = from_dict(value)
            values = value.tensor_list;
            if ~iscell(values)
                error("KSSOLV:Matgenlab:ElasticExpansion:Dictionary", ...
                    "tensor_list must be a cell array for mixed ranks.");
            end
            if isfield(value, "voigt") && value.voigt
                obj = kssolv.analysis.matgenlab.core. ...
                    ElasticTensorExpansion.from_voigt(values);
            else
                obj = kssolv.analysis.matgenlab.core. ...
                    ElasticTensorExpansion(values);
            end
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.core. ...
                ElasticTensorExpansion.from_dict(value);
        end
    end

    methods (Access = private)
        function value = findStabilityRoot(obj, direction, initialSign)
            function result = criterion(point)
                result = obj.get_stability_criteria(point, direction);
            end
            first = 0;
            firstValue = criterion(first);
            second = initialSign;
            secondValue = criterion(second);
            for iteration = 1:30
                if sign(firstValue) ~= sign(secondValue), break; end
                second = second * 2;
                secondValue = criterion(second);
            end
            if sign(firstValue) == sign(secondValue)
                value = NaN;
            else
                value = fzero(@criterion, [min(first, second), ...
                    max(first, second)]);
            end
        end
    end

    methods (Static, Access = private)
        function quadrature = defaultQuadrature()
            persistent cached
            if ~isempty(cached), quadrature = cached; return; end
            % Lebedev-Laikov degree-53 quadrature used by pymatgen's
            % quad_data.json. Each row is an absolute-coordinate orbit
            % representative followed by its per-point weight.
            orbits = [ ...
                0 0 1 0.000143829419053;
                0.57735026918962584 0.57735026918962584 0.57735026918962584 0.0011257722882870001;
                0 0.12366867626579896 0.99232356543149025 0.000682336792711;
                0 0.29407771144683864 0.95578151249654852 0.000945415816045;
                0 0.46977538492076509 0.88278598070118164 0.0010744299753860001;
                0 0.63345632411395669 0.77377844725737477 0.001129300086569;
                0.042929635453413405 0.042929635453413405 0.99815534502384651 0.00049480293419500003;
                0.10514268540864033 0.10514268540864033 0.98888322435468556 0.00073579901091299998;
                0.17500248676230876 0.17500248676230876 0.96889022043470741 0.00088891327713;
                0.24776533796502581 0.24776533796502581 0.93660273040716313 0.000988834783892;
                0.32065671239559562 0.32065671239559562 0.89126794264760612 0.001053299681709;
                0.39165207498499821 0.39165207498499821 0.83259672370235194 0.001092778807015;
                0.4590825874187624 0.4590825874187624 0.76058290531525141 0.001114389394063;
                0.52145638884158607 0.52145638884158607 0.6754009691084143 0.001123724788052;
                0.46685890569574318 0.62531702446541992 0.62531702446541992 0.001125239325244;
                0.34461365423743789 0.66379267445231693 0.66379267445231693 0.001126153271816;
                0.21195415185018424 0.69104103984983001 0.69104103984983001 0.001130286931124;
                0.071624401449955438 0.70529070074577593 0.70529070074577593 0.001134986534364;
                0.059740486141813431 0.20291287527775245 0.97737272284530996 0.00084368845009;
                0.13757604084736344 0.46026219424840537 0.87705846186580272 0.001075255720449;
                0.33910165263362868 0.50306739996620375 0.7949422999642084 0.001108577236864;
                0.12716751914398197 0.28176064224421354 0.95102016937438993 0.000956647532378;
                0.26931207404135121 0.43315612917201568 0.86014346160176203 0.001080663250717;
                0.14197864526019177 0.62561673585808142 0.76710218622055837 0.001126797131196;
                0.06709284600738244 0.37983952168591584 0.92261611073080896 0.001022568715358;
                0.070577381832561778 0.55175054214235197 0.8310175524134743 0.001108960267713;
                0.27838884778821549 0.60296191561591872 0.74762061083408571 0.001122790653436;
                0.1979578938917407 0.35896063295890962 0.91211837840912147 0.001032401847117;
                0.20873070611032746 0.53486664381354776 0.81874853628102173 0.001107249382284;
                0.40551221378728358 0.56749975460743718 0.71659184546702381 0.00112178004852];
            signs = dec2bin(0:7) - '0';
            signs = 1 - 2 * signs;
            points = zeros(974, 3);
            weights = zeros(974, 1);
            row = 0;
            for orbitIndex = 1:size(orbits, 1)
                permutations = unique(perms(orbits(orbitIndex, 1:3)), ...
                    "rows", "stable");
                orbit = reshape(permutations, [], 1, 3) .* ...
                    reshape(signs, 1, [], 3);
                orbit = unique(reshape(orbit, [], 3), "rows", "stable");
                count = size(orbit, 1);
                points(row + (1:count), :) = orbit;
                weights(row + (1:count)) = orbits(orbitIndex, 4);
                row = row + count;
            end
            if row ~= 974
                error("KSSOLV:Matgenlab:ElasticExpansion:Quadrature", ...
                    "Internal Lebedev quadrature construction failed.");
            end
            cached = struct("points", points, "weights", weights);
            quadrature = cached;
        end
    end
end
