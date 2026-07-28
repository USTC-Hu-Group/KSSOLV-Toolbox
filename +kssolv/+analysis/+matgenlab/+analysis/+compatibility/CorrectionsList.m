classdef CorrectionsList < kssolv.analysis.matgenlab.analysis.compatibility.Compatibility
    %CORRECTIONSLIST Combine ordered legacy scalar correction objects.
    properties
        corrections cell = cell(1,0)
        run_types (1,:) string = ["GGA","GGA+U","PBE","PBE+U"]
    end
    methods
        function obj=CorrectionsList(corrections,varargin)
            if nargin<1,corrections={};end
            if ~iscell(corrections),corrections=num2cell(corrections);end
            obj.corrections=corrections;
            options=struct(run_types=obj.run_types);
            options=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.options(options,varargin);
            obj.run_types=string(options.run_types);
        end
        function adjustments=get_adjustments(obj,entry)
            runType=kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                field_or(entry.parameters,"run_type","");
            if ~any(string(runType)==obj.run_types)
                kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                    incompatible("Entry has invalid run type '%s'.",string(runType));
            end
            [values,uncertainties]=obj.get_corrections_dict(entry);
            adjustments=cell(1,numel(obj.corrections));used=0;
            for index=1:numel(obj.corrections)
                name=obj.correctionName(obj.corrections{index});
                if ~isKey(values,char(name)),continue,end
                value=values(char(name));
                uncertainty=uncertainties(char(name));
                if value~=0&&uncertainty==0,uncertainty=NaN;end
                used=used+1;
                adjustments{used}= ...
                    kssolv.analysis.matgenlab.core.ConstantEnergyAdjustment( ...
                    value,"uncertainty",uncertainty, ...
                    "name",name,"cls",obj.as_dict());
            end
            adjustments=adjustments(1:used);
        end
        function [values,uncertainties]=get_corrections_dict(obj,entry)
            values=containers.Map("KeyType","char","ValueType","double");
            uncertainties=containers.Map("KeyType","char","ValueType","double");
            for index=1:numel(obj.corrections)
                correction=obj.corrections{index};
                value=correction.get_correction(entry);
                if value~=0
                    name=char(obj.correctionName(correction));
                    values(name)=value;
                    uncertainties(name)=correction.get_uncertainty(entry);
                end
            end
        end
        function data=get_explanation_dict(obj,entry)
            processed=obj.process_entry(entry);
            data=struct(compatibility=string(extractAfter(class(obj), ...
                "compatibility.")),uncorrected_energy=entry.uncorrected_energy, ...
                corrected_energy=[],correction_uncertainty=[],corrections=struct([]));
            if ~isempty(processed)
                data.corrected_energy=processed.energy;
                data.correction_uncertainty=processed.correction_uncertainty;
            end
            [values,uncertainties]=obj.get_corrections_dict(entry);
            items=repmat(struct(name="",description="",value=0, ...
                uncertainty=0),1,numel(obj.corrections));
            for index=1:numel(obj.corrections)
                correction=obj.corrections{index};
                name=obj.correctionName(correction);
                value=0;uncertainty=0;
                if isKey(values,char(name))
                    value=values(char(name));
                    uncertainty=uncertainties(char(name));
                    if value~=0&&uncertainty==0,uncertainty=NaN;end
                end
                items(index)=struct(name=name, ...
                    description=obj.correctionDescription(correction), ...
                    value=value,uncertainty=uncertainty);
            end
            data.corrections=items;
        end
        function text=explain(obj,entry)
            data=obj.get_explanation_dict(entry);
            text=compose("The uncorrected energy is %.6f eV.", ...
                data.uncorrected_energy);
            for index=1:numel(data.corrections)
                item=data.corrections(index);
                text(end+1)=item.name+": "+compose("%.6f eV",item.value); %#ok<AGROW>
            end
            if ~isempty(data.corrected_energy)
                text(end+1)=compose("The final energy is %.6f eV.", ...
                    data.corrected_energy);
            end
            text=join(text,newline);fprintf("%s\n",text);
        end
        function data=as_dict(obj)
            data=as_dict@kssolv.analysis.matgenlab.analysis.compatibility. ...
                Compatibility(obj);
            data.run_types=obj.run_types;
        end
    end
    methods (Access=private)
        function name=correctionName(~,correction)
            if isa(correction,"kssolv.analysis.matgenlab.analysis.compatibility.PotcarCorrection")
                if correction.input_set=="MIT",setName="MITRelaxSet";
                else,setName="MPRelaxSet";end
                name=setName+" Potcar Correction";
            elseif isa(correction,"kssolv.analysis.matgenlab.analysis.compatibility.GasCorrection")
                name=correction.name+" Gas Correction";
            elseif isa(correction,"kssolv.analysis.matgenlab.analysis.compatibility.AnionCorrection")
                name=correction.name+" Anion Correction";
            elseif isa(correction,"kssolv.analysis.matgenlab.analysis.compatibility.AqueousCorrection")
                name=correction.name+" Aqueous Correction";
            elseif isa(correction,"kssolv.analysis.matgenlab.analysis.compatibility.UCorrection")
                name=correction.name+" "+correction.compat_type+" Correction";
            else
                name=string(extractAfter(class(correction),"compatibility."));
            end
        end
        function text=correctionDescription(~,correction)
            if isa(correction,"kssolv.analysis.matgenlab.analysis.compatibility.PotcarCorrection")
                text="Validate POTCAR metadata against the selected input set.";
            elseif isa(correction,"kssolv.analysis.matgenlab.analysis.compatibility.GasCorrection")
                text="Correct molecular reference energies.";
            elseif isa(correction,"kssolv.analysis.matgenlab.analysis.compatibility.AnionCorrection")
                text="Apply legacy oxide and sulfide corrections.";
            elseif isa(correction,"kssolv.analysis.matgenlab.analysis.compatibility.AqueousCorrection")
                text="Apply legacy aqueous compound corrections.";
            else
                text="Apply the GGA/GGA+U mixing correction.";
            end
        end
    end
end
