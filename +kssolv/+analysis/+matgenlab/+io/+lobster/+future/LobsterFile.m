classdef LobsterFile < handle
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %LOBSTERFILE Shared parser, serialization and versioning base class.
    properties
        filename (1,1) string = ""
        lobster_version (1,1) string = "5.1.1"
        spins cell = {}
        data = []
        interactions cell = {}
        centers cell = {}
        orbitals cell = {}
        populations = struct()
        mulliken double = []
        loewdin double = []
        num_bonds double = []
        num_data double = []
        efermi_value double = []
        band_overlaps = struct()
        fatband = struct()
        matrices = struct()
        matrix_type (1,1) string = ""
        projected_dos = struct()
        total_dos = []
        integrated_total_dos = []
        grid double = []
        points double = []
        distances double = []
        reals double = []
        imaginaries double = []
        structure = []
        final_real = []
        final_imaginary = []
        final_density = []
        volumetricdata_real = []
        volumetricdata_imaginary = []
        volumetricdata_density = []
        ewald_splitting double = []
        madelung_energies_mulliken double = []
        madelung_energies_loewdin double = []
        site_potentials_mulliken double = []
        site_potentials_loewdin double = []
        rel_mulliken_pol_vector = struct()
        rel_loewdin_pol_vector = struct()
        bwdf = struct()
        bin_width double = []
        raw = struct()
    end

    properties (Dependent, SetAccess = private)
        lines
        has_spin
        is_spin_polarized
    end

    methods
        function obj = LobsterFile(filename, process_immediately, lobster_version)
            if nargin == 0, return; end
            if nargin < 1 || isempty(filename), filename = obj.get_default_filename(); end
            if nargin < 2 || isempty(process_immediately), process_immediately = true; end
            if nargin >= 3 && ~isempty(lobster_version)
                obj.lobster_version = string(lobster_version);
            end
            obj.filename = string(java.io.File(char(string(filename))).getCanonicalPath());
            version = obj.get_file_version();
            if strlength(version) > 0, obj.lobster_version = version; end
            if process_immediately, obj.process(); end
        end

        function process(obj)
            if ~isfile(obj.filename)
                error("KSSOLV:Matgenlab:Lobster:MissingFile", ...
                    "LOBSTER file '%s' does not exist.", obj.filename);
            end
            if ismethod(obj, "parse_file")
                obj.parse_file();
            else
                error("KSSOLV:Matgenlab:Lobster:Processor", ...
                    "No parser is registered for %s.", class(obj));
            end
        end

        function version = get_file_version(obj)
            version = "";
            if strlength(obj.filename) == 0 || ~isfile(obj.filename), return; end
            text = kssolv.analysis.matgenlab.io.lobster.read_text(obj.filename);
            token = regexp(text(1:min(numel(text), 4096)), ...
                "(?i)LOBSTER\s*(?:version)?\s*v?(\d+\.\d+(?:\.\d+)?)", ...
                "tokens", "once");
            if ~isempty(token), version = string(token{1}); end
        end

        function name = get_default_filename(~)
            error("KSSOLV:Matgenlab:Lobster:AbstractFilename", ...
                "Concrete LOBSTER parsers must declare a default filename.");
            name = "";
        end

        function value = get.lines(obj)
            text = kssolv.analysis.matgenlab.io.lobster.read_text(obj.filename);
            value = regexp(text, "\r\n|\n|\r", "split");
            if ~isempty(value) && isempty(value{end}), value(end) = []; end
        end

        function output = iterate_lines(obj)
            output = cellfun(@strtrim, obj.lines, "UniformOutput", false);
        end

        function value = get.has_spin(obj)
            value = ~isempty(obj.spins);
        end

        function value = get.is_spin_polarized(obj)
            value = numel(obj.spins) > 1;
        end

        function value = as_dict(obj)
            metadata = metaclass(obj);
            value = struct("x_module", "pymatgen.io.lobster.future", ...
                "x_class", string(metadata.Name), "x_version", []);
            for item = metadata.PropertyList(:).'
                if item.Dependent || item.Constant || ~strcmp(item.GetAccess, "public")
                    continue
                end
                name = item.Name;
                value.(name) = obj.(name);
            end
            value = kssolv.analysis.matgenlab.io.lobster.future.utils. ...
                convert_spin_keys(value);
        end

        function value = asDict(obj), value = obj.as_dict(); end
    end

    methods (Static)
        function valid = check_version(actual, minimum, maximum)
            if nargin < 3, maximum = []; end
            actualParts = sscanf(char(string(actual)), "%d.%d.%d").';
            minimumParts = sscanf(char(string(minimum)), "%d.%d.%d").';
            actualParts(end + 1:3) = 0;
            minimumParts(end + 1:3) = 0;
            valid = kssolv.analysis.matgenlab.io.lobster.future.LobsterFile. ...
                compare_version(actualParts, minimumParts) >= 0;
            if valid && ~isempty(maximum)
                maximumParts = sscanf(char(string(maximum)), "%d.%d.%d").';
                maximumParts(end + 1:3) = 0;
                valid = kssolv.analysis.matgenlab.io.lobster.future.LobsterFile. ...
                    compare_version(actualParts, maximumParts) <= 0;
            end
        end

        function obj = from_dict(value, class_name)
            if nargin < 2 || isempty(class_name)
                if isfield(value, "x_class"), class_name = value.x_class;
                else, class_name = "LobsterFile"; end
            end
            fullName = "kssolv.analysis.matgenlab.io.lobster.future.outputs." + ...
                string(class_name);
            try
                obj = feval(fullName);
            catch
                obj = kssolv.analysis.matgenlab.io.lobster.future.LobsterFile();
            end
            names = fieldnames(value);
            available = string(properties(obj));
            for index = 1:numel(names)
                if startsWith(names{index}, "@") || ...
                        ismember(string(names{index}), ...
                        ["x_module", "x_class", "x_version"]) || ...
                        ~any(available == names{index})
                    continue
                end
                obj.(names{index}) = value.(names{index});
            end
            if ismethod(obj, "process_data_into_interactions") && ~isempty(obj.data)
                obj.process_data_into_interactions();
            end
        end

        function obj = fromDict(value, varargin)
            obj = kssolv.analysis.matgenlab.io.lobster.future.LobsterFile. ...
                from_dict(value, varargin{:});
        end
    end

    methods (Static, Access = private)
        function value = compare_version(first, second)
            difference = first - second;
            index = find(difference ~= 0, 1);
            if isempty(index), value = 0;
            else, value = sign(difference(index)); end
        end
    end
end
