function value = is_lowdin_start_line(line_text)
%IS_LOWDIN_START_LINE Identify a Lowdin population-analysis header.
value = contains(string(line_text), "#--- Lowdin population analysis ---");
end
