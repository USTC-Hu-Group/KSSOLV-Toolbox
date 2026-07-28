classdef ZeoVoronoiXYZ < kssolv.analysis.matgenlab.io.xyz.XYZ
    %ZEOVORONOIXYZ Zeo++ Voronoi-node XYZ representation with node radii.

    methods
        function obj = ZeoVoronoiXYZ(molecule)
            obj@kssolv.analysis.matgenlab.io.xyz.XYZ(molecule, 6);
        end

        function text = char(obj)
            molecule = obj.molecule;
            lines = strings(molecule.num_sites + 2, 1);
            lines(1) = string(molecule.num_sites);
            lines(2) = molecule.formula;
            for index = 1:molecule.num_sites
                site = molecule.get_site(index);
                if ~isfield(site.site_properties, "voronoi_radius")
                    error("KSSOLV:Matgenlab:ZeoVoronoiXYZ:Radius", ...
                        "Every Voronoi node must define voronoi_radius.");
                end
                coordinates = site.coords;
                lines(index + 2) = sprintf( ...
                    "%s %.6f %.6f %.6f %.6f", ...
                    site.specie.symbol, coordinates(3), coordinates(1), ...
                    coordinates(2), site.site_properties.voronoi_radius);
            end
            text = char(strjoin(lines, newline));
        end

        function text = string(obj)
            text = string(char(obj));
        end
    end

    methods (Static)
        function obj = from_str(contents)
            lines = splitlines(string(contents));
            if isempty(lines)
                error("KSSOLV:Matgenlab:ZeoVoronoiXYZ:Empty", ...
                    "Voronoi XYZ content is empty.");
            end
            numberOfSites = str2double(strtrim(lines(1)));
            if ~isfinite(numberOfSites) || numberOfSites < 0 || ...
                    numberOfSites ~= fix(numberOfSites)
                error("KSSOLV:Matgenlab:ZeoVoronoiXYZ:AtomCount", ...
                    "The first line must contain a nonnegative atom count.");
            end
            if numel(lines) < numberOfSites + 2
                error("KSSOLV:Matgenlab:ZeoVoronoiXYZ:Truncated", ...
                    "Voronoi XYZ contains fewer sites than declared.");
            end
            species = strings(numberOfSites, 1);
            coordinates = zeros(numberOfSites, 3);
            radii = zeros(numberOfSites, 1);
            number = "([-+]?(?:\d+\.?\d*|\.\d+)(?:[EeDd][-+]?\d+)?)";
            expression = "^\s*(\w+)\s+" + number + "\s+" + number + ...
                "\s+" + number + "\s+" + number;
            for index = 1:numberOfSites
                tokens = regexp(lines(index + 2), expression, ...
                    "tokens", "once");
                if isempty(tokens)
                    error("KSSOLV:Matgenlab:ZeoVoronoiXYZ:Coordinate", ...
                        "Invalid Voronoi coordinate on line %d.", index + 2);
                end
                species(index) = string(tokens{1});
                zeoCoordinates = parseNumbers(tokens(2:4));
                coordinates(index, :) = zeoCoordinates([2, 3, 1]);
                radii(index) = parseNumbers(tokens(5));
            end
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                species, coordinates, ...
                site_properties = struct("voronoi_radius", radii), ...
                charge_spin_check = false);
            obj = kssolv.analysis.matgenlab.io.zeopp. ...
                ZeoVoronoiXYZ(molecule);
        end

        function obj = from_file(filename)
            obj = kssolv.analysis.matgenlab.io.zeopp.ZeoVoronoiXYZ. ...
                from_str(readText(filename));
        end
    end
end

function values = parseNumbers(tokens)
values = str2double(replace(string(tokens), ["D", "d"], ["E", "e"]));
end

function text = readText(filename)
filename = string(filename);
if ~isfile(filename)
    error("KSSOLV:Matgenlab:ZeoVoronoiXYZ:MissingFile", ...
        "Voronoi XYZ file '%s' does not exist.", filename);
end
if endsWith(lower(filename), ".gz")
    folder = string(tempname);
    mkdir(folder);
    cleanup = onCleanup(@() removeFolder(folder));
    files = gunzip(filename, folder);
    text = fileread(files{1});
    clear cleanup
else
    text = fileread(filename);
end
end

function removeFolder(folder)
if isfolder(folder)
    rmdir(folder, "s");
end
end
