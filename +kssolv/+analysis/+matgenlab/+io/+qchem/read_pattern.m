function matches = read_pattern(text, patterns, terminate_on_match, postprocess)
%READ_PATTERN Apply named regular expressions and retain all capture groups.
if nargin < 3 || isempty(terminate_on_match), terminate_on_match = false; end
if nargin < 4 || isempty(postprocess), postprocess = @(value) value; end
matches = struct();
names = fieldnames(patterns);
for index = 1:numel(names)
    name = names{index};
    tokens = regexp(char(text), patterns.(name), "tokens");
    if terminate_on_match && ~isempty(tokens), tokens = tokens(1); end
    rows = cell(size(tokens));
    for row = 1:numel(tokens)
        values = tokens{row};
        for column = 1:numel(values)
            values{column} = postprocess(values{column});
        end
        rows{row} = values;
    end
    if ~isempty(rows), matches.(name) = rows; end
end
end
