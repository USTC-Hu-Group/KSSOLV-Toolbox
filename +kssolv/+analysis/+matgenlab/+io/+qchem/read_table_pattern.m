function output = read_table_pattern(text, headerPattern, rowPattern, ...
        footerPattern, postprocess, attributeName, lastOneOnly)
%READ_TABLE_PATTERN Parse one or more regular table blocks.
if nargin < 5 || isempty(postprocess), postprocess = @(value) value; end
if nargin < 6, attributeName = ""; end
if nargin < 7 || isempty(lastOneOnly), lastOneOnly = false; end
source = char(text);
blockPattern = [headerPattern '\s*(?<table_body>(?:' rowPattern ')+)\s*' footerPattern];
blocks = regexp(source, blockPattern, "names");
tables = cell(1, numel(blocks));
for blockIndex = 1:numel(blocks)
    body = blocks(blockIndex).table_body;
    named = regexp(body, rowPattern, "names");
    if ~isempty(named) && ~isempty(fieldnames(named))
        rows = cell(1, numel(named));
        for row = 1:numel(named)
            item = named(row);
            names = fieldnames(item);
            for fieldIndex = 1:numel(names)
                field = names{fieldIndex};
                item.(field) = postprocess(item.(field));
            end
            rows{row} = item;
        end
    else
        tokens = regexp(body, rowPattern, "tokens");
        rows = cell(1, numel(tokens));
        for row = 1:numel(tokens)
            item = tokens{row};
            for column = 1:numel(item)
                item{column} = postprocess(item{column});
            end
            rows{row} = item;
        end
    end
    tables{blockIndex} = rows;
end
if lastOneOnly && ~isempty(tables), retained = tables{end}; else, retained = tables; end
if strlength(string(attributeName)) > 0
    output = struct();
    output.(matlab.lang.makeValidName(attributeName)) = retained;
else
    output = retained;
end
end
