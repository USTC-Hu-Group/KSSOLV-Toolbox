classdef TotalDos
    %TOTALDOS Native MATLAB equivalent of phonopy.phonon.dos.TotalDos.
    %
    % This small value object implements the smearing and Debye-fit behavior
    % used by pymatgen's GruneisenParameter without requiring phonopy at
    % production runtime.

    properties (SetAccess=private)
        frequency_points (1,:) double
        dos (1,:) double
        sigma (1,1) double
        frequencies double
        weights (1,:) double
        num_atoms (1,1) double
        debye_frequency = []
        Debye_fit_coef = []
    end

    methods
        function obj=TotalDos(frequencies,weights,numAtoms,sigma)
            if nargin<2 || isempty(weights)
                weights=ones(1,size(frequencies,1));
            end
            if nargin<3 || isempty(numAtoms),numAtoms=1;end
            values=double(frequencies);
            weights=reshape(double(weights),1,[]);
            if size(values,1)~=numel(weights)
                error("KSSOLV:Matgenlab:TotalDos:Shape", ...
                    "frequencies must have one row per mesh weight.");
            end
            minimum=min(values,[],"all");
            maximum=max(values,[],"all");
            if nargin<4 || isempty(sigma)
                sigma=(maximum-minimum)/100;
            end
            if sigma<=0
                sigma=max(eps(max(abs([minimum,maximum]))),eps);
            end
            lower=minimum-10*sigma;
            upper=maximum+10*sigma;
            pitch=(upper-lower)/200;
            points=lower:pitch:(upper+pitch*0.1);
            delta=values-permute(points,[1,3,2]);
            gaussian=exp(-0.5*(delta/sigma).^2)/(sqrt(2*pi)*sigma);
            weighted=sum(gaussian.*reshape(weights,[],1,1),1);
            density=squeeze(sum(weighted,2))/sum(weights);
            obj.frequency_points=reshape(points,1,[]);
            obj.dos=reshape(density,1,[]);
            obj.sigma=sigma;
            obj.frequencies=values;
            obj.weights=weights;
            obj.num_atoms=numAtoms;
        end

        function obj=run(obj)
            %RUN Compatibility no-op: construction already computes the DOS.
        end

        function obj=run_debye_frequency(obj,freqMaxFit)
            if nargin<2,freqMaxFit=[];end
            count=numel(obj.frequency_points);
            if isempty(freqMaxFit)
                fitCount=floor(count/4);
            else
                span=max(obj.frequency_points)-min(obj.frequency_points);
                fitCount=floor(freqMaxFit/span*count);
            end
            fitCount=max(1,min(count,fitCount));
            x=obj.frequency_points(1:fitCount).^2;
            y=obj.dos(1:fitCount);
            coefficient=sum(x.*y)/sum(x.^2);
            obj.Debye_fit_coef=coefficient;
            obj.debye_frequency=(9*obj.num_atoms/coefficient)^(1/3);
        end

        function value=get_Debye_frequency(obj)
            value=obj.debye_frequency;
        end

        function obj=set_Debye_frequency(obj,numAtoms,freqMaxFit)
            if nargin>=2 && ~isempty(numAtoms),obj.num_atoms=numAtoms;end
            if nargin<3,freqMaxFit=[];end
            obj=obj.run_debye_frequency(freqMaxFit);
        end
    end
end
