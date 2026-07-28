function output=options(defaults,input)
%OPTIONS Parse positional and name-value arguments.
output=defaults;names=fieldnames(defaults);position=1;index=1;
while index<=numel(input)
    if (ischar(input{index})||isstring(input{index}))&& ...
            index<numel(input)&&any(strcmpi(string(input{index}),string(names)))
        match=find(strcmpi(string(input{index}),string(names)),1);
        output.(names{match})=input{index+1};index=index+2;
    else
        if position>numel(names)
            error("KSSOLV:Matgenlab:Magnetism:Arguments", ...
                "Too many positional arguments.");
        end
        output.(names{position})=input{index};position=position+1;index=index+1;
    end
end
end
