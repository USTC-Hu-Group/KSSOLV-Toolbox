function energyData = read_cube_file(filename)
%READ_CUBE_FILE Read a BoltzTraP Gaussian cube energy grid.
lines = splitlines(string(fileread(filename)));
if isempty(lines) || ~contains(lines(1), "CUBE")
    error("KSSOLV:Matgenlab:Boltztrap:CubeFormat", ...
        "CUBE file format not recognized.");
end
atomCount = abs(sscanf(lines(3), "%d", 1));
n1 = abs(sscanf(lines(4), "%d", 1));
n2 = abs(sscanf(lines(5), "%d", 1));
n3 = abs(sscanf(lines(6), "%d", 1));
start = 7 + atomCount;
payload = sscanf(join(lines(start:end), newline), "%f");
expected = n1 * n2 * n3;
if numel(payload) < expected
    error("KSSOLV:Matgenlab:Boltztrap:CubeData", ...
        "Cube contains %d values; expected %d.", numel(payload), expected);
end
energyData = reshape(payload(1:expected), [n3, n2, n1]);
energyData = permute(energyData, [3, 2, 1]) / ryPerEv();
end

function value = ryPerEv()
value = 1 / 13.605693122994;
end
