classdef DopingTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess=private)
        dopant
        ionic_radius_tol (1,1) double
        min_length (1,1) double
        alio_tol (1,1) double
        codopant (1,1) logical
        max_structures_per_enum (1,1) double
        allowed_doping_species
        kwargs (1,1) struct
    end
    methods
        function obj=DopingTransformation(dopant,ionicRadiusTol, ...
                minLength,alioTol,codopant,maxStructures,allowed,varargin)
            if nargin<2,ionicRadiusTol=Inf;end
            if isempty(ionicRadiusTol),ionicRadiusTol=Inf;end
            if nargin<3,minLength=10;end
            if nargin<4,alioTol=0;end
            if nargin<5,codopant=false;end
            if nargin<6,maxStructures=100;end
            if nargin<7,allowed=[];end
            obj.dopant=kssolv.analysis.matgenlab.core.getElSp(dopant);
            if ~isa(obj.dopant,"kssolv.analysis.matgenlab.core.Species")
                error("KSSOLV:Matgenlab:Doping:DopantCharge", ...
                    "Dopant must have an oxidation state.");
            end
            obj.ionic_radius_tol=ionicRadiusTol;obj.min_length=minLength;
            obj.alio_tol=alioTol;obj.codopant=codopant;
            obj.max_structures_per_enum=maxStructures;
            obj.allowed_doping_species=allowed;
            options=struct();
            for index=1:2:numel(varargin)
                options.(char(string(varargin{index})))=varargin{index+1};
            end
            obj.kwargs=options;
        end
        function result=apply_transformation(obj,structure,returnRankedList)
            if nargin<3,returnRankedList=false;end
            [species,~]=structure.composition.items();
            if any(cellfun(@(item) ...
                    ~isa(item,"kssolv.analysis.matgenlab.core.Species"),species))
                structure=kssolv.analysis.matgenlab.core.BVAnalyzer(). ...
                    get_oxi_state_decorated_structure(structure);
                [species,~]=structure.composition.items();
            end
            ox=obj.dopant.oxi_state;radius=obj.dopant.ionic_radius;
            compatible={};
            for index=1:numel(species)
                current=species{index};
                radiusOk=~isnan(radius)&&~isnan(current.ionic_radius)&& ...
                    abs(current.ionic_radius/radius-1)< ...
                    obj.ionic_radius_tol;
                if current.oxi_state==ox&&radiusOk
                    compatible{end+1}=current; %#ok<AGROW>
                end
            end
            if isempty(compatible)&&obj.alio_tol>0
                for index=1:numel(species)
                    current=species{index};
                    radiusOk=~isnan(radius)&& ...
                        ~isnan(current.ionic_radius)&& ...
                        abs(current.ionic_radius/radius-1)< ...
                        obj.ionic_radius_tol;
                    chargeOk=abs(current.oxi_state-ox)<=obj.alio_tol&& ...
                        current.oxi_state*ox>=0;
                    if chargeOk&&radiusOk
                        compatible{end+1}=current; %#ok<AGROW>
                    end
                end
            end
            if ~isempty(obj.allowed_doping_species)
                allowed=cellfun(@(item) ...
                    kssolv.analysis.matgenlab.core.getElSp(item), ...
                    cellstr(string(obj.allowed_doping_species)), ...
                    "UniformOutput",false);
                compatible=compatible(cellfun(@(item) ...
                    any(cellfun(@(candidate)item==candidate,allowed)), ...
                    compatible));
            end
            scaling=max(1,ceil(obj.min_length./structure.lattice.lengths));
            allStructures=cell(1,0);
            for targetIndex=1:numel(compatible)
                target=compatible{targetIndex};
                supercell=structure*scaling;
                number=supercell.composition.amountOf(target);
                if target.oxi_state==ox
                    mappings={target,{target,(number-1)/number; ...
                        obj.dopant,1/number}};
                elseif obj.codopant
                    co=kssolv.analysis.matgenlab.transformations. ...
                        find_codopant(target,2*target.oxi_state-ox);
                    mappings={target,{target,(number-2)/number; ...
                        obj.dopant,1/number;co,1/number}};
                elseif abs(target.oxi_state)<abs(ox)
                    same=species(cellfun(@(item) ...
                        item.oxi_state*ox>0,species));
                    [~,which]=min(cellfun(@(item) ...
                        abs(item.oxi_state),same));
                    vacancy=same{which};
                    if vacancy==target
                        common=lcm(round(abs(target.oxi_state)), ...
                            round(abs(ox)));
                        dopants=common/abs(ox);
                        removed=common/abs(target.oxi_state);
                        mappings={target,{target,(number-removed)/number; ...
                            obj.dopant,dopants/number}};
                    else
                        difference=round(abs(target.oxi_state-ox));
                        common=lcm(round(abs(vacancy.oxi_state))*difference, ...
                            difference);
                        dopants=common/difference;
                        vacancyCount=common/(abs(vacancy.oxi_state)*difference);
                        available=supercell.composition.amountOf(vacancy);
                        mappings={target,{target,(number-dopants)/number; ...
                            obj.dopant,dopants/number}; ...
                            vacancy,{vacancy, ...
                            (available-vacancyCount)/available}};
                    end
                else
                    opposite=species(cellfun(@(item) ...
                        item.oxi_state*target.oxi_state<0,species));
                    if isempty(opposite),continue,end
                    electroneg=cellfun(@(item)item.X,opposite);
                    if ox>0,[~,which]=max(electroneg);
                    else,[~,which]=min(electroneg);end
                    vacancy=opposite{which};
                    difference=round(abs(target.oxi_state-ox));
                    common=lcm(round(abs(vacancy.oxi_state)),difference);
                    dopants=common/difference;
                    removed=common/abs(vacancy.oxi_state);
                    available=supercell.composition.amountOf(vacancy);
                    mappings={target,{target,(number-dopants)/number; ...
                        obj.dopant,dopants/number}; ...
                        vacancy,{vacancy,(available-removed)/available}};
                end
                disordered=kssolv.analysis.matgenlab.transformations. ...
                    SubstitutionTransformation(mappings). ...
                    apply_transformation(supercell);
                enumOptions=struct( ...
                    "min_cell_size",1,"max_cell_size",1, ...
                    "symm_prec",.1,"refine_structure",false, ...
                    "enum_precision_parameter",.001, ...
                    "check_ordered_symmetry",true, ...
                    "max_disordered_sites",[], ...
                    "sort_criteria","ewald","timeout",[],"n_jobs",-1);
                names=fieldnames(obj.kwargs);
                for optionIndex=1:numel(names)
                    if isfield(enumOptions,names{optionIndex})
                        enumOptions.(names{optionIndex})= ...
                            obj.kwargs.(names{optionIndex});
                    end
                end
                enumerator=kssolv.analysis.matgenlab.transformations. ...
                    EnumerateStructureTransformation( ...
                    enumOptions.min_cell_size,enumOptions.max_cell_size, ...
                    enumOptions.symm_prec,enumOptions.refine_structure, ...
                    enumOptions.enum_precision_parameter, ...
                    enumOptions.check_ordered_symmetry, ...
                    enumOptions.max_disordered_sites, ...
                    enumOptions.sort_criteria,enumOptions.timeout, ...
                    enumOptions.n_jobs);
                values=enumerator.apply_transformation(disordered, ...
                    obj.max_structures_per_enum);
                allStructures=[allStructures,values]; %#ok<AGROW>
            end
            count=kssolv.analysis.matgenlab.transformations.internal.Utils. ...
                rankedCount(returnRankedList);
            if count==0
                if isempty(allStructures)
                    error("KSSOLV:Matgenlab:Doping:NoStructures", ...
                        "No compatible doping sites were found.");
                end
                result=allStructures{1}.structure;
            else
                result=allStructures(1:min(count,numel(allStructures)));
            end
        end
    end
    methods (Access=protected)
        function value=oneToMany(~),value=true;end
    end
    methods (Static)
        function obj=from_dict(value)
            args={};names=fieldnames(value.kwargs);
            for index=1:numel(names)
                args(end+(1:2))={names{index},value.kwargs.(names{index})}; %#ok<AGROW>
            end
            obj=kssolv.analysis.matgenlab.transformations. ...
                DopingTransformation(value.dopant,value.ionic_radius_tol, ...
                value.min_length,value.alio_tol,value.codopant, ...
                value.max_structures_per_enum, ...
                value.allowed_doping_species,args{:});
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                DopingTransformation.from_dict(value);end
    end
end
