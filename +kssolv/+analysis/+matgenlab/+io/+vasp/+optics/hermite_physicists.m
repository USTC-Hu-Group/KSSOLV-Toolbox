function value = hermite_physicists(order, x)
%HERMITE_PHYSICISTS Evaluate the physicists' Hermite polynomial H_n(x).
arguments
    order (1,1) double {mustBeInteger,mustBeNonnegative}
    x double
end
if order == 0
    value = ones(size(x));
    return
end
previous = ones(size(x));
value = 2 .* x;
for degree = 1:(order - 1)
    next = 2 .* x .* value - 2 .* degree .* previous;
    previous = value;
    value = next;
end
end
