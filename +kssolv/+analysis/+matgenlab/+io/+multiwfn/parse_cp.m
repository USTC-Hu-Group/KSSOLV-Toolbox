function [cpName, descriptor] = parse_cp(lines)
%PARSE_CP Parse one critical-point section from Multiwfn CPprop output.
lines = reshape(string(lines), [], 1);
linesSplit = cell(numel(lines), 1);
for index = 1:numel(lines)
    value = split(strtrim(lines(index)));
    linesSplit{index} = value(strlength(value) > 0);
end
cpName = [];
descriptor = struct();
if isempty(linesSplit) || isempty(linesSplit{1}), return; end
first = string(linesSplit{1});
conditionals = ...
    kssolv.analysis.matgenlab.io.multiwfn.qtaim_conditionals();
if any(first == "(3,-3)")
    cpType = "atom";
    conditionals = rmfield(conditionals, "connected_bond_paths");
elseif any(first == "(3,-1)")
    cpType = "bond";
    conditionals = rmfield(conditionals, "ele_info");
elseif any(first == "(3,+1)")
    cpType = "ring";
    conditionals = rmfield(conditionals, ...
        ["connected_bond_paths", "ele_info"]);
elseif any(first == "(3,+3)")
    cpType = "cage";
    conditionals = rmfield(conditionals, ...
        ["connected_bond_paths", "ele_info"]);
else
    return
end
[cpName, descriptor] = ...
    kssolv.analysis.matgenlab.io.multiwfn. ...
    extract_info_from_cp_text(linesSplit, cpType, conditionals);
end
