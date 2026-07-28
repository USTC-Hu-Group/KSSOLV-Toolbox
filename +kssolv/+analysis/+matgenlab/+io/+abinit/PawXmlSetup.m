classdef PawXmlSetup < kssolv.analysis.matgenlab.io.abinit.PawPseudo
    properties (SetAccess = private)
        paw_setup_version string = ""
        core double = NaN
        valence double = NaN
        valence_states struct = struct()
        rad_grids struct = struct()
    end
    properties (Dependent)
        root
        pseudo_partial_waves
        projector_functions
        ae_partial_waves
        ae_core_density
        pseudo_core_density
    end
    methods
        function obj = PawXmlSetup(filepath)
            text = string(fileread(filepath));
            atom = regexp(text, '<atom\s+([^>]*)/>', 'tokens', 'once');
            attrs = kssolv.analysis.matgenlab.io.abinit.PawXmlSetup.attrs(atom{1});
            z = str2double(attrs.Z); coreValue = str2double(attrs.core);
            valenceValue = str2double(attrs.valence);
            paw = regexp(text, '<PAW_radius\s+([^>]*)/>', 'tokens', 'once');
            if isempty(paw), radius = []; else, pa = kssolv.analysis.matgenlab.io.abinit.PawXmlSetup.attrs(paw{1}); radius = str2double(pa.rpaw); end
            hdr = kssolv.analysis.matgenlab.io.abinit.PawAbinitHeader("", ...
                struct("zatom", z, "zion", valenceValue, "lmax", 0, ...
                "lloc", 0, "pspxc", 11, "r_cut", radius));
            obj@kssolv.analysis.matgenlab.io.abinit.PawPseudo(filepath, hdr);
            obj.core = coreValue; obj.valence = valenceValue;
            v = regexp(text, '<paw_setup\s+([^>]*)>', 'tokens', 'once');
            if ~isempty(v), a = kssolv.analysis.matgenlab.io.abinit.PawXmlSetup.attrs(v{1}); obj.paw_setup_version = string(a.version); end
            xcToken = regexp(text, '<xc_functional\s+([^>]*)/>', 'tokens', 'once');
            if ~isempty(xcToken)
                x = kssolv.analysis.matgenlab.io.abinit.PawXmlSetup.attrs(xcToken{1});
                obj.xc = kssolv.analysis.matgenlab.core.XcFunc.from_type_name(x.type, x.name);
            end
            gridTokens = regexp(text, '<radial_grid\s+([^>]*)/>', 'tokens');
            for i = 1:numel(gridTokens)
                a = kssolv.analysis.matgenlab.io.abinit.PawXmlSetup.attrs(gridTokens{i}{1});
                obj.rad_grids.(matlab.lang.makeValidName(a.id)) = ...
                    kssolv.analysis.matgenlab.io.abinit.PawXmlSetup.evalGrid(a);
            end
            stateTokens = regexp(text, '<state\s+([^>]*)/>', 'tokens');
            for i = 1:numel(stateTokens)
                a = kssolv.analysis.matgenlab.io.abinit.PawXmlSetup.attrs(stateTokens{i}{1});
                if isfield(a, "id"), obj.valence_states.(matlab.lang.makeValidName(a.id)) = a; end
            end
        end
        function value = get.root(obj)
            value = matlab.io.xml.dom.Parser.parseFile(char(obj.filepath)).getDocumentElement();
        end
        function value = get.ae_core_density(obj), value = obj.parseOne("ae_core_density"); end
        function value = get.pseudo_core_density(obj), value = obj.parseOne("pseudo_core_density"); end
        function value = get.ae_partial_waves(obj), value = obj.parseAll("ae_partial_wave"); end
        function value = get.pseudo_partial_waves(obj), value = obj.parseAll("pseudo_partial_wave"); end
        function value = get.projector_functions(obj), value = obj.parseAll("projector_function"); end
        function figs = yield_figs(obj, varargin)
            figs = [obj.plot_densities(varargin{:}), obj.plot_waves(varargin{:}), obj.plot_projectors(varargin{:})];
        end
        function fig = plot_densities(obj, varargin)
            ax = kssolv.analysis.matgenlab.io.abinit.PawXmlSetup.axesFrom(varargin{:});
            a = obj.ae_core_density; p = obj.pseudo_core_density;
            plot(ax, a.mesh, a.mesh .* a.values, "DisplayName", "AE core"); hold(ax, "on");
            plot(ax, p.mesh, p.mesh .* p.values, "DisplayName", "Pseudo core");
            grid(ax, "on"); xlabel(ax, "r [Bohr]"); legend(ax, "show"); fig = ancestor(ax, "figure");
        end
        function fig = plot_waves(obj, varargin)
            ax = kssolv.analysis.matgenlab.io.abinit.PawXmlSetup.axesFrom(varargin{:}); hold(ax, "on");
            obj.plotSet(ax, obj.pseudo_partial_waves, "PS");
            obj.plotSet(ax, obj.ae_partial_waves, "AE");
            grid(ax, "on"); xlabel(ax, "r [Bohr]"); legend(ax, "show"); fig = ancestor(ax, "figure");
        end
        function fig = plot_projectors(obj, varargin)
            ax = kssolv.analysis.matgenlab.io.abinit.PawXmlSetup.axesFrom(varargin{:}); hold(ax, "on");
            obj.plotSet(ax, obj.projector_functions, "Projector");
            grid(ax, "on"); xlabel(ax, "r [Bohr]"); legend(ax, "show"); fig = ancestor(ax, "figure");
        end
    end
    methods (Access = private)
        function value = parseOne(obj, tag)
            allValues = obj.parseAll(tag); names = fieldnames(allValues);
            if isempty(names), value = kssolv.analysis.matgenlab.io.abinit.RadialFunction(); else, value = allValues.(names{1}); end
        end
        function result = parseAll(obj, tag)
            text = fileread(obj.filepath);
            tag = char(string(tag));
            pat = ['<' tag '\s+([^>]*)>([\s\S]*?)</' tag '>'];
            tokens = regexp(text, pat, 'tokens'); result = struct();
            for i = 1:numel(tokens)
                attributeText = char(string(tokens{i}{1}));
                gridToken = regexp(attributeText, 'grid\s*=\s*["'']\s*([^"'']+?)\s*["'']', 'tokens', 'once');
                values = sscanf(char(regexprep(string(tokens{i}{2}), '[Dd]', 'E')), '%f').';
                mesh = obj.rad_grids.(matlab.lang.makeValidName(gridToken{1}));
                stateToken = regexp(attributeText, 'state\s*=\s*["'']\s*([^"'']+?)\s*["'']', 'tokens', 'once');
                if ~isempty(stateToken), key = matlab.lang.makeValidName(stateToken{1});
                else, key = matlab.lang.makeValidName(tag);
                end
                result.(key) = kssolv.analysis.matgenlab.io.abinit.RadialFunction(mesh, values);
            end
        end
        function plotSet(~, ax, values, prefix)
            names = fieldnames(values);
            for i = 1:numel(names)
                r = values.(names{i}); plot(ax, r.mesh, r.mesh .* r.values, ...
                    "DisplayName", prefix + " " + names{i});
            end
        end
    end
    methods (Static, Access = private)
        function result = attrs(text)
            pairs = regexp(char(text), '(\w+)\s*=\s*["'']\s*([^"'']*?)\s*["'']', 'tokens');
            result = struct();
            for i = 1:numel(pairs), result.(pairs{i}{1}) = pairs{i}{2}; end
        end
        function mesh = evalGrid(a)
            first = str2double(a.istart); last = str2double(a.iend); i = first:last;
            eq = replace(string(a.eq), " ", "");
            if eq == "r=a*exp(d*i)"
                mesh = str2double(a.a) * exp(str2double(a.d) * i);
            elseif eq == "r=a*i/(n-i)"
                mesh = str2double(a.a) * i ./ (str2double(a.n) - i);
            elseif eq == "r=a*(exp(d*i)-1)"
                mesh = str2double(a.a) * (exp(str2double(a.d) * i) - 1);
            elseif eq == "r=d*i"
                mesh = str2double(a.d) * i;
            elseif eq == "r=(i/n+a)^5/a-a^4"
                av = str2double(a.a); mesh = (i / str2double(a.n) + av).^5 / av - av^4;
            else
                error("KSSOLV:Matgenlab:Abinit:PawGrid", "Unknown PAW radial grid equation %s.", eq);
            end
        end
        function ax = axesFrom(varargin)
            ax = [];
            for i = 1:2:numel(varargin)
                if strcmpi(string(varargin{i}), "ax"), ax = varargin{i + 1}; end
            end
            if isempty(ax), fig = figure("Visible", "off"); ax = axes(fig); end
        end
    end
end
