function value=prefix_wyckoff_counts(value)
%PREFIX_WYCKOFF_COUNTS Insert a count of one before unprefixed letters.
value=regexprep(string(value),"(?<![0-9])([A-Za-z])","1$1");
end
