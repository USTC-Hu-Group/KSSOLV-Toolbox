classdef MagOrderParameterConstraint < ...
        kssolv.analysis.matgenlab.util.MSONable
    properties (SetAccess=private)
        order_parameter (1,1) double
        species_constraints
        site_constraint_name
        site_constraints
    end
    methods
        function obj=MagOrderParameterConstraint( ...
                orderParameter,speciesConstraints,siteConstraintName, ...
                siteConstraints)
            if nargin<2||isempty(speciesConstraints),speciesConstraints={};end
            if nargin<3,siteConstraintName=[];end
            if nargin<4||isempty(siteConstraints),siteConstraints={};end
            if orderParameter<0||orderParameter>1
                error("KSSOLV:Matgenlab:MagOrderConstraint:Parameter", ...
                    "Order parameter must lie between zero and one.");
            end
            if ~isempty(siteConstraints)&&isempty(siteConstraintName)
                error("KSSOLV:Matgenlab:MagOrderConstraint:PropertyName", ...
                    "Specify the name of the site constraint.");
            elseif isempty(siteConstraints)&&~isempty(siteConstraintName)
                error("KSSOLV:Matgenlab:MagOrderConstraint:Values", ...
                    "Specify site constraint values.");
            end
            if ~iscell(speciesConstraints)
                speciesConstraints=cellstr(string(speciesConstraints));
            end
            if ~iscell(siteConstraints),siteConstraints=num2cell(siteConstraints);end
            obj.order_parameter=orderParameter;
            obj.species_constraints=speciesConstraints;
            obj.site_constraint_name=siteConstraintName;
            obj.site_constraints=siteConstraints;
        end
        function value=satisfies_constraint(obj,site)
            if ~site.is_ordered,value=false;return,end
            value=~isempty(obj.species_constraints)&&any( ...
                string(obj.species_constraints)==string(site.specie));
            if ~isempty(obj.site_constraint_name)
                name=char(string(obj.site_constraint_name));
                if ~isfield(site.site_properties,name),value=false;return,end
                property=site.site_properties.(name);
                value=any(cellfun(@(candidate)isequal(candidate,property), ...
                    obj.site_constraints));
            end
        end
        function value=asDict(obj)
            value=struct( ...
                "x_module","pymatgen.transformations.advanced_transformations", ...
                "x_class","MagOrderParameterConstraint", ...
                "x_version",[], ...
                "order_parameter",obj.order_parameter, ...
                "species_constraints",{obj.species_constraints}, ...
                "site_constraint_name",obj.site_constraint_name, ...
                "site_constraints",{obj.site_constraints});
        end
        function value=as_dict(obj),value=obj.asDict();end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                MagOrderParameterConstraint(value.order_parameter, ...
                value.species_constraints,value.site_constraint_name, ...
                value.site_constraints);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                MagOrderParameterConstraint.from_dict(value);end
    end
end
