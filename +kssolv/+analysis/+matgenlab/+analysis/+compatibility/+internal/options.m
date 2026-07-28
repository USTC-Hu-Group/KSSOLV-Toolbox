function output=options(output,input)
%OPTIONS Parse Python-like positional and name-value arguments.
names=fieldnames(output); position=1; index=1;
while index<=numel(input)
    item=input{index};
    if (ischar(item)||isstring(item)) && ...
            any(strcmpi(string(item),string(names)))
        key=names{strcmpi(string(item),string(names))};
        if index==numel(input)
            error("KSSOLV:Matgenlab:Compatibility:Arguments", ...
                "Name-value arguments must occur in pairs.");
        end
        output.(key)=input{index+1}; index=index+2;
    else
        if position>numel(names)
            error("KSSOLV:Matgenlab:Compatibility:Arguments", ...
                "Too many positional arguments.");
        end
        output.(names{position})=item; position=position+1; index=index+1;
    end
end
end
