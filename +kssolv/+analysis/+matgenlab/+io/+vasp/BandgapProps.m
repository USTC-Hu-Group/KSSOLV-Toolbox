classdef BandgapProps < kssolv.analysis.matgenlab.util.MSONable
    %BANDGAPPROPS Band-edge metadata container.
    properties
        vbm = []
        cbm = []
        direct_gap_eigenvalues = []
        efermi = []
        vbm_k = []
        cbm_k = []
        direct_gap_k = []
    end
    methods
        function obj = BandgapProps(options)
            arguments
                options.vbm = []
                options.cbm = []
                options.direct_gap_eigenvalues = []
                options.efermi = []
                options.vbm_k = []
                options.cbm_k = []
                options.direct_gap_k = []
            end
            names = fieldnames(options);
            for index = 1:numel(names)
                obj.(names{index}) = options.(names{index});
            end
        end
        function value = as_dict(obj)
            value = struct("x_module","pymatgen.io.vasp.outputs", ...
                "x_class","BandgapProps","vbm",obj.vbm,"cbm",obj.cbm, ...
                "direct_gap_eigenvalues",obj.direct_gap_eigenvalues, ...
                "efermi",obj.efermi,"vbm_k",obj.vbm_k, ...
                "cbm_k",obj.cbm_k,"direct_gap_k",obj.direct_gap_k);
        end
        function value = asDict(obj), value = obj.as_dict(); end
    end
end
