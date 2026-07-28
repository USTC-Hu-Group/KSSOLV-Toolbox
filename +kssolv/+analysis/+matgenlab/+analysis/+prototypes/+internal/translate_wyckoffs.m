function output=translate_wyckoffs(input,mapping)
%TRANSLATE_WYCKOFFS Apply a simultaneous ASCII-code relabeling.
characters=char(string(input));output=characters;
fields=fieldnames(mapping);
for index=1:numel(fields)
    code=str2double(regexprep(fields{index},"^[A-Za-z]+",""));
    if isnan(code),continue,end
    output(characters==char(code))=char(string(mapping.(fields{index})));
end
output=string(output);
end
