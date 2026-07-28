function text=hkl_tuple_to_str(hkl)
%HKL_TUPLE_TO_STR Format a Miller index for mathematical plot labels.
parts=strings(1,numel(hkl));
for index=1:numel(hkl)
    value=hkl(index);
    if value<0
        parts(index)="\overline{"+string(-value)+"}";
    else
        parts(index)=string(value);
    end
end
text="($"+join(parts,"")+"$)";
end
