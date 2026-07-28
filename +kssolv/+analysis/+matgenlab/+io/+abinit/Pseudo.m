classdef Pseudo
    properties (SetAccess = protected)
        path string = ""
        header = []
        xc = []
        pseudo_kind string = "NC"
        summary_ string = ""
        dojo_report = []
    end
    properties (Dependent)
        summary
        filepath
        basename
        Z
        Z_val
        type
        element
        symbol
        l_max
        l_local
        isnc
        ispaw
        md5
        supports_soc
        has_dojo_report
        djrepo_path
        has_hints
        nlcc_radius
        has_nlcc
        rcore
        paw_radius
    end
    methods
        function obj = Pseudo(path, header, kind)
            if nargin == 0, return; end
            obj.path = string(path); obj.header = header;
            if nargin >= 3, obj.pseudo_kind = upper(string(kind)); end
            if ~isempty(header)
                obj.summary_ = header.summary;
                pspxc = header.get("pspxc", 0);
                try
                    obj.xc = kssolv.analysis.matgenlab.core.XcFunc.from_abinit_ixc(pspxc);
                catch
                    obj.xc = [];
                end
            end
        end
        function value = get.summary(obj), value = strtrim(obj.summary_); end
        function value = get.filepath(obj)
            p = char(obj.path);
            if isempty(p), value = ""; return; end
            if startsWith(p, filesep), value = string(p);
            else, value = string(fullfile(pwd, p));
            end
        end
        function value = get.basename(obj), [~, n, e] = fileparts(obj.filepath); value = n + e; end
        function value = get.Z(obj), value = obj.header.get("zatom"); end
        function value = get.Z_val(obj), value = obj.header.get("zion"); end
        function value = get.type(obj)
            pieces = split(string(class(obj)), ".");
            value = pieces(end);
        end
        function value = get.element(obj), value = kssolv.analysis.matgenlab.core.Element.from_Z(round(obj.Z)); end
        function value = get.symbol(obj), value = string(obj.element.symbol); end
        function value = get.l_max(obj), value = obj.header.get("lmax"); end
        function value = get.l_local(obj), value = obj.header.get("lloc"); end
        function value = get.isnc(obj), value = obj.pseudo_kind == "NC"; end
        function value = get.ispaw(obj), value = obj.pseudo_kind == "PAW"; end
        function value = get.md5(obj), value = obj.compute_md5(); end
        function value = get.supports_soc(obj)
            if obj.ispaw, value = true; return; end
            if obj.header.get("pspcod", 0) == 8
                value = ismember(obj.header.get("extension_switch", 0), [2, 3]);
            else
                value = false;
            end
        end
        function value = get.has_dojo_report(obj)
            value = isprop(obj, "dojo_report") && ~isempty(obj.dojo_report);
        end
        function value = get.djrepo_path(obj), [p, n] = fileparts(obj.filepath); value = string(fullfile(p, n + ".djrepo")); end
        function value = get.has_hints(obj)
            value = false;
            if ~obj.has_dojo_report, return; end
            value = true;
            for name = ["low", "normal", "high"]
                try, obj.hint_for_accuracy(name); catch, value = false; return; end %#ok<NOCOMMA>
            end
        end
        function value = get.nlcc_radius(obj)
            if ~obj.isnc, value = []; else, value = obj.header.get("rchrg", 0); end
        end
        function value = get.has_nlcc(obj), value = obj.isnc && obj.nlcc_radius > 0; end
        function value = get.rcore(obj)
            if obj.ispaw, value = obj.paw_radius; else, value = []; end
        end
        function value = get.paw_radius(obj)
            if obj.ispaw, value = obj.header.get("r_cut", []); else, value = []; end
        end
        function value = compute_md5(obj)
            bytes = uint8(fileread(obj.filepath));
            digest = java.security.MessageDigest.getInstance("MD5");
            digest.update(bytes);
            raw = typecast(digest.digest(), "uint8");
            value = lower(string(reshape(dec2hex(raw, 2).', 1, [])));
        end
        function value = to_str(obj, varargin)
            lines = ["<" + obj.type + ": " + obj.basename + ">", ...
                "  summary: " + obj.summary, ...
                "  number of valence electrons: " + string(obj.Z_val), ...
                "  maximum angular momentum: " + kssolv.analysis.matgenlab.io.abinit.l2str(obj.l_max), ...
                "  angular momentum for local part: " + kssolv.analysis.matgenlab.io.abinit.l2str(obj.l_local), ...
                "  supports spin-orbit: " + string(obj.supports_soc)];
            if obj.isnc, lines(end + 1) = "  radius for non-linear core correction: " + string(obj.nlcc_radius); end
            value = char(join(lines, newline));
        end
        function value = char(obj), value = obj.to_str(); end
        function value = string(obj), value = string(obj.to_str()); end
        function value = eq(first, second)
            value = isa(second, "kssolv.analysis.matgenlab.io.abinit.Pseudo") && ...
                first.md5 == second.md5;
        end
        function value = ne(first, second), value = ~eq(first, second); end
        function value = as_dict(obj, varargin)
            value = struct("x_module", "pymatgen.io.abinit.pseudos", ...
                "x_class", obj.type, "basename", obj.basename, ...
                "type", obj.type, "symbol", obj.symbol, "Z", obj.Z, ...
                "Z_val", obj.Z_val, "l_max", obj.l_max, ...
                "md5", obj.md5, "filepath", obj.filepath);
        end
        function value = asDict(obj), value = obj.as_dict(); end
        function value = as_tmpfile(obj, tmpdir)
            if nargin < 2 || strlength(string(tmpdir)) == 0
                tmpdir = string(tempname); mkdir(tmpdir);
            end
            target = fullfile(tmpdir, obj.basename);
            copyfile(obj.filepath, target);
            value = kssolv.analysis.matgenlab.io.abinit.Pseudo.from_file(target);
        end
        function value = hint_for_accuracy(obj, accuracy)
            if nargin < 2, accuracy = "normal"; end
            if ~obj.has_dojo_report
                value = kssolv.analysis.matgenlab.io.abinit.Hint(0, 0); return
            end
            report = obj.dojo_report;
            if isfield(report, "hints"), source = report.hints;
            elseif isfield(report, "ppgen_hints"), source = report.ppgen_hints;
            else, value = kssolv.analysis.matgenlab.io.abinit.Hint(0, 0); return
            end
            value = kssolv.analysis.matgenlab.io.abinit.Hint.from_dict(source.(char(accuracy)));
        end
        function value = open_pspsfile(varargin)
            value = []; %#ok<NASGU>
            error("KSSOLV:Matgenlab:Abinit:ExternalExecutable", ...
                "open_pspsfile requires an installed ABINIT executable and is an explicit external-runtime boundary.");
        end
    end
    methods (Static)
        function obj = as_pseudo(value)
            if isa(value, "kssolv.analysis.matgenlab.io.abinit.Pseudo"), obj = value;
            else, obj = kssolv.analysis.matgenlab.io.abinit.Pseudo.from_file(value);
            end
        end
        function obj = from_file(filename)
            parser = kssolv.analysis.matgenlab.io.abinit.PseudoParser();
            obj = parser.parse(filename);
        end
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.abinit.Pseudo.from_file(value.filepath);
            if isfield(value, "md5") && string(value.md5) ~= obj.md5
                error("KSSOLV:Matgenlab:Abinit:PseudoChecksum", ...
                    "Pseudopotential checksum does not match serialized metadata.");
            end
        end
        function obj = fromDict(value), obj = kssolv.analysis.matgenlab.io.abinit.Pseudo.from_dict(value); end
    end
end
