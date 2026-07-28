function [cpName, descriptor] = extract_info_from_cp_text( ...
        linesSplit, cpType, conditionals)
%EXTRACT_INFO_FROM_CP_TEXT Extract descriptors from one Multiwfn CP block.
if nargin < 3
    conditionals = ...
        kssolv.analysis.matgenlab.io.multiwfn.qtaim_conditionals();
end
cpName = "null";
descriptor = struct();
remaining = conditionals;
for lineIndex = 1:numel(linesSplit)
    tokens = string(linesSplit{lineIndex});
    names = fieldnames(remaining);
    for nameIndex = 1:numel(names)
        name = names{nameIndex};
        required = string(remaining.(name));
        if ~all(ismember(required, tokens)), continue; end
        switch name
            case "cp_num"
                descriptor.cp_num = str2double( ...
                    erase(tokens(3), ","));
                cpName = descriptor.cp_num + "_" + string(cpType);
            case "ele_info"
                if tokens(3) == "Unknown"
                    cpName = descriptor.cp_num + "_Unknown";
                    descriptor.number = "Unknown";
                    descriptor.ele = "Unknown";
                else
                    nuclear = strjoin(tokens(3:end), "");
                    openIndex = strfind(nuclear, "(");
                    closeIndex = strfind(nuclear, ")");
                    if isempty(openIndex) || isempty(closeIndex) || ...
                            closeIndex(1) <= openIndex(1)
                        error("KSSOLV:Matgenlab:Multiwfn:Nucleus", ...
                            "Invalid corresponding-nucleus record.");
                    end
                    descriptor.number = extractBefore( ...
                        nuclear, openIndex(1));
                    descriptor.element = extractBetween( ...
                        nuclear, openIndex(1) + 1, closeIndex(1) - 1);
                    cpName = descriptor.number + "_" + descriptor.element;
                end
            case "connected_bond_paths"
                indices = zeros(1, numel(tokens) - 2);
                count = 0;
                candidates = tokens(3:end);
                for tokenIndex = 1:numel(candidates)
                    match = regexp(candidates(tokenIndex), ...
                        "^(\d+)", "tokens", "once");
                    if ~isempty(match)
                        count = count + 1;
                        indices(count) = str2double(match{1});
                    end
                end
                descriptor.connected_bond_paths = indices(1:count);
            case "pos_ang"
                descriptor.pos_ang = reshape( ...
                    str2double(tokens(3:end)), 1, []);
            case "esp_total"
                descriptor.esp_total = str2double(tokens(3));
            case "eig_hess"
                descriptor.eig_hess = ...
                    sum(str2double(tokens(end - 2:end)));
            case {"grad_norm", "lap_norm"}
                descriptor.(name) = str2double( ...
                    string(linesSplit{lineIndex + 2}(end)));
            otherwise
                descriptor.(name) = str2double(tokens(end));
        end
        remaining = rmfield(remaining, name);
        break
    end
end
end
