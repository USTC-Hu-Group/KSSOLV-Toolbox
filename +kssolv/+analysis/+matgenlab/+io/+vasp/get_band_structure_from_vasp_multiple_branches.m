function bandStructure = get_band_structure_from_vasp_multiple_branches( ...
        directory,efermi,projections)
%GET_BAND_STRUCTURE_FROM_VASP_MULTIPLE_BRANCHES Read and reconstruct branches.
if nargin < 2, efermi = []; end
if nargin < 3, projections = false; end
directory = string(directory);
branches = dir(fullfile(directory,"branch_*"));
branches = branches([branches.isdir]);
if isempty(branches)
    direct = fullfile(directory,"vasprun.xml");
    if ~isfile(direct) && isfile(direct+".gz"), direct = direct+".gz"; end
    if ~isfile(direct)
        error("KSSOLV:Matgenlab:VaspParseError", ...
            "Failed to find any vasprun.xml in selected directory.");
    end
    run = kssolv.analysis.matgenlab.io.vasp.Vasprun( ...
        direct,parse_projected_eigen=projections,parse_potcar_file=false);
    bandStructure = run.get_band_structure([],efermi);
    return
end
indices = arrayfun(@(item)str2double(extractAfter( ...
    string(item.name),"branch_")),branches);
[~,order] = sort(indices);
branches = branches(order);
parts = cell(1,numel(branches));
for index = 1:numel(branches)
    path = fullfile(branches(index).folder,branches(index).name,"vasprun.xml");
    if ~isfile(path) && isfile(path+".gz"), path = path+".gz"; end
    if ~isfile(path)
        error("KSSOLV:Matgenlab:VaspParseError", ...
            "Cannot find vasprun.xml in '%s'.",branches(index).name);
    end
    run = kssolv.analysis.matgenlab.io.vasp.Vasprun( ...
        path,parse_projected_eigen=projections,parse_potcar_file=false);
    parts{index} = run.get_band_structure([],efermi);
end
bandStructure = kssolv.analysis.matgenlab.electronic_structure. ...
    get_reconstructed_band_structure(parts,efermi);
end
