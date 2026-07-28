classdef ResProvider < kssolv.analysis.matgenlab.util.MSONable
    %RESPROVIDER Expose parsed RES records as matgenlab core objects.

    properties (Access = protected)
        res_
    end

    properties (Dependent, SetAccess = private)
        rems
        lattice
        sites
        structure
    end

    methods
        function obj = ResProvider(res)
            if nargin == 0
                res = kssolv.analysis.matgenlab.io.res.Res();
            end
            obj.res_ = res;
        end

        function value = get.rems(obj)
            value = obj.res_.REMS;
        end

        function value = get.lattice(obj)
            cellRecord = obj.res_.CELL;
            value = kssolv.analysis.matgenlab.core.Lattice. ...
                from_parameters(cellRecord.a, cellRecord.b, cellRecord.c, ...
                cellRecord.alpha, cellRecord.beta, cellRecord.gamma);
        end

        function value = get.sites(obj)
            ions = obj.res_.SFAC.ions;
            value = cell(1, numel(ions));
            latticeValue = obj.lattice;
            for index = 1:numel(ions)
                ion = ions{index};
                siteProperties = struct();
                if ~isempty(ion.spin)
                    siteProperties.magmom = ion.spin;
                end
                value{index} = ...
                    kssolv.analysis.matgenlab.core.PeriodicSite( ...
                    ion.specie, ion.pos, latticeValue, ...
                    properties = siteProperties);
            end
        end

        function value = get.structure(obj)
            value = kssolv.analysis.matgenlab.core.Structure. ...
                from_sites(obj.sites);
        end

        function value = as_dict(obj)
            value = struct("x_module", "pymatgen.io.res", ...
                "x_class", classLeaf(obj), ...
                "res", obj.res_.as_dict());
            function name = classLeaf(input)
                parts = split(string(class(input)), ".");
                name = parts(end);
            end
        end

        function value = asDict(obj)
            value = obj.as_dict();
        end
    end

    methods (Static)
        function obj = from_str(source)
            obj = kssolv.analysis.matgenlab.io.res.ResProvider( ...
                kssolv.analysis.matgenlab.io.res.ResParser. ...
                parse_str(source));
        end

        function obj = from_file(filename)
            obj = kssolv.analysis.matgenlab.io.res.ResProvider( ...
                kssolv.analysis.matgenlab.io.res.ResParser. ...
                parse_file(filename));
        end

        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.res.ResProvider( ...
                kssolv.analysis.matgenlab.io.res.Res.from_dict(value.res));
        end
    end
end
