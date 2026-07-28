classdef IRDielectricTensor
    %IRDIELECTRICTENSOR Ionic frequency-dependent dielectric response.

    properties (SetAccess=private)
        oscillator_strength
        ph_freqs_gamma (:,1) double
        epsilon_infinity (3,3) double
        structure
    end

    properties (Dependent,SetAccess=private)
        max_phfreq
        nph_freqs
    end

    methods
        function obj=IRDielectricTensor( ...
                oscillatorStrength,phononFrequencies, ...
                epsilonInfinity,structure)
            obj.oscillator_strength=real(oscillatorStrength);
            obj.ph_freqs_gamma=reshape(double(phononFrequencies),[],1);
            obj.epsilon_infinity=double(epsilonInfinity);
            obj.structure=structure;
            if size(obj.oscillator_strength,1)~=obj.nph_freqs || ...
                    ~isequal(size(obj.oscillator_strength,2),3) || ...
                    ~isequal(size(obj.oscillator_strength,3),3)
                error("KSSOLV:Matgenlab:IRDielectricTensor:Shape", ...
                    "oscillator_strength must have shape n_modes-by-3-by-3.");
            end
        end

        function value=get.max_phfreq(obj),value=max(obj.ph_freqs_gamma);end
        function value=get.nph_freqs(obj),value=numel(obj.ph_freqs_gamma);end

        function [frequencies,dielectric]=get_ir_spectra( ...
                obj,broadening,minimum,maximum,divisions)
            if nargin<2||isempty(broadening),broadening=5e-5;end
            if nargin<3||isempty(minimum),minimum=0;end
            if nargin<4,maximum=[];end
            if nargin<5||isempty(divisions),divisions=500;end
            if isscalar(broadening)
                broadening=repmat(double(broadening),obj.nph_freqs,1);
            else
                broadening=reshape(double(broadening),[],1);
            end
            if numel(broadening)~=obj.nph_freqs
                error("KSSOLV:Matgenlab:IRDielectricTensor:Broadening", ...
                    "The broadening list must contain one value per frequency.");
            end
            if isempty(maximum)
                maximum=obj.max_phfreq+max(broadening)*20;
            end
            frequencies=linspace(minimum,maximum,divisions).';
            dielectric=complex(zeros(divisions,3,3));
            for index=4:obj.nph_freqs
                damping=broadening(index)*obj.ph_freqs_gamma(index);
                numerator=reshape( ...
                    obj.oscillator_strength(index,:,:),1,3,3);
                denominator=obj.ph_freqs_gamma(index)^2- ...
                    frequencies.^2-1i*damping;
                dielectric=dielectric+ ...
                    numerator./reshape(denominator,[],1,1);
            end
            dielectric=dielectric+ ...
                reshape(obj.epsilon_infinity,1,3,3);
        end

        function spectrum=get_spectrum( ...
                obj,component,reim,broadening,minimum,maximum, ...
                divisions,label) %#ok<INUSD>
            if nargin<4,broadening=[];end
            if nargin<5,minimum=[];end
            if nargin<6,maximum=[];end
            if nargin<7,divisions=[];end
            [row,column]=componentIndices(component);
            [frequencies,dielectric]=obj.get_ir_spectra( ...
                broadening,minimum,maximum,divisions);
            values=squeeze(dielectric(:,row,column));
            if lower(string(reim))=="re",values=real(values);
            elseif lower(string(reim))=="im",values=imag(values);
            else,error("KSSOLV:Matgenlab:IRDielectricTensor:Part", ...
                    "reim must be 're' or 'im'.");
            end
            spectrum=kssolv.analysis.matgenlab.core.Spectrum( ...
                frequencies*1000,values);
        end

        function plotter=get_plotter( ...
                obj,components,reim,broadening,minimum,maximum,divisions)
            if nargin<2||isempty(components),components={"xx"};end
            if nargin<3||isempty(reim),reim="reim";end
            if nargin<4,broadening=[];end
            if nargin<5,minimum=[];end
            if nargin<6,maximum=[];end
            if nargin<7,divisions=[];end
            if ischar(components)||isstring(components)
                components=cellstr(string(components));
            elseif isnumeric(components)
                components={components};
            end
            plotter=kssolv.analysis.matgenlab.vis.SpectrumPlotter();
            for componentIndex=1:numel(components)
                component=components{componentIndex};
                for part=["re","im"]
                    if contains(string(reim),part)
                        [row,column]=componentIndices(component);
                        axisNames="xyz";
                        prefix="Re";if part=="im",prefix="Im";end
                        label=prefix+"{epsilon_"+ ...
                            extractBetween(axisNames,row,row)+ ...
                            extractBetween(axisNames,column,column)+"}";
                        spectrum=obj.get_spectrum(component,part, ...
                            broadening,minimum,maximum,divisions,label);
                        plotter.add_spectrum(label,spectrum);
                    end
                end
            end
        end

        function ax=plot(obj,components,reim,showFrequencies, ...
                xLimits,yLimits,varargin)
            if nargin<2,components=[];end
            if nargin<3,reim=[];end
            if nargin<4||isempty(showFrequencies),showFrequencies=true;end
            if nargin<5,xLimits=[];end
            if nargin<6,yLimits=[];end
            plotter=obj.get_plotter(components,reim,varargin{:});
            ax=plotter.get_plot(xLimits,yLimits);
            if showFrequencies
                hold(ax,"on");
                scatter(ax,obj.ph_freqs_gamma(4:end)*1000, ...
                    zeros(max(0,obj.nph_freqs-3),1));
                hold(ax,"off");
            end
            xlabel(ax,"Frequency (meV)");
            ylabel(ax,"\epsilon(\omega)");
        end

        function write_json(obj,filename)
            fid=fopen(filename,"w","n","UTF-8");
            if fid<0
                error("KSSOLV:Matgenlab:IRDielectricTensor:Write", ...
                    "Cannot write '%s'.",filename);
            end
            cleanup=onCleanup(@()fclose(fid));
            fwrite(fid,kssolv.analysis.matgenlab.util.encode(obj.as_dict()), ...
                "char");
            clear cleanup
        end

        function value=as_dict(obj)
            value=struct( ...
                "x_module","pymatgen.phonon.ir_spectra", ...
                "x_class","IRDielectricTensor", ...
                "oscillator_strength",obj.oscillator_strength, ...
                "ph_freqs_gamma",obj.ph_freqs_gamma, ...
                "structure",obj.structure.as_dict(), ...
                "epsilon_infinity",obj.epsilon_infinity);
        end
        function value=asDict(obj),value=obj.as_dict();end
    end

    methods (Static)
        function obj=from_dict(value)
            structure=kssolv.analysis.matgenlab.core.Structure. ...
                from_dict(value.structure);
            obj=kssolv.analysis.matgenlab.phonon.IRDielectricTensor( ...
                value.oscillator_strength,value.ph_freqs_gamma, ...
                value.epsilon_infinity,structure);
        end
    end
end

function [row,column]=componentIndices(component)
if isnumeric(component)
    component=reshape(double(component),1,2);
    if any(component==0),component=component+1;end
    row=component(1);column=component(2);
else
    text=char(lower(string(component)));
    if numel(text)~=2
        error("KSSOLV:Matgenlab:IRDielectricTensor:Component", ...
            "component must contain two directions.");
    end
    names='xyz';
    row=find(names==text(1),1);
    column=find(names==text(2),1);
end
if isempty(row)||isempty(column)||any([row,column]<1)|| ...
        any([row,column]>3)
    error("KSSOLV:Matgenlab:IRDielectricTensor:Component", ...
        "component directions must be x/y/z or valid indices.");
end
end
