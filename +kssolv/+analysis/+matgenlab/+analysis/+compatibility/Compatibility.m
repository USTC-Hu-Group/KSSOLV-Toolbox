classdef Compatibility < kssolv.analysis.matgenlab.util.MSONable
    %COMPATIBILITY Base implementation for applying energy adjustments.
    methods
        function adjustments=get_adjustments(~,~) %#ok<STOUT>
            error("KSSOLV:Matgenlab:Compatibility:Abstract", ...
                "Subclasses must implement get_adjustments.");
        end
        function value=process_entry(obj,entry,varargin)
            options=struct(inplace=true,clean=true,on_error="ignore");
            options=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.options(options,varargin);
            if ~options.inplace,entry=entry.copy();end
            [value,~,incompatible]=obj.processOne( ...
                entry,options.clean,options.on_error);
            if incompatible,value=[];end
        end
        function values=process_entries(obj,entries,varargin)
            options=struct(clean=true,verbose=false,inplace=true, ...
                n_workers=1,on_error="ignore");
            options=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.options(options,varargin);
            if ~iscell(entries),entries=num2cell(entries);end
            if options.n_workers~=1&&options.inplace
                error("KSSOLV:Matgenlab:Compatibility:ParallelInplace", ...
                    "Parallel processing requires inplace=false.");
            end
            values={};
            for index=1:numel(entries)
                entry=entries{index};
                if ~options.inplace,entry=entry.copy();end
                [entry,ignore,incompatible]=obj.processOne( ...
                    entry,options.clean,options.on_error);
                if ~ignore&&~incompatible,values{end+1}=entry;end %#ok<AGROW>
            end
        end
        function text=explain(~,entry)
            lines="The uncorrected energy of "+entry.formula+" is "+ ...
                compose("%.3f eV (%.3f eV/atom).",entry.uncorrected_energy, ...
                entry.uncorrected_energy_per_atom);
            if isempty(entry.energy_adjustments)
                lines(end+1)="No energy adjustments have been applied to this entry.";
            else
                lines(end+1)="The following energy adjustments have been applied:";
                for index=1:numel(entry.energy_adjustments)
                    item=entry.energy_adjustments{index};
                    lines(end+1)="  "+item.name+": "+compose("%.3f eV",item.value); %#ok<AGROW>
                end
            end
            lines(end+1)="The final energy after adjustments is "+ ...
                compose("%.3f eV (%.3f eV/atom).",entry.energy,entry.energy_per_atom);
            text=join(lines,newline); fprintf("%s\n",text);
        end
        function data=as_dict(obj)
            data=struct(x_module="pymatgen.analysis.compatibility", ...
                x_class=string(extractAfter(class(obj),"compatibility.")));
        end
        function data=asDict(obj),data=obj.as_dict();end
    end
    methods (Access=protected)
        function [entry,ignore,incompatible]=processOne( ...
                obj,entry,clean,onError)
            ignore=false;incompatible=false;
            if clean,entry.energy_adjustments={};end
            try
                adjustments=obj.get_adjustments(entry);
            catch exception
                if exception.identifier~= ...
                        kssolv.analysis.matgenlab.analysis.compatibility. ...
                        CompatibilityError.Identifier
                    rethrow(exception);
                end
                if string(onError)=="raise",rethrow(exception);end
                if string(onError)=="warn"
                    warning("KSSOLV:Matgenlab:Compatibility:Rejected", ...
                        "%s",exception.message);
                end
                incompatible=true;return
            end
            if ~iscell(adjustments),adjustments=num2cell(adjustments);end
            for index=1:numel(adjustments)
                item=adjustments{index};
                sameName=false;sameExact=false;
                for priorIndex=1:numel(entry.energy_adjustments)
                    prior=entry.energy_adjustments{priorIndex};
                    namesEqual=string(prior.name)==string(item.name);
                    classesEqual=isequal(prior.cls,item.cls);
                    sameName=sameName||(namesEqual&&classesEqual);
                    sameExact=sameExact||(namesEqual&&classesEqual&& ...
                        abs(prior.value-item.value)<1e-12);
                end
                if sameExact,continue,end
                if sameName
                    warning("KSSOLV:Matgenlab:Compatibility:Overlap", ...
                        "Entry has a conflicting adjustment named '%s'.",item.name);
                    ignore=true;continue
                end
                entry.energy_adjustments{end+1}=item;
            end
        end
    end
end
