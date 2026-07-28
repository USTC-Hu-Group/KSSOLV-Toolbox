classdef OutFermi < kssolv.analysis.matgenlab.util.MSONable
    %OUTFERMI Extract the rounded Fermi energy from OUT.FERMI.

    properties (SetAccess = private)
        filename (1,1) string
    end

    properties (Access = private)
        eFermi (1,1) double
    end

    properties (Dependent, SetAccess = private)
        e_fermi
    end

    methods
        function obj = OutFermi(filename)
            obj.filename = string(filename);
            text = ...
                kssolv.analysis.matgenlab.io.pwmat.PWmatIOUtils. ...
                read_text(filename);
            lines = splitlines(text);
            fields = regexp(strtrim(char(lines(1))), '\s+', "split");
            if numel(fields) < 2
                error("KSSOLV:Matgenlab:PWmat:OutFermi", ...
                    "OUT.FERMI first line has too few fields.");
            end
            value = str2double(fields{end - 1});
            if isnan(value)
                error("KSSOLV:Matgenlab:PWmat:OutFermi", ...
                    "OUT.FERMI Fermi energy is not numeric.");
            end
            obj.eFermi = round(value, 3);
        end

        function value = get.e_fermi(obj)
            value = obj.eFermi;
        end

        function value = asDict(obj)
            value = struct("x_module", "pymatgen.io.pwmat.outputs", ...
                "x_class", "OutFermi", "filename", obj.filename);
        end
    end

    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.pwmat.OutFermi( ...
                value.filename);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.io.pwmat.OutFermi. ...
                from_dict(value);
        end
    end
end
