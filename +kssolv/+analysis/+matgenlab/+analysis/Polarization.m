classdef Polarization
    %POLARIZATION Recover a continuous ferroelectric polarization branch.
    properties
        p_elecs
        p_ions
        structures
    end
    methods
        function obj=Polarization(pElecs,pIons,structures, ...
                pElecsInCartesian,pIonsInCartesian)
            if nargin<4,pElecsInCartesian=true;end
            if nargin<5,pIonsInCartesian=false;end
            if size(pElecs,1)~=size(pIons,1)|| ...
                    size(pElecs,1)~=numel(structures)
                error("KSSOLV:Matgenlab:Polarization:Length", ...
                    "Electronic, ionic, and structure counts must match.");
            end
            pElecs=double(pElecs);pIons=double(pIons);
            if pElecsInCartesian
                for index=1:numel(structures)
                    pElecs(index,:)=structures{index}.lattice. ...
                        get_vector_along_lattice_directions(pElecs(index,:));
                end
            end
            if pIonsInCartesian
                for index=1:numel(structures)
                    pIons(index,:)=structures{index}.lattice. ...
                        get_vector_along_lattice_directions(pIons(index,:));
                end
            end
            obj.p_elecs=pElecs;obj.p_ions=pIons;
            obj.structures=reshape(structures,1,[]);
        end
        function [electronic,ionic]=get_pelecs_and_pions(obj,convert)
            if nargin<2,convert=false;end
            electronic=obj.p_elecs;ionic=obj.p_ions;
            if ~convert,return,end
            units=obj.conversionUnits();
            electronic=electronic.*units;
            ionic=ionic.*units;
        end
        function adjusted=get_same_branch_polarization_data( ...
                obj,convertToMuC,allInPolar)
            if nargin<2,convertToMuC=true;end
            if nargin<3,allInPolar=true;end
            total=obj.p_elecs+obj.p_ions;
            count=size(total,1);quanta=zeros(count,3);metrics=cell(1,count);
            volumes=zeros(count,1);lengths=zeros(count,3);
            angles=zeros(count,3);
            for index=1:count
                volumes(index)=obj.structures{index}.volume;
                lengths(index,:)=obj.structures{index}.lattice.lengths;
                angles(index,:)=obj.structures{index}.lattice.angles;
            end
            units=-1.6021766e3./volumes;
            if convertToMuC&&~allInPolar
                total=total.*units;quanta=abs(lengths.*units);
                for index=1:count
                    baseMetric=kssolv.analysis.matgenlab.core.Lattice. ...
                        from_parameters(quanta(index,1),quanta(index,2), ...
                        quanta(index,3),angles(index,1),angles(index,2), ...
                        angles(index,3));
                    metrics{index}=kssolv.analysis.matgenlab.core. ...
                        Lattice(sign(units(index))*baseMetric.matrix);
                end
            elseif convertToMuC&&allInPolar
                total=total./lengths;
                total=total.*(lengths(end,:)/volumes(end)*-1.6021766e3);
                quanta(:,:)=repmat(abs(lengths(end,:)*units(end)),count,1);
                angles(:,:)=repmat(angles(end,:),count,1);
                baseMetric=kssolv.analysis.matgenlab.core.Lattice. ...
                    from_parameters(quanta(1,1),quanta(1,2),quanta(1,3), ...
                    angles(1,1),angles(1,2),angles(1,3));
                for index=1:count
                    metrics{index}=kssolv.analysis.matgenlab.core. ...
                        Lattice(sign(units(end))*baseMetric.matrix);
                end
            else
                quanta=lengths;
                for index=1:count
                    metrics{index}=obj.structures{index}.lattice;
                end
            end
            adjusted=zeros(count,3);previousCartesian=[0,0,0];
            for index=1:count
                metric=metrics{index};
                baseFractional=total(index,:)./quanta(index,:);
                [chosen,previousCartesian]=nearestImage( ...
                    baseFractional,metric,previousCartesian);
                adjusted(index,:)=chosen.*quanta(index,:);
            end
        end
        function quanta=get_lattice_quanta(obj,convertToMuC,allInPolar)
            if nargin<2,convertToMuC=true;end
            if nargin<3,allInPolar=true;end
            count=numel(obj.structures);quanta=zeros(count,3);
            volumes=zeros(count,1);
            for index=1:count
                quanta(index,:)=obj.structures{index}.lattice.lengths;
                volumes(index)=obj.structures{index}.volume;
            end
            if convertToMuC&&allInPolar
                quanta(:,:)=repmat( ...
                    abs(quanta(end,:)*(-1.6021766e3/volumes(end))), ...
                    count,1);
            elseif convertToMuC
                quanta=abs(quanta.*(-1.6021766e3./volumes));
            end
        end
        function change=get_polarization_change(obj,varargin)
            options=parseOptions(varargin{:});
            values=obj.get_same_branch_polarization_data( ...
                options.convert_to_muC_per_cm2,options.all_in_polar);
            change=reshape(values(end,:)-values(1,:),1,3);
        end
        function value=get_polarization_change_norm(obj,varargin)
            options=parseOptions(varargin{:});
            change=obj.get_polarization_change( ...
                convert_to_muC_per_cm2= ...
                options.convert_to_muC_per_cm2, ...
                all_in_polar=options.all_in_polar);
            matrix=obj.structures{end}.lattice.matrix;
            matrix=matrix./vecnorm(matrix,2,2);
            value=norm(change*matrix);
        end
        function splines=same_branch_splines(obj,varargin)
            options=parseOptions(varargin{:});
            values=obj.get_same_branch_polarization_data( ...
                options.convert_to_muC_per_cm2,options.all_in_polar);
            x=(0:size(values,1)-1).';
            splines=cell(1,3);
            for index=1:3
                splines{index}=polyfit(x,values(:,index), ...
                    min(3,numel(x)-1));
            end
        end
        function jumps=max_spline_jumps(obj,varargin)
            options=parseOptions(varargin{:});
            values=obj.get_same_branch_polarization_data( ...
                options.convert_to_muC_per_cm2,options.all_in_polar);
            coefficients=obj.same_branch_splines( ...
                convert_to_muC_per_cm2= ...
                options.convert_to_muC_per_cm2, ...
                all_in_polar=options.all_in_polar);
            x=(0:size(values,1)-1).';jumps=zeros(1,3);
            for index=1:3
                jumps(index)=max(values(:,index)- ...
                    polyval(coefficients{index},x));
            end
        end
        function values=smoothness(obj,varargin)
            options=parseOptions(varargin{:});
            branch=obj.get_same_branch_polarization_data( ...
                options.convert_to_muC_per_cm2,options.all_in_polar);
            coefficients=obj.same_branch_splines( ...
                convert_to_muC_per_cm2= ...
                options.convert_to_muC_per_cm2, ...
                all_in_polar=options.all_in_polar);
            x=(0:size(branch,1)-1).';values=zeros(1,3);
            for index=1:3
                difference=polyval(coefficients{index},x)-branch(:,index);
                values(index)=sqrt(mean(difference.^2));
            end
        end
    end
    methods (Static)
        function obj=from_outcars_and_structures(outcars,structures, ...
                calcIonicFromZval)
            if nargin<3,calcIonicFromZval=false;end
            count=numel(outcars);electronic=zeros(count,3);
            ionic=zeros(count,3);
            for index=1:count
                electronic(index,:)=outcars{index}.p_elec;
                if calcIonicFromZval
                    ionic(index,:)=kssolv.analysis.matgenlab.analysis. ...
                        get_total_ionic_dipole( ...
                        structures{index},outcars{index}.zval_dict);
                else
                    ionic(index,:)=outcars{index}.p_ion;
                end
            end
            obj=kssolv.analysis.matgenlab.analysis.Polarization( ...
                electronic,ionic,structures);
        end
    end
    methods (Access=private)
        function units=conversionUnits(obj)
            units=zeros(numel(obj.structures),1);
            for index=1:numel(obj.structures)
                units(index)=-1.6021766e3/obj.structures{index}.volume;
            end
        end
    end
end
function [fractional,cartesian]=nearestImage(base,lattice,previous)
best=Inf;fractional=base;cartesian=lattice.get_cartesian_coords(base);
target=lattice.get_fractional_coords(previous);
center=round(target-base);
for a=-3:3
    for b=-3:3
        for c=-3:3
            candidate=base+center+[a,b,c];
            point=lattice.get_cartesian_coords(candidate);
            distance=norm(point-previous);
            if distance<best
                best=distance;fractional=candidate;cartesian=point;
            end
        end
    end
end
end
function options=parseOptions(varargin)
options=struct("convert_to_muC_per_cm2",true,"all_in_polar",true);
for index=1:2:numel(varargin)
    name=char(string(varargin{index}));
    if isfield(options,name),options.(name)=varargin{index+1};end
end
end
