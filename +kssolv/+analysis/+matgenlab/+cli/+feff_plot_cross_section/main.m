function [axesHandle, data] = main(xmuFile, feffInput, options)
%MAIN Plot FEFF absorption cross sections from xmu.dat and feff.inp.
arguments
    xmuFile {mustBeTextScalar}
    feffInput {mustBeTextScalar}
    options.Visible (1,1) logical = false
    options.Xmu = []
end
if isempty(options.Xmu)
    xmu = kssolv.analysis.matgenlab.io.feff.Xmu.from_file( ...
        xmuFile, feffInput);
else
    xmu = options.Xmu;
end
figureHandle = figure("Visible", onOff(options.Visible));
axesHandle = axes(figureHandle);
hold(axesHandle, "on");
single = xmu.mu0;
total = xmu.mu;
atom = string(xmu.absorbing_atom);
formula = string(xmu.material_formula);
title(axesHandle, sprintf("%s Feff9.6 Calculation for %s in %s unit cell", ...
    xmu.calc, atom, formula));
xlabel(axesHandle, "Energies (eV)");
ylabel(axesHandle, "Absorption Cross-section");
plot(axesHandle, xmu.energies, single, "b", ...
    "DisplayName", sprintf("Single %s %s edge", atom, xmu.edge));
plot(axesHandle, xmu.energies, total, "g", ...
    "DisplayName", sprintf("%s %s edge in %s", ...
    atom, xmu.edge, formula));
legend(axesHandle, "show");
data = struct("energies", xmu.energies, "scross", single, ...
    "across", total, "atom", atom, "formula", formula, ...
    "edge", string(xmu.edge), "calc", string(xmu.calc));
end

function value = onOff(tf)
if tf, value = "on"; else, value = "off"; end
end
