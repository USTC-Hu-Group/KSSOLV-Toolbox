classdef AirssProvider < kssolv.analysis.matgenlab.io.res.ResProvider
    %AIRSSPROVIDER AIRSS-specific metadata access for RES files.

    properties
        parse_rems (1,1) string = "gentle"
    end

    properties (Access = private)
        title_
    end

    properties (Dependent, SetAccess = private)
        seed
        pressure
        volume
        energy
        integrated_spin_density
        integrated_absolute_spin_density
        spacegroup_label
        appearances
        entry
    end

    methods
        function obj = AirssProvider(res, parseRems)
            if nargin == 0
                error("KSSOLV:Matgenlab:ResError", ...
                    "AirssProvider requires a parsed RES object.");
            end
            if nargin < 2, parseRems = "gentle"; end
            obj@kssolv.analysis.matgenlab.io.res.ResProvider(res);
            if isempty(res.TITL)
                error("KSSOLV:Matgenlab:ResError", ...
                    "AirssProvider can only be constructed from a RES file with a valid TITL entry.");
            end
            parseRems = string(parseRems);
            if ~isscalar(parseRems) || ...
                    ~ismember(parseRems, ["gentle", "strict"])
                error("KSSOLV:Matgenlab:AirssProvider:ParseMode", ...
                    "%s is not valid; use 'gentle' or 'strict'.", parseRems);
            end
            obj.title_ = res.TITL;
            obj.parse_rems = parseRems;
        end

        function value = get.seed(obj), value = obj.title_.seed; end
        function value = get.pressure(obj), value = obj.title_.pressure; end
        function value = get.volume(obj), value = obj.title_.volume; end
        function value = get.energy(obj), value = obj.title_.energy; end
        function value = get.integrated_spin_density(obj)
            value = obj.title_.integrated_spin_density;
        end
        function value = get.integrated_absolute_spin_density(obj)
            value = obj.title_.integrated_absolute_spin_density;
        end
        function value = get.spacegroup_label(obj)
            value = obj.title_.spacegroup_label;
        end
        function value = get.appearances(obj)
            value = obj.title_.appearances;
        end
        function value = get.entry(obj)
            value = kssolv.analysis.matgenlab.core. ...
                ComputedStructureEntry(obj.structure, obj.energy, ...
                "data", struct("rems", obj.rems));
        end

        function value = get_run_start_info(obj)
            value = [];
            for rem = obj.rems
                if startsWith(strtrim(rem), "Run started:")
                    value = {obj.parse_date(rem), ...
                        string(regexp(char(rem), '\S+$', ...
                        'match', 'once'))};
                    return
                end
            end
            obj.fail("Could not find run started information.");
        end

        function value = get_castep_version(obj)
            value = [];
            for rem = obj.rems
                if startsWith(strtrim(rem), "CASTEP")
                    fields = regexp(strtrim(char(rem)), '\s+', 'split');
                    version = fields{2};
                    value = string(version(1:end - 1));
                    return
                end
            end
            obj.fail("No CASTEP version found in REM.");
        end

        function value = get_func_rel_disp(obj)
            value = [];
            for rem = obj.rems
                if startsWith(strtrim(rem), "Functional")
                    fields = string(regexp(strtrim(char(rem)), ...
                        '\s+', 'split'));
                    if numel(fields) < 8
                        obj.fail("Malformed functional REM entry.");
                        return
                    end
                    value = {strjoin(fields(2:4), " "), fields(6), ...
                        fields(8)};
                    return
                end
            end
            obj.fail("Could not find functional, relativity, and dispersion.");
        end

        function value = get_cut_grid_gmax_fsbc(obj)
            value = [];
            for rem = obj.rems
                if startsWith(strtrim(rem), "Cut-off")
                    fields = string(regexp(strtrim(char(rem)), ...
                        '\s+', 'split'));
                    if numel(fields) < 11
                        obj.fail("Malformed cut-off REM entry.");
                        return
                    end
                    value = {str2double(fields(2)), ...
                        str2double(fields(6)), str2double(fields(8)), ...
                        fields(11)};
                    if any(isnan([value{1:3}]))
                        obj.fail("Malformed numeric cut-off REM entry.");
                        value = [];
                    end
                    return
                end
            end
            obj.fail("Could not find line with cut-off energy.");
        end

        function value = get_mpgrid_offset_nkpts_spacing(obj)
            value = [];
            for rem = obj.rems
                if startsWith(strtrim(rem), "MP grid")
                    fields = string(regexp(strtrim(char(rem)), ...
                        '\s+', 'split'));
                    if numel(fields) < 14
                        obj.fail("Malformed MP grid REM entry.");
                        return
                    end
                    grid = str2double(fields(3:5));
                    offsets = str2double(fields(7:9));
                    points = str2double(fields(12));
                    spacing = str2double(fields(14));
                    if any(isnan([grid, offsets, points, spacing]))
                        obj.fail("Malformed numeric MP grid REM entry.");
                        return
                    end
                    value = {grid, offsets, points, spacing};
                    return
                end
            end
            obj.fail("Could not find line with MP grid.");
        end

        function value = get_airss_version(obj)
            value = [];
            for rem = obj.rems
                if startsWith(strtrim(rem), "AIRSS Version")
                    fields = regexp(strtrim(char(rem)), '\s+', 'split');
                    value = {string(fields{3}), obj.parse_date(rem)};
                    return
                end
            end
            obj.fail("Could not find line with AIRSS version.");
        end

        function value = get_pspots(obj)
            value = struct();
            for rem = obj.rems
                fields = regexp(strtrim(char(rem)), '\s+', 'split');
                if numel(fields) == 2 && ...
                        kssolv.analysis.matgenlab.core.Element. ...
                        is_valid_symbol(fields{1})
                    value.(fields{1}) = string(fields{2});
                end
            end
        end

        function value = as_dict(obj, verbose)
            if nargin < 2, verbose = true; end
            if verbose
                value = struct("x_module", "pymatgen.io.res", ...
                    "x_class", "AirssProvider", ...
                    "res", obj.res_.as_dict(), ...
                    "parse_rems", obj.parse_rems);
                return
            end
            value = obj.title_.as_dict();
            value.structure = obj.structure.as_dict();
            value.rems = obj.rems;
        end

        function value = asDict(obj, varargin)
            value = obj.as_dict(varargin{:});
        end
    end

    methods (Access = private)
        function fail(obj, message)
            if obj.parse_rems == "strict"
                error("KSSOLV:Matgenlab:ResParseError", "%s", message);
            end
        end
    end

    methods (Static)
        function obj = from_str(source, parseRems)
            if nargin < 2, parseRems = "gentle"; end
            obj = kssolv.analysis.matgenlab.io.res.AirssProvider( ...
                kssolv.analysis.matgenlab.io.res.ResParser. ...
                parse_str(source), parseRems);
        end

        function obj = from_file(filename, parseRems)
            if nargin < 2, parseRems = "gentle"; end
            obj = kssolv.analysis.matgenlab.io.res.AirssProvider( ...
                kssolv.analysis.matgenlab.io.res.ResParser. ...
                parse_file(filename), parseRems);
        end

        function obj = from_dict(value)
            mode = "gentle";
            if isfield(value, "parse_rems"), mode = value.parse_rems; end
            obj = kssolv.analysis.matgenlab.io.res.AirssProvider( ...
                kssolv.analysis.matgenlab.io.res.Res.from_dict(value.res), ...
                mode);
        end
    end

    methods (Static, Access = private)
        function value = parse_date(text)
            expression = ['[MTWFS][a-z]{2},\s+(\d{2})\s+' ...
                '([A-Z][a-z]{2})\s+(\d{4})\s+\d{2}:\d{2}:\d{2}\s+' ...
                '[+-]?\d{4}'];
            fields = regexp(char(text), expression, 'tokens', 'once');
            if isempty(fields)
                error("KSSOLV:Matgenlab:ResParseError", ...
                    "Could not parse the date from '%s'.", text);
            end
            value = datetime(strjoin(string(fields(1:3)), " "), ...
                "InputFormat", "dd MMM yyyy", "Locale", "en_US");
            value.Format = "yyyy-MM-dd";
        end
    end
end
