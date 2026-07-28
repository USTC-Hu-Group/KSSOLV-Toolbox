classdef AddSitePropertyTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess = private)
        site_properties (1,1) struct
    end
    methods
        function obj = AddSitePropertyTransformation(siteProperties)
            obj.site_properties = siteProperties;
        end
        function result = apply_transformation(obj, structure, varargin)
            result = ...
                kssolv.analysis.matgenlab.transformations.internal.Utils. ...
                addSiteProperties(structure, obj.site_properties);
        end
    end
    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.transformations. ...
                AddSitePropertyTransformation(value.site_properties);
        end
        function obj = fromDict(value), obj = ...
                kssolv.analysis.matgenlab.transformations. ...
                AddSitePropertyTransformation.from_dict(value); end
    end
end
