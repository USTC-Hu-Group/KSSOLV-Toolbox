function geometry = process_parsed_coords(coords)
%PROCESS_PARSED_COORDS Convert parsed coordinate tokens to an N-by-3 array.
if isnumeric(coords)
    geometry = double(coords);
elseif iscell(coords)
    geometry = zeros(size(coords, 1), 3);
    for row = 1:size(coords, 1)
        for column = 1:3
            geometry(row, column) = str2double(string(coords{row, column}));
        end
    end
else
    geometry = str2double(string(coords));
end
if size(geometry, 2) ~= 3
    error("KSSOLV:Matgenlab:QChem:Coordinates", ...
        "Parsed coordinates must have exactly three columns.");
end
end
