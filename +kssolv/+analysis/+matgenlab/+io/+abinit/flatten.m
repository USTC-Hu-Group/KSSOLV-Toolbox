function output = flatten(input)
%FLATTEN Recursively flatten nested ABINIT input values.
output = {};
visit(input);
output = [output{:}];
    function visit(value)
        if iscell(value)
            for index = 1:numel(value), visit(value{index}); end
        elseif isnumeric(value) || islogical(value)
            for index = 1:numel(value), output{end + 1} = value(index); end %#ok<AGROW>
        else
            output{end + 1} = value;
        end
    end
end
