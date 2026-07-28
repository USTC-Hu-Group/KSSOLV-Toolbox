function [axesHandle, allDos] = main(ldosBase, feffInput, options)
%MAIN Plot total and selected projected DOS from a FEFF LDOS file set.
arguments
    ldosBase {mustBeTextScalar}
    feffInput {mustBeTextScalar}
    options.site (1,1) logical = false
    options.element (1,1) logical = false
    options.orbital (1,1) logical = false
    options.Visible (1,1) logical = false
    options.LDos = []
end
if isempty(options.LDos)
    output = kssolv.analysis.matgenlab.io.feff.LDos.from_file( ...
        feffInput, ldosBase);
else
    output = options.LDos;
end
complete = output.complete_dos;
allDos = containers.Map("KeyType", "char", "ValueType", "any");
allDos("Total") = complete;
structure = complete.structure;
if options.site
    for index = 1:structure.num_sites
        site = structure.sites{index};
        label = sprintf("Site %d %s", index - 1, site.specie.symbol);
        allDos(label) = complete.get_site_dos(site);
    end
end
if options.element
    allDos = mergeMaps(allDos, complete.get_element_dos());
end
if options.orbital
    allDos = mergeMaps(allDos, complete.get_spd_dos());
end
plotter = kssolv.analysis.matgenlab.electronic_structure.DosPlotter();
plotter.add_dos_dict(allDos);
axesHandle = plotter.get_plot();
axesHandle.Parent.Visible = onOff(options.Visible);
end

function target = mergeMaps(target, source)
if isa(source, "containers.Map")
    names = source.keys;
    for index = 1:numel(names), target(names{index}) = source(names{index}); end
else
    names = fieldnames(source);
    for index = 1:numel(names)
        target(names{index}) = source.(names{index});
    end
end
end

function value = onOff(tf)
if tf, value = "on"; else, value = "off"; end
end
