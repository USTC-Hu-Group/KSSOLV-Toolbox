function [vasprun, outcar] = get_vasprun_outcar(prev_calc_dir, parse_dos, parse_eigen)
%GET_VASPRUN_OUTCAR Read the latest vasprun.xml and OUTCAR in a directory.
if nargin < 2, parse_dos = true; end
if nargin < 3, parse_eigen = true; end
base = string(prev_calc_dir);
vasprunFiles = dir(fullfile(base, "vasprun.xml*"));
outcarFiles = dir(fullfile(base, "OUTCAR*"));
if isempty(vasprunFiles) || isempty(outcarFiles)
    error("KSSOLV:Matgenlab:VaspInputSet:PreviousOutputs", ...
        "Unable to get vasprun.xml/OUTCAR from '%s'.", base);
end
vasprunNames = sort(string({vasprunFiles.name}));
outcarNames = sort(string({outcarFiles.name}));
if any(vasprunNames == "vasprun.xml"), vasprunName = "vasprun.xml";
else, vasprunName = vasprunNames(end);
end
if any(outcarNames == "OUTCAR.gz"), outcarName = "OUTCAR.gz";
else, outcarName = outcarNames(end);
end
vasprun = kssolv.analysis.matgenlab.io.vasp.Vasprun( ...
    fullfile(base, vasprunName), parse_dos = parse_dos, ...
    parse_eigen = parse_eigen);
outcar = kssolv.analysis.matgenlab.io.vasp.Outcar( ...
    fullfile(base, outcarName));
end
