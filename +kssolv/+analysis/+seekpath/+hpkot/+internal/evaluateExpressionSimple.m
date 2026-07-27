function result = evaluateExpressionSimple(expression, parameters)
%EVALUATEEXPRESSIONSIMPLE Evaluates expressions that only require parameters.
%
% Input:
%   expression - A string representing the mathematical expression to evaluate.
%   parameters  - A structure or container (like a containers.Map) containing named values.
%
% Output:
%   result      - The numerical result of the evaluated expression.

% Predefined expressions with direct numeric results
switch expression
    case "0"
        result = 0.0;
    case "1/2"
        result = 1.0 / 2.0;
    case "1"
        result = 1.0;
    case "-1/2"
        result = -1.0 / 2.0;
    case "1/4"
        result = 1.0 / 4.0;
    case "3/8"
        result = 3.0 / 8.0;
    case "3/4"
        result = 3.0 / 4.0;
    case "5/8"
        result = 5.0 / 8.0;
    case "1/3"
        result = 1.0 / 3.0;
    otherwise
        % Try retrieving from parameters if not a predefined expression
        try
            if isa(parameters, 'containers.Map')
                % For containers.Map input
                result = parameters(expression);
            else
                error('The parameters argument must be a structure or a containers.Map');
            end
        catch
            error("Undefined or uncomputed symbol '%s' in evaluateExpressionSimple.", expression);
        end
end
end
