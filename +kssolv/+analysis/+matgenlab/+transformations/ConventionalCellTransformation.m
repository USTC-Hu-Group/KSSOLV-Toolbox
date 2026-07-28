classdef ConventionalCellTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess=private)
        symprec (1,1) double
        angle_tolerance (1,1) double
        international_monoclinic (1,1) logical
    end
    methods
        function obj=ConventionalCellTransformation( ...
                symprec,angleTolerance,internationalMonoclinic)
            if nargin<1,symprec=.01;end
            if nargin<2,angleTolerance=5;end
            if nargin<3,internationalMonoclinic=true;end
            obj.symprec=symprec;obj.angle_tolerance=angleTolerance;
            obj.international_monoclinic=internationalMonoclinic;
        end
        function result=apply_transformation(obj,structure,varargin)
            analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(structure,obj.symprec,obj.angle_tolerance);
            result=analyzer.get_conventional_standard_structure( ...
                obj.international_monoclinic);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                ConventionalCellTransformation(value.symprec, ...
                value.angle_tolerance,value.international_monoclinic);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                ConventionalCellTransformation.from_dict(value);end
    end
end
