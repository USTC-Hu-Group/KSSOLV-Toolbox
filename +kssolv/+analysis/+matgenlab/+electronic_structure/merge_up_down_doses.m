function result = merge_up_down_doses(up, down)
%MERGE_UP_DOWN_DOSES Merge independently computed spin-resolved DOS data.
densities = struct("up", up.densities.up, "down", down.densities.down);
total = kssolv.analysis.matgenlab.electronic_structure.Dos( ...
    up.efermi, up.energies, densities);
if isa(up, "kssolv.analysis.matgenlab.electronic_structure.CompleteDos") && ...
        isa(down, "kssolv.analysis.matgenlab.electronic_structure.CompleteDos")
    pdos = up.pdos;
    for siteIndex = 1:numel(pdos)
        names = fieldnames(pdos{siteIndex});
        for orbitalIndex = 1:numel(names)
            name = names{orbitalIndex};
            pdos{siteIndex}.(name).down = ...
                down.pdos{siteIndex}.(name).down;
        end
    end
    result = kssolv.analysis.matgenlab.electronic_structure. ...
        CompleteDos(up.structure, total, pdos);
else
    result = total;
end
end
