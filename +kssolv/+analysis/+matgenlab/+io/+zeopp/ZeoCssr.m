classdef ZeoCssr < kssolv.analysis.matgenlab.io.Cssr
    %ZEOCSSR CSSR representation using Zeo++'s rotated axis convention.

    methods
        function obj = ZeoCssr(structure)
            obj@kssolv.analysis.matgenlab.io.Cssr(structure);
        end

        function text = char(obj)
            lengths = obj.structure.lattice.lengths;
            angles = obj.structure.lattice.angles;
            lines = strings(obj.structure.num_sites + 4, 1);
            lines(1) = string(sprintf("%.4f %.4f %.4f", ...
                lengths(3), lengths(1), lengths(2)));
            lines(2) = string(sprintf( ...
                "%.2f %.2f %.2f SPGR =  1 P 1    OPT = 1", ...
                angles(3), angles(1), angles(2)));
            lines(3) = string(sprintf("%d 0", obj.structure.num_sites));
            lines(4) = "0 " + obj.structure.formula;
            for index = 1:obj.structure.num_sites
                site = obj.structure.get_site(index);
                charge = siteCharge(site);
                fractional = site.frac_coords;
                lines(index + 4) = string(sprintf( ...
                    "%d %s %.4f %.4f %.4f 0 0 0 0 0 0 0 0 %.4f", ...
                    index, site.species_string, fractional(3), ...
                    fractional(1), fractional(2), charge));
            end
            text = char(strjoin(lines, newline));
        end

        function text = string(obj)
            text = string(char(obj));
        end
    end

    methods (Static)
        function obj = from_str(text)
            lines = splitlines(string(text));
            if numel(lines) < 4
                error("KSSOLV:Matgenlab:ZeoCssr:Invalid", ...
                    "A Zeo++ CSSR document requires four header lines.");
            end
            lengths = sscanf(lines(1), "%f", 3).';
            angles = sscanf(lines(2), "%f", 3).';
            if numel(lengths) ~= 3 || numel(angles) ~= 3
                error("KSSOLV:Matgenlab:ZeoCssr:Lattice", ...
                    "Invalid Zeo++ CSSR lattice parameters.");
            end
            lengths = lengths([3, 1, 2]);
            angles = angles([3, 1, 2]);
            lattice = kssolv.analysis.matgenlab.core.Lattice. ...
                from_parameters(lengths(1), lengths(2), lengths(3), ...
                angles(1), angles(2), angles(3));
            maximumSites = max(0, numel(lines) - 4);
            species = strings(maximumSites, 1);
            coordinates = zeros(maximumSites, 3);
            charges = zeros(maximumSites, 1);
            numberOfSites = 0;
            number = "([-+]?(?:\d+\.?\d*|\.\d+)(?:[EeDd][-+]?\d+)?)";
            expression = "^\s*\d+\s+(\S+)\s+" + number + "\s+" + ...
                number + "\s+" + number + "\s+(?:0\s+){8}" + ...
                number + "\s*$";
            for lineIndex = 5:numel(lines)
                tokens = regexp(lines(lineIndex), expression, ...
                    "tokens", "once");
                if isempty(tokens)
                    continue
                end
                numberOfSites = numberOfSites + 1;
                species(numberOfSites) = string(tokens{1});
                zeoCoordinates = parseNumbers(tokens(2:4));
                coordinates(numberOfSites, :) = ...
                    zeoCoordinates([2, 3, 1]);
                charges(numberOfSites) = parseNumbers(tokens(5));
            end
            species = species(1:numberOfSites);
            coordinates = coordinates(1:numberOfSites, :);
            charges = charges(1:numberOfSites);
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, species, coordinates, ...
                site_properties = struct("charge", charges));
            obj = kssolv.analysis.matgenlab.io.zeopp.ZeoCssr(structure);
        end

        function obj = from_file(filename)
            obj = kssolv.analysis.matgenlab.io.zeopp.ZeoCssr. ...
                from_str(readText(filename));
        end
    end
end

function charge = siteCharge(site)
charge = 0;
if isfield(site.site_properties, "charge")
    charge = site.site_properties.charge;
    return
end
specie = site.specie;
if isa(specie, "kssolv.analysis.matgenlab.core.Species") && ...
        isfinite(specie.oxi_state)
    charge = specie.oxi_state;
end
end

function values = parseNumbers(tokens)
values = str2double(replace(string(tokens), ["D", "d"], ["E", "e"]));
end

function text = readText(filename)
filename = string(filename);
if ~isfile(filename)
    error("KSSOLV:Matgenlab:ZeoCssr:MissingFile", ...
        "Zeo++ CSSR file '%s' does not exist.", filename);
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
