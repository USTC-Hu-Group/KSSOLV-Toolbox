classdef SimpleVaspToComputedEntryDrone < ...
        kssolv.analysis.matgenlab.apps.borg.VaspToComputedEntryDrone
    %SIMPLEVAS PTOCOMPUTEDENTRYDRONE Assimilate compact VASP output files.
    %
    % Parses INCAR, POTCAR, POSCAR, CONTCAR and OSZICAR without loading
    % vasprun.xml. DYNMAT phonon frequencies are included when available.

    methods
        function obj = SimpleVaspToComputedEntryDrone(varargin)
            incStructure = false;
            if ~isempty(varargin)
                if isscalar(varargin)
                    incStructure = varargin{1};
                elseif numel(varargin) == 2 && ...
                        strcmpi(string(varargin{1}), "inc_structure")
                    incStructure = varargin{2};
                else
                    error("KSSOLV:Matgenlab:Borg:Arguments", ...
                        "Expected inc_structure as a positional or name-value argument.");
                end
            end
            obj@kssolv.analysis.matgenlab.apps.borg. ...
                VaspToComputedEntryDrone(incStructure);
        end

        function text = char(~)
            text = 'SimpleVaspToComputedEntryDrone';
        end

        function entry = assimilate(obj, path)
            path = string(path);
            names = directoryNames(path);
            selected = struct();
            try
                if any(names == "relax1") && any(names == "relax2")
                    for name = ["INCAR", "POTCAR", "POSCAR"]
                        candidates = matchingFiles( ...
                            fullfile(path, "relax1"), name + "*");
                        if ~isempty(candidates)
                            selected.(char(name)) = candidates(1);
                        end
                    end
                    for name = ["CONTCAR", "OSZICAR"]
                        candidates = matchingFiles( ...
                            fullfile(path, "relax2"), name + "*");
                        if ~isempty(candidates)
                            selected.(char(name)) = candidates(end);
                        end
                    end
                else
                    for name = ["INCAR", "POTCAR", "CONTCAR", ...
                            "OSZICAR", "POSCAR", "DYNMAT"]
                        candidates = matchingFiles(path, name + "*");
                        if isempty(candidates), continue; end
                        if isscalar(candidates) || ...
                                any(name == ["INCAR", "POTCAR"])
                            selected.(char(name)) = candidates(1);
                        else
                            if name == "POSCAR"
                                selected.(char(name)) = candidates(1);
                            else
                                selected.(char(name)) = candidates(end);
                            end
                            warning("KSSOLV:Matgenlab:Borg:MultipleFiles", ...
                                "%d %s files found. %s is being parsed.", ...
                                numel(candidates), name, ...
                                selected.(char(name)));
                        end
                    end
                end
                required = ["INCAR", "POTCAR", "CONTCAR", ...
                    "OSZICAR", "POSCAR"];
                if ~all(isfield(selected, required))
                    error("KSSOLV:Matgenlab:Borg:MissingVaspFiles", ...
                        "Unable to parse %s as not all necessary files are present! " + ...
                        "SimpleVaspToComputedEntryDrone requires INCAR, POTCAR, " + ...
                        "CONTCAR, OSZICAR, POSCAR to be present.", path);
                end

                poscar = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                    from_file(selected.POSCAR);
                contcar = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                    from_file(selected.CONTCAR);
                incar = kssolv.analysis.matgenlab.io.vasp.Incar. ...
                    from_file(selected.INCAR);
                potcar = kssolv.analysis.matgenlab.io.vasp.Potcar. ...
                    from_file(selected.POTCAR);
                oszicar = kssolv.analysis.matgenlab.io.vasp. ...
                    Oszicar(selected.OSZICAR);

                parameters = struct("hubbards", struct());
                if incar.contains("LDAUU")
                    values = reshape(double(incar.get("LDAUU")), 1, []);
                    symbols = reshape(string(poscar.site_symbols), 1, []);
                    if numel(values) ~= numel(symbols)
                        error("KSSOLV:Matgenlab:Borg:HubbardLength", ...
                            "LDAUU must contain one value per POSCAR site symbol.");
                    end
                    for index = 1:numel(symbols)
                        field = matlab.lang.makeValidName(symbols(index));
                        parameters.hubbards.(field) = values(index);
                    end
                end
                hubbardNames = fieldnames(parameters.hubbards);
                values = zeros(1, numel(hubbardNames));
                for index = 1:numel(hubbardNames)
                    values(index) = ...
                        parameters.hubbards.(hubbardNames{index});
                end
                parameters.is_hubbard = logical( ...
                    incar.get("LDAU", true) && ~isempty(values) && ...
                    sum(values) > 0);
                parameters.run_type = [];
                parameters.potcar_spec = potcar.spec;
                energy = oszicar.final_energy;
                structure = contcar.structure;
                outputData = struct();
                outputData.filename = path;
                outputData.delta_volume = ...
                    structure.volume / poscar.structure.volume - 1;
                if isfield(selected, "DYNMAT")
                    dynmat = kssolv.analysis.matgenlab.io.vasp. ...
                        Dynmat(selected.DYNMAT);
                    outputData.phonon_frequencies = ...
                        dynmat.get_phonon_frequencies();
                end
                if obj.inc_structure
                    entry = kssolv.analysis.matgenlab.core. ...
                        ComputedStructureEntry(structure, energy, ...
                        "parameters", parameters, "data", outputData);
                else
                    entry = kssolv.analysis.matgenlab.core.ComputedEntry( ...
                        structure.composition, energy, ...
                        "parameters", parameters, "data", outputData);
                end
            catch exception
                if exception.identifier == ...
                        "KSSOLV:Matgenlab:Borg:MissingVaspFiles"
                    rethrow(exception)
                end
                warning("KSSOLV:Matgenlab:Borg:SimpleVaspParse", ...
                    "Unable to assimilate %s: %s", path, ...
                    exception.message);
                entry = [];
            end
        end

        function value = as_dict(obj)
            initArgs = struct("inc_structure", obj.inc_structure);
            value = struct();
            value.init_args = initArgs;
            value.x_module = "pymatgen.apps.borg.hive";
            value.x_class = "SimpleVaspToComputedEntryDrone";
        end
    end

    methods (Static)
        function obj = from_dict(value)
            initArgs = value.init_args;
            obj = kssolv.analysis.matgenlab.apps.borg. ...
                SimpleVaspToComputedEntryDrone(initArgs.inc_structure);
        end
    end
end

function names = directoryNames(path)
listing = dir(path);
listing = listing([listing.isdir]);
names = string({listing.name});
names = names(~ismember(names, [".", ".."]));
end

function paths = matchingFiles(parent, pattern)
listing = dir(fullfile(string(parent), string(pattern)));
listing = listing(~[listing.isdir]);
if isempty(listing)
    paths = strings(1,0);
else
    paths = sort(string(fullfile({listing.folder}, {listing.name})));
end
end
