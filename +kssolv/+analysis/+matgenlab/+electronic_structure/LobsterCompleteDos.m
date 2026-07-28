classdef LobsterCompleteDos < ...
        kssolv.analysis.matgenlab.electronic_structure.CompleteDos
    %LOBSTERCOMPLETEDOS LOBSTER orbital-label variant of CompleteDos.

    methods
        function obj = LobsterCompleteDos(structure, totalDos, pdoss, normalize)
            if nargin < 4, normalize = false; end
            obj@kssolv.analysis.matgenlab.electronic_structure. ...
                CompleteDos(structure, totalDos, pdoss, normalize);
        end

        function value = get_site_orbital_dos(obj, site, orbital)
            label = string(orbital);
            valid = ["s","p_y","p_z","p_x","d_xy","d_yz","d_z^2", ...
                "d_xz","d_x^2-y^2","f_y(3x^2-y^2)","f_xyz", ...
                "f_yz^2","f_z^3","f_xz^2","f_z(x^2-y^2)", ...
                "f_x(x^2-3y^2)"];
            if strlength(label) < 2 || ~any(extractAfter(label, 1) == valid)
                error("KSSOLV:Matgenlab:LobsterCompleteDos:InvalidOrbital", ...
                    "orbital is not correct.");
            end
            value = get_site_orbital_dos@kssolv.analysis.matgenlab. ...
                electronic_structure.CompleteDos(obj, site, orbital);
        end
    end

    methods (Static)
        function obj = from_dict(value)
            base = kssolv.analysis.matgenlab.electronic_structure. ...
                CompleteDos.from_dict(value);
            obj = kssolv.analysis.matgenlab.electronic_structure. ...
                LobsterCompleteDos(base.structure, base, base.pdos);
        end
    end
end
