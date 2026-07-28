function projections = get_proj_tju_from_file(bandfile_filepath)
%GET_PROJ_TJU_FROM_FILE Parse JDFTx band projections in state-band-orbital order.
lines = string(kssolv.analysis.matgenlab.io.jdftx. ...
    read_file(string(bandfile_filepath)));
header = regexp(lines(1), ...
    "^(\d+) states,\s*(\d+) bands,\s*(\d+) .*projections,\s*(\d+) species", ...
    "tokens", "once");
if isempty(header)
    error("KSSOLV:Matgenlab:JDFTX:BandProjectionHeader", ...
        "Invalid bandProjections header.");
end
nstates = str2double(header{1});
nbands = str2double(header{2});
nproj = str2double(header{3});
nspecies = str2double(header{4});
is_complex = ~contains(lines(2), "|projection|^2");
if is_complex
    projections = complex(zeros(nstates, nbands, nproj, "single"));
else
    projections = zeros(nstates, nbands, nproj, "single");
end
cursor = nspecies + 3;
for state = 1:nstates
    if cursor > numel(lines) || ~startsWith(strtrim(lines(cursor)), "#")
        error("KSSOLV:Matgenlab:JDFTX:BandProjectionShape", ...
            "Missing state header %d.", state - 1);
    end
    cursor = cursor + 1;
    for band = 1:nbands
        values = sscanf(lines(cursor), "%f").';
        if is_complex
            if numel(values) ~= 2 * nproj
                error("KSSOLV:Matgenlab:JDFTX:BandProjectionShape", ...
                    "Projection row has the wrong width.");
            end
            projections(state, band, :) = complex( ...
                single(values(1:2:end)), single(values(2:2:end)));
        else
            projections(state, band, :) = single(values(1:nproj));
        end
        cursor = cursor + 1;
    end
end
end
