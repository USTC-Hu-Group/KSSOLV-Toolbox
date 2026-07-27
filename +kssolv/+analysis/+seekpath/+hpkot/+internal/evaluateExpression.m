function result = evaluateExpression(expression, a, b, c, ~, cosBeta, ~, parameters)
%EVALUATEEXPRESSION Evaluates expressions based on lattice parameters.
%
% Input:
%   expression  - A string representing the mathematical expression to evaluate.
%   a           - Length of the first lattice vector.
%   b           - Length of the second lattice vector.
%   c           - Length of the third lattice vector.
%   cosAlpha    - Cosine of the angle between lattice vectors 2 and 3.
%   cosBeta     - Cosine of the angle between lattice vectors 1 and 3.
%   cosGamma    - Cosine of the angle between lattice vectors 1 and 2.
%   parameters  - A structure or containers.Map containing additional parameters.
%
% Output:
%   result - The numerical result of the evaluated expression.

% Pre-compute sine values for efficiency
sinBeta = sqrt(1.0 - cosBeta^2);

try
    % Evaluate the known expressions
    switch expression
        case "(a*a/b/b+(1+a/c*cosbeta)/sinbeta/sinbeta)/4"
            result = (a^2 / b^2 + (1.0 + a / c * cosBeta) / sinBeta^2) / 4.0;

        case "1-Z*b*b/a/a"
            Z = parameters.Z;
            result = 1.0 - Z * b^2 / a^2;

        case "1/2-2*Z*c*cosbeta/a"
            Z = parameters.Z;
            result = 0.5 - 2.0 * Z * c * cosBeta / a;

        case "E/2+a*a/4/b/b+a*c*cosbeta/2/b/b"
            E = parameters.E;
            result = E / 2.0 + a^2 / 4.0 / b^2 + a * c * cosBeta / 2.0 / b^2;

        case "2*F-Z"
            F = parameters.F;
            Z = parameters.Z;
            result = 2.0 * F - Z;

        case "c/2/a/cosbeta*(1-4*U+a*a*sinbeta*sinbeta/b/b)"
            U = parameters.U;
            result = (c / 2.0 / a / cosBeta) * (1.0 - 4.0 * U + a^2 * sinBeta^2 / b^2);

        case "-1/4+W/2-Z*c*cosbeta/a"
            W = parameters.W;
            Z = parameters.Z;
            result = -0.25 + W / 2.0 - Z * c * cosBeta / a;

        case "(2+a/c*cosbeta)/4/sinbeta/sinbeta"
            result = (2.0 + a / c * cosBeta) / 4.0 / sinBeta^2;

        case "3/4-b*b/4/a/a/sinbeta/sinbeta"
            result = 0.75 - b^2 / 4.0 / a^2 / sinBeta^2;

        case "S-(3/4-S)*a*cosbeta/c"
            S = parameters.S;
            result = S - (0.75 - S) * a * cosBeta / c;

        case "(1+a*a/b/b)/4"
            result = (1.0 + a^2 / b^2) / 4.0;

        case "-a*c*cosbeta/2/b/b"
            result = -a * c * cosBeta / 2.0 / b^2;

        case "1+Z-2*M"
            Z = parameters.Z;
            M = parameters.M;
            result = 1.0 + Z - 2.0 * M;

        case "X-2*D"
            X = parameters.X;
            D = parameters.D;
            result = X - 2.0 * D;

        case "(1+a/c*cosbeta)/2/sinbeta/sinbeta"
            result = (1.0 + a / c * cosBeta) / 2.0 / sinBeta^2;

        case "1/2+Y*c*cosbeta/a"
            Y = parameters.Y;
            result = 0.5 + Y * c * cosBeta / a;

        case "a*a/4/c/c"
            result = a^2 / 4.0 / c^2;

        case "5/6-2*D"
            D = parameters.D;
            result = 5.0 / 6.0 - 2.0 * D;

        case "1/3+D"
            D = parameters.D;
            result = 1.0 / 3.0 + D;

        case "1/6-c*c/9/a/a"
            result = 1.0 / 6.0 - c^2 / 9.0 / a^2;

        case "1/2-2*Z"
            Z = parameters.Z;
            result = 0.5 - 2.0 * Z;

        case "1/2+Z"
            Z = parameters.Z;
            result = 0.5 + Z;

        case "(1+b*b/c/c)/4"
            result = (1.0 + b^2 / c^2) / 4.0;

        case "(1+c*c/b/b)/4"
            result = (1.0 + c^2 / b^2) / 4.0;

        case "(1+b*b/a/a)/4"
            result = (1.0 + b^2 / a^2) / 4.0;

        case "(1+a*a/b/b-a*a/c/c)/4"
            result = (1.0 + a^2 / b^2 - a^2 / c^2) / 4.0;

        case "(1+a*a/b/b+a*a/c/c)/4"
            result = (1.0 + a^2 / b^2 + a^2 / c^2) / 4.0;

        case "(1+c*c/a/a-c*c/b/b)/4"
            result = (1.0 + c^2 / a^2 - c^2 / b^2) / 4.0;

        case "(1+c*c/a/a+c*c/b/b)/4"
            result = (1.0 + c^2 / a^2 + c^2 / b^2) / 4.0;

        case "(1+b*b/a/a-b*b/c/c)/4"
            result = (1.0 + b^2 / a^2 - b^2 / c^2) / 4.0;

        case "(1+c*c/b/b-c*c/a/a)/4"
            result = (1.0 + c^2 / b^2 - c^2 / a^2) / 4.0;

        case "(1+a*a/c/c)/4"
            result = (1.0 + a^2 / c^2) / 4.0;

        case "(b*b-a*a)/4/c/c"
            result = (b^2 - a^2) / 4.0 / c^2;

        case "(a*a+b*b)/4/c/c"
            result = (a^2 + b^2) / 4.0 / c^2;

        case "(1+c*c/a/a)/4"
            result = (1.0 + c^2 / a^2) / 4.0;

        case "(c*c-b*b)/4/a/a"
            result = (c^2 - b^2) / 4.0 / a^2;

        case "(b*b+c*c)/4/a/a"
            result = (b^2 + c^2) / 4.0 / a^2;

        case "(a*a-c*c)/4/b/b"
            result = (a^2 - c^2) / 4.0 / b^2;

        case "(c*c+a*a)/4/b/b"
            result = (c^2 + a^2) / 4.0 / b^2;

        case "a*a/2/c/c"
            result = a^2 / 2.0 / c^2;

        otherwise
            error("Unknown expression '%s'. Define a new case in evaluateExpression.", expression);
    end
catch ME
    if strcmp(ME.identifier, 'MATLAB:nonExistentField') || strcmp(ME.identifier, 'MATLAB:Containers:Map:NoKey')
        error("Asking for evaluation of symbol '%s' but this has not been defined or not yet computed.", ME.message);
    else
        rethrow(ME);
    end
end
end
