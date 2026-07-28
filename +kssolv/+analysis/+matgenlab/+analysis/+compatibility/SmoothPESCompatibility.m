classdef SmoothPESCompatibility < kssolv.analysis.matgenlab.analysis.compatibility.MaterialsProject2020Compatibility
    %SMOOTHPESCOMPATIBILITY Smooth PBE/PBE+U potential-energy alignment.
    methods
        function obj=SmoothPESCompatibility(varargin)
            hasConfig=false;
            for index=1:2:numel(varargin)
                if ischar(varargin{index})||isstring(varargin{index})
                    hasConfig=strcmpi(string(varargin{index}),"config_file");
                    if hasConfig,break,end
                end
            end
            if ~hasConfig
                varargin=[varargin,{"config_file", ...
                    kssolv.analysis.matgenlab.analysis.compatibility. ...
                    internal.config_path("SmoothPESCompatibility.yaml")}];
            end
            obj@kssolv.analysis.matgenlab.analysis.compatibility. ...
                MaterialsProject2020Compatibility(varargin{:});
        end
    end
end
