function tensors = diff_fit( ...
        strains, stresses, equilibriumStress, order, tol)
%DIFF_FIT Fit elastic constants using arbitrary-stencil derivatives.
if nargin < 3, equilibriumStress = []; end
if nargin < 4, order = 2; end
if nargin < 5, tol = 1e-10; end
if order < 2 || order ~= fix(order)
    error("KSSOLV:Matgenlab:Elasticity:FitOrder", ...
        "Elastic fit order must be an integer of at least two.");
end
groups = kssolv.analysis.matgenlab.core.get_strain_state_dict( ...
    strains, stresses, equilibriumStress, tol, true, true);
stateMatrix = vertcat(groups.state);
[pseudo, ~] = kssolv.analysis.matgenlab.core. ...
    generate_pseudo(stateMatrix, order);
derivatives = cell(1, order - 1);
for derivativeOrder = 1:order-1
    values = zeros(numel(groups), 6);
    for groupIndex = 1:numel(groups)
        unitIndex = find(abs(groups(groupIndex).state - 1) < ...
            1e-8, 1);
        if isempty(unitIndex)
            error("KSSOLV:Matgenlab:Elasticity:StrainState", ...
                "Every strain state must contain a unit component.");
        end
        mesh = groups(groupIndex).strains(:, unitIndex);
        coefficients = kssolv.analysis.matgenlab.core. ...
            get_diff_coeff(mesh, derivativeOrder);
        values(groupIndex, :) = ...
            coefficients * groups(groupIndex).stresses;
    end
    derivatives{derivativeOrder} = values;
end
tensors = cell(1, order - 1);
for derivativeOrder = 1:order-1
    degree = derivativeOrder + 1;
    [symbols, symbolicTensor] = ...
        kssolv.analysis.matgenlab.core.get_symbol_list(degree, 6);
    vector = reshape(derivatives{derivativeOrder}.', [], 1);
    fitted = pseudo{derivativeOrder} * vector;
    mapping = containers.Map(cellstr(symbols), num2cell(fitted));
    voigt = zeros(size(symbolicTensor));
    for index = 1:numel(symbolicTensor)
        voigt(index) = mapping(char(symbolicTensor(index)));
    end
    base = kssolv.analysis.matgenlab.core.Tensor.from_voigt(voigt);
    tensors{derivativeOrder} = ...
        kssolv.analysis.matgenlab.core.NthOrderElasticTensor( ...
        double(base));
end
end
