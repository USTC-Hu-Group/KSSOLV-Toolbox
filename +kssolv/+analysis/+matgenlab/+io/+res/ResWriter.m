classdef ResWriter
    %RESWRITER Serialize a Structure or ComputedStructureEntry as RES.

    properties (Access = private)
        res_
    end

    properties (Dependent, SetAccess = private)
        string
    end

    methods
        function obj = ResWriter(entry)
            if isa(entry, ...
                    "kssolv.analysis.matgenlab.core.ComputedStructureEntry")
                obj.res_ = ...
                    kssolv.analysis.matgenlab.io.res.ResWriter. ...
                    res_from_entry(entry);
            elseif isa(entry, ...
                    "kssolv.analysis.matgenlab.core.IStructure")
                obj.res_ = ...
                    kssolv.analysis.matgenlab.io.res.ResWriter. ...
                    res_from_structure(entry);
            else
                error("KSSOLV:Matgenlab:ResWriter:Type", ...
                    "Expected a Structure or ComputedStructureEntry.");
            end
        end

        function value = get.string(obj)
            value = obj.res_.string();
        end

        function value = char(obj)
            value = char(obj.string);
        end

        function write(obj, filename)
            kssolv.analysis.matgenlab.io.res.ResIOUtils. ...
                write_text(filename, obj.string);
        end
    end

    methods (Static)
        function value = cell_from_lattice(lattice)
            value = kssolv.analysis.matgenlab.io.res.ResCELL(1, ...
                lattice.a, lattice.b, lattice.c, lattice.alpha, ...
                lattice.beta, lattice.gamma);
        end

        function value = sfac_from_sites(sites)
            if ~iscell(sites), sites = num2cell(sites); end
            species = strings(1, 0);
            ions = cell(1, 0);
            for siteIndex = 1:numel(sites)
                site = sites{siteIndex};
                [siteSpecies, occupancies] = site.species.items();
                for speciesIndex = 1:numel(siteSpecies)
                    specie = string(siteSpecies{speciesIndex});
                    number = find(species == specie, 1);
                    if isempty(number)
                        species(end + 1) = specie; %#ok<AGROW>
                        number = numel(species);
                    end
                    spin = [];
                    if isfield(site.site_properties, "magmom")
                        candidate = double(site.site_properties.magmom);
                        if ~isempty(candidate) && candidate ~= 0
                            spin = candidate;
                        end
                    end
                    ions{end + 1} = ...
                        kssolv.analysis.matgenlab.io.res.Ion( ...
                        specie, number, site.frac_coords, ...
                        occupancies(speciesIndex), spin); %#ok<AGROW>
                end
            end
            value = kssolv.analysis.matgenlab.io.res.ResSFAC( ...
                species, ions);
        end

        function value = res_from_structure(structure)
            value = kssolv.analysis.matgenlab.io.res.Res([], ...
                strings(1, 0), ...
                kssolv.analysis.matgenlab.io.res.ResWriter. ...
                cell_from_lattice(structure.lattice), ...
                kssolv.analysis.matgenlab.io.res.ResWriter. ...
                sfac_from_sites(structure.sites));
        end

        function value = res_from_entry(entry)
            data = entry.data;
            seed = "";
            if isfield(data, "seed") && strlength(string(data.seed)) > 0
                seed = string(data.seed);
            end
            if strlength(seed) == 0
                seed = "matgenlab-" + ...
                    regexprep(string(entry.structure.reduced_formula), ...
                    '[^A-Za-z0-9_.-]', '_');
            end
            pressure = fieldNumber(data, "pressure", 0);
            integrated = fieldNumber(data, "isd", 0);
            absolute = fieldNumber(data, "iasd", 0);
            try
                information = entry.structure.get_space_group_info();
                spacegroup = string(information{1});
            catch
                spacegroup = "P1";
            end
            rems = strings(1, 0);
            if isfield(data, "rems")
                rems = reshape(string(data.rems), 1, []);
            end
            title = kssolv.analysis.matgenlab.io.res.AirssTITL( ...
                seed, pressure, entry.structure.volume, entry.energy, ...
                integrated, absolute, spacegroup, 1);
            value = kssolv.analysis.matgenlab.io.res.Res(title, rems, ...
                kssolv.analysis.matgenlab.io.res.ResWriter. ...
                cell_from_lattice(entry.structure.lattice), ...
                kssolv.analysis.matgenlab.io.res.ResWriter. ...
                sfac_from_sites(entry.structure.sites));

            function result = fieldNumber(input, name, fallback)
                result = fallback;
                if isfield(input, name) && ~isempty(input.(name))
                    result = double(input.(name));
                end
            end
        end
    end
end
