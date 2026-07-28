function value = get_tag_object_on_val(tag, input)
%GET_TAG_OBJECT_ON_VAL Select a concrete tag codec based on a value.
value = kssolv.analysis.matgenlab.io.jdftx.get_tag_object(tag);
if isa(value, "kssolv.analysis.matgenlab.io.jdftx.MultiformatTag")
    index = value.get_format_index_for_str_value(tag, string(input));
    value = value.format_options{index + 1};
end
end
