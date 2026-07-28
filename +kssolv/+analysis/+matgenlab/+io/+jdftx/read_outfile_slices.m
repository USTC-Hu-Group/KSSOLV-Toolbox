function slices = read_outfile_slices(file_name)
%READ_OUTFILE_SLICES Split an output containing appended JDFTx runs.
lines = kssolv.analysis.matgenlab.io.jdftx.read_file(string(file_name));
starts = kssolv.analysis.matgenlab.io.jdftx.get_start_lines( ...
    lines, add_end = true);
slices = cell(1, numel(starts) - 1);
for idx = 1:numel(slices)
    slices{idx} = lines(starts(idx) + 1:starts(idx + 1));
end
end
