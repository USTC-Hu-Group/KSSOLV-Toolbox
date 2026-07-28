classdef XSFBand < kssolv.analysis.matgenlab.util.MSONable
    %XSFBAND Static three-dimensional BXSF band-grid data.

    properties
        data double
        lattice double
        origin double
        comment (1,1) string = ""
        labels (1,:) string = strings(1, 0)
    end

    properties (Dependent, SetAccess = private)
        shape
        ndim
    end

    methods
        function obj = XSFBand(data, lattice, origin, options)
            arguments
                data double
                lattice double
                origin double
                options.comment (1,1) string = ""
                options.labels = strings(1, 0)
            end
            obj.data = data;
            obj.lattice = lattice;
            obj.origin = reshape(origin, 1, []);
            obj.comment = options.comment;
            obj.labels = reshape(string(options.labels), 1, []);
            if ~isempty(obj.labels) && numel(obj.labels) ~= size(data, 1)
                error("KSSOLV:Matgenlab:XSFBand:LabelCount", ...
                    "XSFBand labels must be empty or match the number of bands");
            end
        end

        function value = get.shape(obj)
            value = [size(obj.data, 1), size(obj.data, 2), ...
                size(obj.data, 3), size(obj.data, 4)];
        end

        function value = get.ndim(~)
            value = 3;
        end

        function value = as_dict(obj)
            value = struct();
            value.x_module = "pymatgen.io.xcrysden";
            value.x_class = "XSFBand";
            value.data = obj.data;
            value.lattice = obj.lattice;
            value.origin = obj.origin;
            value.comment = obj.comment;
            value.labels = obj.labels;
        end

        function value = asDict(obj)
            value = obj.as_dict();
        end
    end

    methods (Static)
        function obj = from_dict(value)
            comment = "";
            labels = strings(1, 0);
            if isfield(value, "comment"), comment = string(value.comment); end
            if isfield(value, "labels"), labels = string(value.labels); end
            obj = kssolv.analysis.matgenlab.io.xcrysden.XSFBand( ...
                double(value.data), double(value.lattice), ...
                double(value.origin), comment = comment, labels = labels);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.io.xcrysden.XSFBand. ...
                from_dict(value);
        end
    end
end
