classdef GruneisenParameter
    %GRUNEISENPARAMETER Gruneisen parameters on a regular reciprocal mesh.

    properties (SetAccess=private)
        qpoints double
        gruneisen double
        frequencies double
        multiplicities
        structure
        lattice
    end

    properties (Dependent,SetAccess=private)
        tdos
        phdos
        debye_temp_limit
        acoustic_debye_temp
    end

    methods
        function obj=GruneisenParameter(qpoints,gruneisen,frequencies, ...
                multiplicities,structure,lattice)
            if nargin<4,multiplicities=[];end
            if nargin<5,structure=[];end
            if nargin<6,lattice=[];end
            obj.qpoints=double(qpoints);
            obj.gruneisen=double(gruneisen);
            obj.frequencies=double(frequencies);
            obj.multiplicities=multiplicities;
            obj.structure=structure;
            obj.lattice=lattice;
            if ~isequal(size(obj.gruneisen),size(obj.frequencies))
                error("KSSOLV:Matgenlab:GruneisenParameter:Shape", ...
                    "gruneisen and frequencies must have identical shapes.");
            end
        end

        function value=average_gruneisen(obj,temp,squared,limitFrequencies)
            if nargin<2 || isempty(temp),temp=obj.acoustic_debye_temp;end
            if nargin<3 || isempty(squared),squared=true;end
            if nargin<4,limitFrequencies=[];end
            if isempty(obj.multiplicities)
                error("KSSOLV:Matgenlab:GruneisenParameter:Multiplicities", ...
                    "Multiplicities are not defined.");
            end
            constants=kssolv.analysis.matgenlab.core.Constants;
            w=obj.frequencies;
            wdkt=w*constants.tera/( ...
                constants.value("Boltzmann constant in Hz/K")*temp);
            exponent=exp(wdkt);
            cv=zeros(size(w));
            positive=w>0;
            cv(positive)=constants.value( ...
                "Boltzmann constant in eV/K").* ...
                wdkt(positive).^2.*exponent(positive)./ ...
                (exponent(positive)-1).^2;
            gamma=obj.gruneisen;
            if squared,gamma=gamma.^2;end
            limit=lower(string(limitFrequencies));
            if isempty(limitFrequencies)
                selected=w>=0;
                selectedShape=size(w);
            elseif limit=="debye"
                acousticFrequency=obj.acoustic_debye_temp* ...
                    constants.value("Boltzmann constant in Hz/K")/ ...
                    constants.tera;
                selected=w>=0 & w<=acousticFrequency;
                selectedShape=size(w);
            elseif limit=="acoustic"
                acoustic=w(:,1:min(3,size(w,2)));
                selected=acoustic>=0;
                selectedShape=size(acoustic);
            else
                error("KSSOLV:Matgenlab:GruneisenParameter:Limit", ...
                    "%s is not an accepted value for limit_frequencies.", ...
                    limitFrequencies);
            end
            [bandIndices,qpointIndices]=find(selected);
            linear=sub2ind(size(w),bandIndices,qpointIndices);
            if ~isequal(selectedShape,size(w))
                linear=sub2ind(size(w),bandIndices,qpointIndices);
            end
            weights=reshape(double(obj.multiplicities),[],1);
            if any(bandIndices>numel(weights))
                error("KSSOLV:Matgenlab:GruneisenParameter:Weights", ...
                    "Multiplicities do not cover selected band indices.");
            end
            weighted=weights(bandIndices);
            numerator=sum(weighted.*cv(linear).*gamma(linear));
            denominator=sum(weighted.*cv(linear));
            value=numerator/denominator;
            if squared,value=sqrt(value);end
        end

        function value=thermal_conductivity_slack( ...
                obj,squared,limitFrequencies,thetaD,temp)
            if nargin<2 || isempty(squared),squared=true;end
            if nargin<3,limitFrequencies=[];end
            if nargin<4 || isempty(thetaD),thetaD=obj.acoustic_debye_temp;end
            if nargin<5,temp=[];end
            if isempty(obj.structure)
                error("KSSOLV:Matgenlab:GruneisenParameter:Structure", ...
                    "Structure is not defined.");
            end
            masses=zeros(1,obj.structure.num_sites);
            for index=1:numel(masses)
                masses(index)=obj.structure(index).specie.atomic_mass;
            end
            averageMass=mean(masses)* ...
                kssolv.analysis.matgenlab.core.UnitConstants.amu_to_kg;
            meanG=obj.average_gruneisen( ...
                thetaD,squared,limitFrequencies);
            constants=kssolv.analysis.matgenlab.core.Constants;
            f1=0.849*3*4^(1/3)/(20*pi^3* ...
                (1-0.514/meanG+0.228/meanG^2));
            f2=(constants.k*thetaD/constants.hbar)^2;
            f3=constants.k*averageMass*obj.structure.volume^(1/3)* ...
                1e-10/(constants.hbar*meanG^2);
            value=f1*f2*f3;
            if ~isempty(temp),value=value*thetaD/temp;end
        end

        function value=get.tdos(obj)
            count=1;
            if ~isempty(obj.structure),count=obj.structure.num_sites;end
            value=kssolv.analysis.matgenlab.phonon.TotalDos( ...
                obj.frequencies.',obj.multiplicities,count);
        end

        function value=get.phdos(obj)
            total=obj.tdos;
            value=kssolv.analysis.matgenlab.phonon.PhononDos( ...
                total.frequency_points,total.dos);
        end

        function value=get.debye_temp_limit(obj)
            total=obj.tdos;
            meshFrequencies=total.frequency_points* ...
                kssolv.analysis.matgenlab.core.Constants.tera;
            numerator=integrateSpline( ...
                meshFrequencies,total.dos.*meshFrequencies.^2);
            denominator=integrateSpline(meshFrequencies,total.dos);
            value=sqrt(5/3*numerator/denominator)/ ...
                kssolv.analysis.matgenlab.core.Constants.value( ...
                "Boltzmann constant in Hz/K");
        end

        function value=debye_temp_phonopy(obj,freqMaxFit)
            if nargin<2,freqMaxFit=[];end
            if isempty(obj.structure)
                error("KSSOLV:Matgenlab:GruneisenParameter:Structure", ...
                    "Structure not defined.");
            end
            total=obj.tdos;
            total=total.run_debye_frequency(freqMaxFit);
            value=kssolv.analysis.matgenlab.core.Constants.value( ...
                "Planck constant")*total.debye_frequency* ...
                kssolv.analysis.matgenlab.core.Constants.tera/ ...
                kssolv.analysis.matgenlab.core.Constants.value( ...
                "Boltzmann constant");
        end

        function value=get.acoustic_debye_temp(obj)
            if isempty(obj.structure)
                error("KSSOLV:Matgenlab:GruneisenParameter:Structure", ...
                    "Structure is not defined.");
            end
            value=obj.debye_temp_limit/obj.structure.num_sites^(1/3);
        end

        function value=as_dict(obj)
            value=struct( ...
                "x_module","pymatgen.phonon.gruneisen", ...
                "x_class","GruneisenParameter", ...
                "qpoints",obj.qpoints, ...
                "gruneisen",obj.gruneisen, ...
                "frequencies",obj.frequencies, ...
                "multiplicities",obj.multiplicities, ...
                "structure",[], ...
                "lattice",[]);
            if ~isempty(obj.structure),value.structure=obj.structure.as_dict();end
            if ~isempty(obj.lattice),value.lattice=obj.lattice.as_dict();end
        end
        function value=asDict(obj),value=obj.as_dict();end
    end

    methods (Static)
        function obj=from_dict(value)
            structure=[];lattice=[];
            if isfield(value,"structure") && ~isempty(value.structure)
                structure=kssolv.analysis.matgenlab.core.Structure. ...
                    from_dict(value.structure);
            end
            if isfield(value,"lattice") && ~isempty(value.lattice)
                lattice=kssolv.analysis.matgenlab.core.Lattice. ...
                    from_dict(value.lattice);
            end
            obj=kssolv.analysis.matgenlab.phonon.GruneisenParameter( ...
                value.qpoints,value.gruneisen,value.frequencies, ...
                value.multiplicities,structure,lattice);
        end
    end
end

function value=integrateSpline(x,y)
piece=spline(reshape(x,1,[]),reshape(y,1,[]));
breaks=piece.breaks;
coefs=piece.coefs;
value=0;
for index=1:numel(breaks)-1
    width=breaks(index+1)-breaks(index);
    row=coefs(index,:);
    powers=(numel(row)-1):-1:0;
    value=value+sum(row.*width.^(powers+1)./(powers+1));
end
end
