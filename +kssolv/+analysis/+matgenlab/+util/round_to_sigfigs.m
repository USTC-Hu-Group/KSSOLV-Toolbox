function value = round_to_sigfigs(num, sig_figs)
%ROUND_TO_SIGFIGS Round a scalar to a number of significant figures.
% Compatible with pymatgen.util.num.round_to_sigfigs.
if ~isnumeric(sig_figs) || ~isscalar(sig_figs) || ...
        ~isfinite(sig_figs) || sig_figs ~= fix(sig_figs)
    error("KSSOLV:Matgenlab:Num:SigFigsNotInteger", ...
        "Number of significant figures must be integer");
end
if sig_figs < 1
    error("KSSOLV:Matgenlab:Num:SigFigsNotPositive", ...
        "Number of significant figures must be positive");
end
if ~isnumeric(num) || ~isscalar(num)
    error("KSSOLV:Matgenlab:Num:InvalidNumber", ...
        "num must be a numeric scalar.");
end
if num == 0 || ~isfinite(num)
    value = num;
    return
end
precision = sig_figs - ceil(log10(abs(double(num))));
if precision >= 0
    scale = 10^precision;
    value = roundHalfEven(double(num) * scale) / scale;
else
    scale = 10^(-precision);
    value = roundHalfEven(double(num) / scale) * scale;
end
end

function rounded = roundHalfEven(value)
lower = floor(value);
fraction = value - lower;
tieTolerance = 2 * eps(max(1, abs(value)));
if abs(fraction - 0.5) <= tieTolerance
    if mod(abs(lower), 2) == 0
        rounded = lower;
    else
        rounded = lower + 1;
    end
else
    rounded = round(value);
end
end
