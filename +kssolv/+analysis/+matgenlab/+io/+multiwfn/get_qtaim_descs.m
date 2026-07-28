function descriptors = get_qtaim_descs(filename)
%GET_QTAIM_DESCS Parse all critical points from a Multiwfn CPprop file.
lines = splitlines(string(fileread(filename)));
sections = cell(1, 0);
segment = strings(0, 1);
for index = 1:numel(lines)
    if contains(lines(index), "----------------")
        segment = strings(0, 1);
    end
    segment(end + 1) = lines(index); %#ok<AGROW>
    if index == numel(lines) || ...
            contains(lines(index + 1), "----------------")
        sections{end + 1} = segment; %#ok<AGROW>
    end
end
descriptors = containers.Map( ...
    "KeyType", "char", "ValueType", "any");
for index = 1:numel(sections)
    [name, descriptor] = ...
        kssolv.analysis.matgenlab.io.multiwfn. ...
        parse_cp(sections{index});
    if ~isempty(name)
        descriptors(char(name)) = descriptor;
    end
end
end
