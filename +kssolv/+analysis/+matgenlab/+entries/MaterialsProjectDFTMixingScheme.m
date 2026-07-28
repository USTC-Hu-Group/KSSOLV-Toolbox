classdef MaterialsProjectDFTMixingScheme < ...
        kssolv.analysis.matgenlab.analysis.compatibility. ...
        MaterialsProjectDFTMixingScheme
    %MATERIALSPROJECTDFTMIXINGSCHEME pymatgen.entries namespace facade.

    methods
        function obj=MaterialsProjectDFTMixingScheme(varargin)
            obj@kssolv.analysis.matgenlab.analysis.compatibility. ...
                MaterialsProjectDFTMixingScheme(varargin{:});
        end

        function data=as_dict(obj)
            data=as_dict@kssolv.analysis.matgenlab.analysis. ...
                compatibility.MaterialsProjectDFTMixingScheme(obj);
            data.x_module="pymatgen.entries.mixing_scheme";
            data.x_class="MaterialsProjectDFTMixingScheme";
        end
    end
end
