function value=sort_separation(separation)
%SORT_SEPARATION Canonicalize the two sides of a three-part separation.
%#ok<*ALIGN>
if numel(separation{1})>numel(separation{3})
    value={sort(separation{3}),sort(separation{2}),sort(separation{1})};
else,value={sort(separation{1}),sort(separation{2}),sort(separation{3})};end
end
