classdef DiscretizeOccupanciesTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess=private)
        max_denominator (1,1) double
        tol (1,1) double
        fix_denominator (1,1) logical
    end
    methods
        function obj=DiscretizeOccupanciesTransformation( ...
                maxDenominator,tolerance,fixDenominator)
            if nargin<1,maxDenominator=5;end
            if nargin<2||isempty(tolerance)
                tolerance=1/(4*maxDenominator);
            end
            if nargin<3,fixDenominator=false;end
            obj.max_denominator=maxDenominator;obj.tol=tolerance;
            obj.fix_denominator=fixDenominator;
        end
        function result=apply_transformation(obj,structure,varargin)
            if structure.is_ordered,result=structure;return,end
            result=structure.copy();
            for siteIndex=1:result.num_sites
                site=result(siteIndex);
                [species,amounts]=site.species.items();
                pairs=cell(numel(species),2);
                for index=1:numel(species)
                    original=amounts(index);
                    if obj.fix_denominator
                        replacement=round(original*obj.max_denominator)/ ...
                            obj.max_denominator;
                    else
                        denominators=1:obj.max_denominator;
                        candidates=round(original*denominators)./denominators;
                        errors=abs(candidates-original);
                        minimum=min(errors);
                        possible=find(abs(errors-minimum)<1e-15);
                        [~,which]=min(denominators(possible));
                        replacement=candidates(possible(which));
                    end
                    if round(abs(original-replacement),6)>obj.tol
                        error("KSSOLV:Matgenlab:DiscretizeOccupancies:Tolerance", ...
                            "Cannot discretize structure within tolerance.");
                    end
                    pairs(index,:)={species{index},replacement};
                end
                result=result.replace(siteIndex, ...
                    kssolv.analysis.matgenlab.core.Composition(pairs));
            end
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                DiscretizeOccupanciesTransformation( ...
                value.max_denominator,value.tol,value.fix_denominator);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                DiscretizeOccupanciesTransformation.from_dict(value);end
    end
end
