classdef KpointOptProps
    %KPOINTOPTPROPS Namespace for KPOINTS_OPT results in Vasprun.
    properties
        tdos = []
        idos = []
        pdos = []
        efermi = []
        eigenvalues = []
        projected_eigenvalues = []
        projected_magnetization = []
        kpoints = []
        actual_kpoints = []
        actual_kpoints_weights = []
        dos_has_errors = []
    end
    properties (Dependent)
        projected_magnetisation
    end
    methods
        function value = get.projected_magnetisation(obj)
            value = obj.projected_magnetization;
        end
        function obj = set.projected_magnetisation(obj,value)
            obj.projected_magnetization = value;
        end
    end
end
