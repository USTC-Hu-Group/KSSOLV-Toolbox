classdef PhononDos
    %PHONONDOS Phonon density of states in THz.

    properties (SetAccess = protected)
        frequencies (:,1) double
        densities (:,1) double
    end

    properties (Dependent,SetAccess=private)
        ind_zero_freq
    end

    methods
        function obj=PhononDos(frequencies,densities)
            if nargin==0
                frequencies=zeros(0,1);densities=zeros(0,1);
            end
            obj.frequencies=reshape(double(frequencies),[],1);
            obj.densities=reshape(double(densities),[],1);
            if numel(obj.frequencies)~=numel(obj.densities)
                error("KSSOLV:Matgenlab:PhononDos:Length", ...
                    "frequencies and densities must have equal lengths.");
            end
        end

        function value=get.ind_zero_freq(obj)
            value=find(obj.frequencies>=0,1);
            if isempty(value)
                error("KSSOLV:Matgenlab:PhononDos:NoPositiveFrequency", ...
                    "No positive frequencies found.");
            end
        end

        function value=get_smeared_densities(obj,sigma)
            if sigma==0,value=obj.densities;return,end
            spacing=mean(diff(obj.frequencies));
            value=kssolv.analysis.matgenlab.phonon.PhononDos. ...
                gaussianFilter(obj.densities,sigma/spacing);
        end

        function value=get_interpolated_value(obj,frequency)
            value=kssolv.analysis.matgenlab.util. ...
                get_linear_interpolated_value( ...
                obj.frequencies,obj.densities,frequency);
        end

        function result=plus(first,second)
            if isnumeric(first)
                result=kssolv.analysis.matgenlab.phonon. ...
                    PhononDos(second.frequencies,second.densities+first);
            elseif isnumeric(second)
                result=kssolv.analysis.matgenlab.phonon. ...
                    PhononDos(first.frequencies,first.densities+second);
            else
                if ~isequal(first.frequencies,second.frequencies)
                    error("KSSOLV:Matgenlab:PhononDos:Frequencies", ...
                        "Frequencies of both DOS are not compatible!");
                end
                result=kssolv.analysis.matgenlab.phonon. ...
                    PhononDos(first.frequencies, ...
                    first.densities+second.densities);
            end
        end

        function result=minus(first,second),result=first+(-second);end
        function result=uminus(obj)
            result=kssolv.analysis.matgenlab.phonon. ...
                PhononDos(obj.frequencies,-obj.densities);
        end
        function result=times(first,second)
            if isa(first,"kssolv.analysis.matgenlab.phonon.PhononDos")
                result=kssolv.analysis.matgenlab.phonon. ...
                    PhononDos(first.frequencies,first.densities.*second);
            else
                result=second.*first;
            end
        end
        function result=mtimes(first,second),result=times(first,second);end

        function value=eq(first,second)
            value=isa(second, ...
                "kssolv.analysis.matgenlab.phonon.PhononDos") && ...
                isequal(size(first.densities),size(second.densities)) && ...
                all(abs(first.densities-second.densities)<= ...
                1e-8+1e-5*abs(second.densities));
        end
        function value=ne(first,second),value=~eq(first,second);end

        function value=cv(obj,temp,structure,varargin)
            if nargin<2 || isempty(temp)
                temp=deprecatedTemperature(varargin{:});
            end
            if nargin<3,structure=[];end
            if temp==0,value=0;return,end
            [positiveFrequencies,positiveDensities]=obj.positiveData();
            x=positiveFrequencies/(2*obj.boltzThzPerK()*temp);
            integrand=x.^2./sinh(x).^2.*positiveDensities;
            value=trapz(positiveFrequencies,integrand)* ...
                obj.boltzmann()*obj.avogadro();
            value=obj.perFormulaUnit(value,structure);
        end

        function value=entropy(obj,temp,structure,varargin)
            if nargin<2 || isempty(temp)
                temp=deprecatedTemperature(varargin{:});
            end
            if nargin<3,structure=[];end
            if temp==0,value=0;return,end
            [positiveFrequencies,positiveDensities]=obj.positiveData();
            x=positiveFrequencies/(2*obj.boltzThzPerK()*temp);
            value=trapz(positiveFrequencies, ...
                (x./tanh(x)-log(2*sinh(x))).*positiveDensities);
            value=value*obj.boltzmann()*obj.avogadro();
            value=obj.perFormulaUnit(value,structure);
        end

        function value=internal_energy(obj,temp,structure,varargin)
            if nargin<2 || isempty(temp)
                temp=deprecatedTemperature(varargin{:});
            end
            if nargin<3,structure=[];end
            if temp==0,value=obj.zero_point_energy(structure);return,end
            [positiveFrequencies,positiveDensities]=obj.positiveData();
            x=positiveFrequencies/(2*obj.boltzThzPerK()*temp);
            value=trapz(positiveFrequencies, ...
                positiveFrequencies./tanh(x).*positiveDensities)/2;
            value=value*obj.thzToJ()*obj.avogadro();
            value=obj.perFormulaUnit(value,structure);
        end

        function value=helmholtz_free_energy( ...
                obj,temp,structure,varargin)
            if nargin<2 || isempty(temp)
                temp=deprecatedTemperature(varargin{:});
            end
            if nargin<3,structure=[];end
            if temp==0,value=obj.zero_point_energy(structure);return,end
            [positiveFrequencies,positiveDensities]=obj.positiveData();
            x=positiveFrequencies/(2*obj.boltzThzPerK()*temp);
            value=trapz(positiveFrequencies, ...
                log(2*sinh(x)).*positiveDensities);
            value=value*obj.boltzmann()*obj.avogadro()*temp;
            value=obj.perFormulaUnit(value,structure);
        end

        function value=zero_point_energy(obj,structure)
            if nargin<2,structure=[];end
            [positiveFrequencies,positiveDensities]=obj.positiveData();
            value=0.5*trapz(positiveFrequencies, ...
                positiveFrequencies.*positiveDensities)* ...
                obj.thzToJ()*obj.avogadro();
            value=obj.perFormulaUnit(value,structure);
        end

        function value=mae(obj,other,twoSided)
            if nargin<3,twoSided=true;end
            interpolated=numpyInterp(other.frequencies, ...
                other.densities,obj.frequencies);
            first=mean(abs(obj.densities-interpolated));
            if twoSided
                interpolated=numpyInterp(obj.frequencies, ...
                    obj.densities,other.frequencies);
                value=(first+mean(abs(other.densities-interpolated)))/2;
            else
                value=first;
            end
        end

        function value=r2_score(obj,other)
            variance=var(obj.densities,1);
            if variance==0,value=0;return,end
            value=1-mean((obj.densities-other.densities).^2)/variance;
        end

        function value=get_last_peak(obj,threshold)
            if nargin<2,threshold=0.05;end
            first=gradient(obj.densities,obj.frequencies);
            second=gradient(first,obj.frequencies);
            maxima=first(1:end-1)>0 & first(2:end)<0 & ...
                second(1:end-1)<0;
            peakGrid=(obj.frequencies(1:end-1)+ ...
                obj.frequencies(2:end))/2;
            peakFrequencies=peakGrid(maxima);
            peakDensities=obj.densities(1:end-1);
            selected=peakFrequencies( ...
                peakDensities(maxima)>=threshold*max(obj.densities));
            if isempty(selected)
                sorted=sort(obj.densities);
                selected=peakFrequencies( ...
                    peakDensities(maxima)>=sorted(end-1)/2);
            end
            value=max(selected);
        end

        function fingerprint=get_dos_fp( ...
                obj,binning,minFrequency,maxFrequency,nBins,normalize)
            if nargin<2 || isempty(binning),binning=true;end
            if nargin<3 || isempty(minFrequency)
                minFrequency=min(obj.frequencies);
            end
            if nargin<4 || isempty(maxFrequency)
                maxFrequency=max(obj.frequencies);
            end
            if nargin<5 || isempty(nBins),nBins=256;end
            if nargin<6 || isempty(normalize),normalize=true;end
            if numel(obj.frequencies)<nBins
                keep=obj.frequencies>=minFrequency & ...
                    obj.frequencies<=maxFrequency;
                fingerprint=kssolv.analysis.matgenlab.phonon. ...
                    PhononDosFingerprint( ...
                    obj.frequencies(keep),obj.densities(keep), ...
                    numel(obj.frequencies),diff(obj.frequencies(1:2)));
                return
            end
            if binning
                bounds=linspace(minFrequency,maxFrequency,nBins+1);
                fingerprintFrequencies= ...
                    bounds(1:end-1)+diff(bounds(1:2))/2;
                binWidth=diff(fingerprintFrequencies(1:2));
            else
                bounds=obj.frequencies.';
                fingerprintFrequencies=[obj.frequencies.', ...
                    obj.frequencies(end)+abs(obj.frequencies(end))/10];
                nBins=numel(obj.frequencies);
                binWidth=diff(obj.frequencies(1:2));
            end
            fingerprintDensities=zeros(size(fingerprintFrequencies));
            count=min(numel(fingerprintFrequencies),numel(bounds)-1);
            for index=1:count
                keep=obj.frequencies>=bounds(index) & ...
                    obj.frequencies<bounds(index+1);
                fingerprintDensities(index)=sum(obj.densities(keep));
            end
            if normalize
                fingerprintDensities=fingerprintDensities/ ...
                    sum(fingerprintDensities*binWidth);
            end
            fingerprint=kssolv.analysis.matgenlab.phonon. ...
                PhononDosFingerprint( ...
                fingerprintFrequencies,fingerprintDensities, ...
                nBins,binWidth);
        end

        function value=as_dict(obj)
            value=struct( ...
                "x_module","pymatgen.phonon.dos", ...
                "x_class",phononDosClassName(obj), ...
                "frequencies",obj.frequencies, ...
                "densities",obj.densities);
        end
        function value=asDict(obj),value=obj.as_dict();end

        function text=char(obj)
            rows=strings(numel(obj.frequencies)+1,1);
            rows(1)=sprintf("#%-30s %-30s","Frequency","Density");
            for index=1:numel(obj.frequencies)
                rows(index+1)=sprintf("%.5f %.5f", ...
                    obj.frequencies(index),obj.densities(index));
            end
            text=char(strjoin(rows,newline));
        end
        function text=string(obj),text=string(char(obj));end
    end

    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.phonon. ...
                PhononDos(value.frequencies,value.densities);
        end

        function value=fp_to_dict(fingerprint)
            value=struct();
            value.("n"+string(fingerprint.n_bins)) = ...
                [fingerprint.frequencies(:),fingerprint.densities(:)];
        end

        function value=get_dos_fp_similarity( ...
                first,second,column,point,normalize,metric)
            if nargin<3 || isempty(column),column=1;end
            if nargin<4 || isempty(point),point="All";end
            if nargin<5 || isempty(normalize),normalize=false;end
            if nargin<6 || isempty(metric),metric="tanimoto";end
            firstVector=phononFingerprintVector(first,column,point);
            secondVector=phononFingerprintVector(second,column,point);
            metric=string(metric);
            if ~any(metric==["tanimoto","wasserstein","cosine-sim"])
                error("KSSOLV:Matgenlab:PhononDos:Metric", ...
                    "Invalid metric='%s'.",metric);
            end
            product=dot(firstVector,secondVector);
            if ~normalize && metric=="tanimoto"
                value=product/(norm(firstVector)^2+ ...
                    norm(secondVector)^2-product);
            elseif ~normalize && metric=="wasserstein"
                value=kssolv.analysis.matgenlab.phonon.PhononDos. ...
                    wasserstein( ...
                    cumsum(firstVector*first.bin_width), ...
                    cumsum(secondVector*second.bin_width));
            elseif normalize && metric=="cosine-sim"
                value=product/(norm(firstVector)*norm(secondVector));
            elseif ~normalize && metric=="cosine-sim"
                value=product;
            else
                error("KSSOLV:Matgenlab:PhononDos:Similarity", ...
                    "normalize=true is supported only for cosine-sim.");
            end
        end
    end

    methods (Access=protected)
        function [frequencies,densities]=positiveData(obj)
            index=obj.ind_zero_freq;
            frequencies=obj.frequencies(index:end);
            densities=obj.densities(index:end);
        end
        function value=perFormulaUnit(~,value,structure)
            if ~isempty(structure)
                units=structure.composition.num_atoms/ ...
                    structure.composition.reduced_composition.num_atoms;
                value=value/units;
            end
        end
    end

    methods (Static,Access=private)
        function value=boltzmann(),value=1.380649e-23;end
        function value=avogadro(),value=6.02214076e23;end
        function value=boltzThzPerK()
            value=1.380649e-23/6.62607015e-34/1e12;
        end
        function value=thzToJ(),value=6.62607015e-34*1e12;end

        function output=gaussianFilter(input,sigma)
            radius=round(4*sigma);
            offsets=-radius:radius;
            weights=exp(-0.5*(offsets/sigma).^2);
            weights=weights/sum(weights);
            input=reshape(double(input),[],1);
            output=zeros(size(input));
            count=numel(input);
            for center=1:count
                for offsetIndex=1:numel(offsets)
                    candidate=center+offsets(offsetIndex);
                    while candidate<1 || candidate>count
                        if candidate<1,candidate=1-candidate;
                        else,candidate=2*count+1-candidate;
                        end
                    end
                    output(center)=output(center)+ ...
                        weights(offsetIndex)*input(candidate);
                end
            end
        end

        function value=wasserstein(first,second)
            first=sort(first(:));second=sort(second(:));
            points=unique([first;second]);
            if numel(points)<2,value=0;return,end
            delta=diff(points);
            firstCdf=arrayfun(@(x)mean(first<=x),points(1:end-1));
            secondCdf=arrayfun(@(x)mean(second<=x),points(1:end-1));
            value=sum(abs(firstCdf-secondCdf).*delta);
        end
    end
end

function value=numpyInterp(x,y,query)
%NUMPYINTERP Match numpy.interp's constant endpoint extension.
bounded=min(max(query,min(x)),max(x));
value=interp1(x,y,bounded,"linear");
end

function value=deprecatedTemperature(varargin)
if numel(varargin)>=2 && lower(string(varargin{1}))=="t"
    value=varargin{2};
else
    error("KSSOLV:Matgenlab:PhononDos:Temperature", ...
        "A temperature must be supplied.");
end
end

function vector=phononFingerprintVector(fingerprint,column,point)
if ~isa(fingerprint, ...
        "kssolv.analysis.matgenlab.phonon.PhononDosFingerprint")
    error("KSSOLV:Matgenlab:PhononDos:Fingerprint", ...
        "Similarity requires PhononDosFingerprint inputs.");
end
if ~ismember(column,[0,1])
    error("KSSOLV:Matgenlab:PhononDos:Column", ...
        "column must be 0 or 1.");
end
if ~(ischar(point)||isstring(point)) && ...
        (~isscalar(point)||~ismember(double(point),[0,1]))
    error("KSSOLV:Matgenlab:PhononDos:Point", ...
        "A fingerprint contains one point group.");
end
if column==0,vector=fingerprint.frequencies(:);
else,vector=fingerprint.densities(:);
end
end

function value=phononDosClassName(obj)
parts=split(string(class(obj)),".");
value=parts(end);
end
