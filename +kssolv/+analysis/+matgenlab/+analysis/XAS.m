classdef XAS < kssolv.analysis.matgenlab.core.Spectrum
    %XAS X-ray absorption spectrum with XANES/EXAFS stitching.
    properties
        structure
        absorbing_element
        edge (1,1) string
        spectrum_type (1,1) string
        e0 (1,1) double
        k
        absorbing_index
        zero_negative_intensity (1,1) logical
    end
    properties (Dependent, SetAccess=private)
        energy
        intensity
    end
    methods
        function obj=XAS(x,y,structure,absorbingElement,edge, ...
                spectrumType,absorbingIndex,zeroNegativeIntensity)
            if nargin<5||isempty(edge),edge="K";end
            if nargin<6||isempty(spectrumType),spectrumType="XANES";end
            if nargin<7,absorbingIndex=[];end
            if nargin<8||isempty(zeroNegativeIntensity)
                zeroNegativeIntensity=false;
            end
            obj@kssolv.analysis.matgenlab.core.Spectrum( ...
                x,y,structure,absorbingElement,edge,spectrumType, ...
                absorbingIndex,zeroNegativeIntensity);
            obj.structure=structure;
            obj.absorbing_element= ...
                kssolv.analysis.matgenlab.core.Element(absorbingElement);
            obj.edge=string(edge);
            obj.spectrum_type=string(spectrumType);
            derivative=gradient(obj.y)./gradient(obj.x);
            [~,index]=max(derivative);
            obj.e0=obj.x(index);
            difference=obj.x-obj.e0;
            obj.k=sign(difference).*sqrt(abs(difference)/3.8537);
            obj.absorbing_index=absorbingIndex;
            negative=obj.y<0;
            if mean(negative)>0.05
                warning("KSSOLV:Matgenlab:XAS:NegativeIntensity", ...
                    "More than 5%% of XAS intensities are negative.");
            end
            obj.zero_negative_intensity=logical(zeroNegativeIntensity);
            if obj.zero_negative_intensity,obj.y(negative)=0;end
        end

        function value=get.energy(obj),value=obj.x;end
        function value=get.intensity(obj),value=obj.y;end

        function output=stitch(obj,other,numSamples,mode)
            if nargin<3||isempty(numSamples),numSamples=500;end
            if nargin<4||isempty(mode),mode="XAFS";end
            matcher=kssolv.analysis.matgenlab.core.StructureMatcher();
            if ~matcher.fit(obj.structure,other.structure)
                error("KSSOLV:Matgenlab:XAS:Structure", ...
                    "The input structures for spectra mismatch.");
            end
            if obj.absorbing_element~=other.absorbing_element
                error("KSSOLV:Matgenlab:XAS:Element", ...
                    "The absorbing elements differ.");
            end
            if ~isequal(obj.absorbing_index,other.absorbing_index)
                error("KSSOLV:Matgenlab:XAS:Index", ...
                    "The absorbing site indices differ.");
            end
            mode=upper(string(mode));
            if mode=="XAFS"
                output=stitchXAFS(obj,other,numSamples);
            elseif mode=="L23"
                output=stitchL23(obj,other,numSamples);
            else
                error("KSSOLV:Matgenlab:XAS:Mode", ...
                    "Only XAFS and L23 stitching modes are supported.");
            end
        end

        function value=asDict(obj)
            value=asDict@kssolv.analysis.matgenlab.core.Spectrum(obj);
            value.x_module="pymatgen.analysis.xas.spectrum";
            value.x_class="XAS";
            value.structure=obj.structure.as_dict();
            value.absorbing_element=char(obj.absorbing_element.symbol);
            value.edge=char(obj.edge);
            value.spectrum_type=char(obj.spectrum_type);
            if isempty(obj.absorbing_index)
                value.absorbing_index=[];
            else
                value.absorbing_index=obj.absorbing_index-1;
            end
            value.zero_negative_intensity=obj.zero_negative_intensity;
        end
    end
    methods (Static)
        function obj=from_dict(value)
            structure=value.structure;
            if isstruct(structure)
                structure=kssolv.analysis.matgenlab.core.Structure. ...
                    from_dict(structure);
            end
            element=value.absorbing_element;
            if isstruct(element)
                if isfield(element,"element"),element=element.element;
                elseif isfield(element,"symbol"),element=element.symbol;end
            end
            edge="K";spectrumType="XANES";absorbingIndex=[];
            zeroNegative=false;
            if isfield(value,"edge"),edge=value.edge;end
            if isfield(value,"spectrum_type")
                spectrumType=value.spectrum_type;
            end
            if isfield(value,"absorbing_index")
                absorbingIndex=value.absorbing_index;
                if isempty(absorbingIndex)
                    absorbingIndex=[];
                else
                    absorbingIndex=double(absorbingIndex)+1;
                end
            end
            if isfield(value,"zero_negative_intensity")
                zeroNegative=value.zero_negative_intensity;
            end
            obj=kssolv.analysis.matgenlab.analysis.XAS( ...
                value.x,value.y,structure,element,edge,spectrumType, ...
                absorbingIndex,zeroNegative);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.analysis.XAS.from_dict(value);end
    end
end

function output=stitchXAFS(first,second,numSamples)
if first.edge~=second.edge
    error("KSSOLV:Matgenlab:XAS:Edge", ...
        "XAFS stitching requires the same absorption edge.");
end
if first.spectrum_type==second.spectrum_type
    error("KSSOLV:Matgenlab:XAS:SpectrumType", ...
        "XAFS stitching requires one XANES and one EXAFS spectrum.");
end
if first.spectrum_type=="XANES",xanes=first;exafs=second;
else,xanes=second;exafs=first;end
if max(xanes.x)<min(exafs.x)
    error("KSSOLV:Matgenlab:XAS:Overlap", ...
        "XANES and EXAFS spectra need an energy overlap.");
end
distance=abs(xanes.k-3);
minimum=min(distance);
index=find(distance==minimum,1);
wavenumber=xanes.k(1:index-1);
mu=xanes.y(1:index-1);
blendK=linspace(3,max(xanes.k),50).';
weight=cos((pi/2)*(blendK-3)/(max(xanes.k)-3)).^2;
xanesMu=interp1(xanes.k,xanes.y,blendK,"linear",0);
exafsMu=interp1(exafs.k,exafs.y,blendK,"linear",0);
wavenumber=[wavenumber;blendK];
mu=[mu;weight.*xanesMu+(1-weight).*exafsMu];
[~,index]=min(abs(exafs.k-max(xanes.k)));
wavenumber=[wavenumber;exafs.k(index:end)];
mu=[mu;exafs.y(index:end)];
[wavenumber,uniqueIndices]=unique(wavenumber,"stable");
mu=mu(uniqueIndices);
finalK=linspace(min(wavenumber),max(wavenumber),numSamples).';
finalMu=interp1(wavenumber,mu,finalK,"linear",0);
energy=sign(finalK).*3.8537.*finalK.^2+xanes.e0;
output=kssolv.analysis.matgenlab.analysis.XAS( ...
    energy,finalMu,first.structure,first.absorbing_element, ...
    xanes.edge,"XAFS");
end

function output=stitchL23(first,second,numSamples)
if first.spectrum_type~="XANES"||second.spectrum_type~="XANES"
    error("KSSOLV:Matgenlab:XAS:L23Type", ...
        "L23 stitching accepts XANES spectra only.");
end
if ~any(first.edge==["L2","L3"])|| ...
        ~any(second.edge==["L2","L3"])||first.edge==second.edge
    error("KSSOLV:Matgenlab:XAS:L23Edge", ...
        "L23 stitching requires one L2 and one L3 edge.");
end
if first.edge=="L2",l2=first;l3=second;else,l2=second;l3=first;end
if l2.absorbing_element.number>30
    error("KSSOLV:Matgenlab:XAS:L23Element", ...
        "L23 stitching supports elements through Zn.");
end
energy=linspace(min(l3.x),max(l3.x),numSamples).';
l2Mu=max(interp1(l2.x,l2.y,energy,"spline","extrap"),0);
if min(energy)<min(l3.x)||max(energy)>max(l3.x)
    error("KSSOLV:Matgenlab:XAS:L23Bounds", ...
        "Requested interpolation falls outside the L3 spectrum.");
end
l3Mu=interp1(l3.x,l3.y,energy,"spline");
output=kssolv.analysis.matgenlab.analysis.XAS( ...
    energy,l2Mu+l3Mu,first.structure,first.absorbing_element, ...
    "L23","XANES");
end
