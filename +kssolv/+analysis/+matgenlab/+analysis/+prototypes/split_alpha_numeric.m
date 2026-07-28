function value=split_alpha_numeric(input)
%SPLIT_ALPHA_NUMERIC Split alternating alphabetic and numeric groups.
groups=regexp(char(string(input)),"[A-Za-z]+|[0-9]+","match");
alpha=string(groups(~cellfun("isempty",regexp(groups, ...
    "^[A-Za-z]+$","once"))));
numeric=string(groups(~cellfun("isempty",regexp(groups, ...
    "^[0-9]+$","once"))));
value=struct(alpha=reshape(alpha,1,[]),numeric=reshape(numeric,1,[]));
end
