classdef MaterialsProjectDFTMixingScheme < kssolv.analysis.matgenlab.analysis.compatibility.Compatibility
    %#ok<*MSNU>
    %MATERIALSPROJECTDFTMIXINGSCHEME Mix a complete base hull with preferred DFT.
    properties
        name (1,1) string = "MP DFT mixing scheme"
        structure_matcher
        run_type_1 (1,1) string = "GGA(+U)"
        run_type_2 (1,1) string = "r2SCAN"
        valid_rtypes_1 (1,:) string = ["GGA","GGA+U"]
        valid_rtypes_2 (1,:) string = ["r2SCAN","R2SCAN"]
        compat_1 = []
        compat_2 = []
        fuzzy_matching (1,1) logical = true
        check_potcar (1,1) logical = true
    end
    methods
        function obj=MaterialsProjectDFTMixingScheme(varargin)
            options=struct(structure_matcher=[],run_type_1="GGA(+U)", ...
                run_type_2="r2SCAN",compat_1="default",compat_2=[], ...
                fuzzy_matching=true,check_potcar=true);
            options=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.options(options,varargin);
            if string(options.run_type_1)==string(options.run_type_2)
                error("KSSOLV:Matgenlab:MixingScheme:RunTypes", ...
                    "The two run types must differ.");
            end
            if isempty(options.structure_matcher) %#ok<ALIGN>
                obj.structure_matcher=kssolv.analysis.matgenlab.core.StructureMatcher();
            else,obj.structure_matcher=options.structure_matcher;end
            obj.run_type_1=string(options.run_type_1);
            obj.run_type_2=string(options.run_type_2);
            if upper(obj.run_type_1)=="GGA(+U)" %#ok<ALIGN>
                obj.valid_rtypes_1=["GGA","GGA+U"];
            else,obj.valid_rtypes_1=obj.run_type_1;end
            if upper(obj.run_type_2)=="R2SCAN" %#ok<ALIGN>
                obj.valid_rtypes_2=["r2SCAN","R2SCAN"];
            else,obj.valid_rtypes_2=obj.run_type_2;end
            if ischar(options.compat_1)||isstring(options.compat_1) %#ok<ALIGN>
                if string(options.compat_1)=="default" %#ok<ALIGN>
                    obj.compat_1=kssolv.analysis.matgenlab.analysis. ...
                        compatibility.MaterialsProject2020Compatibility();
                else,obj.compat_1=[];end
            else,obj.compat_1=options.compat_1;end
            obj.compat_2=options.compat_2;
            obj.fuzzy_matching=options.fuzzy_matching;
            obj.check_potcar=options.check_potcar;
            if ~isempty(obj.compat_1)&&isprop(obj.compat_1,"check_potcar")
                obj.compat_1.check_potcar=obj.check_potcar;
            end
            if ~isempty(obj.compat_2)&&isprop(obj.compat_2,"check_potcar")
                obj.compat_2.check_potcar=obj.check_potcar;
            end
        end
        function values=process_entries(obj,entries,varargin)
            options=struct(clean=true,verbose=false,inplace=true, ...
                mixing_state_data=[]);
            options=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.options(options,varargin);
            if ~iscell(entries),entries=num2cell(entries);end
            if isscalar(entries),values={};return,end
            if ~options.inplace
                entries=cellfun(@(item)item.copy(),entries,"UniformOutput",false);
            end
            if options.clean
                for index=1:numel(entries),entries{index}.energy_adjustments={};end
            end
            [first,second]=obj.filterEntries(entries);
            state=options.mixing_state_data;
            if isempty(state),state=obj.get_mixing_state_data([first,second]);end
            values={};
            for entry=[first,second]
                try
                    adjustments=obj.get_adjustments(entry{1},state);
                catch exception
                    if exception.identifier== ...
                            kssolv.analysis.matgenlab.analysis.compatibility. ...
                            CompatibilityError.Identifier
                        continue
                    end
                    rethrow(exception)
                end
                duplicate=false;
                for adjustment=adjustments
                    same=cellfun(@(item)string(item.name)== ...
                        string(adjustment{1}.name),entry{1}.energy_adjustments);
                    if any(same)
                        existing=entry{1}.energy_adjustments{find(same,1)};
                        if abs(existing.value-adjustment{1}.value)>1e-12
                            duplicate=true;
                        end
                    else
                        entry{1}.energy_adjustments{end+1}=adjustment{1}; %#ok<FXSETA>
                    end
                end
                if ~duplicate,values{end+1}=entry{1};end %#ok<AGROW>
            end
            if options.verbose,obj.display_entries(values);end
        end
        function adjustments=get_adjustments(obj,entry,varargin)
            options=struct(mixing_state_data=[]);
            options=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.options(options,varargin);
            state=options.mixing_state_data;
            if isempty(state)
                kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                    incompatible("mixing_state_data is required.");
            end
            runType=string(kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.field_or(entry.parameters,"run_type",""));
            if ~any(runType==[obj.valid_rtypes_1,obj.valid_rtypes_2])
                kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                    incompatible("Invalid run type.");
            end
            id=string(entry.entry_id);
            if ~any(state.entry_id_1==id)&&~any(state.entry_id_2==id)
                kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                    incompatible("Entry is absent from mixing state data.");
            end
            if ~any(abs(state.energy_1-entry.energy_per_atom)<1e-10)&& ...
                    ~any(abs(state.energy_2-entry.energy_per_atom)<1e-10)
                kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                    incompatible("Entry energy changed after state generation.");
            end
            stableRows=state(state.is_stable_1,:);
            matches=stableRows.entry_id_2~="";
            adjustments={};adjustmentName="MP "+obj.run_type_1+"/"+obj.run_type_2+ ...
                " mixing adjustment";
            isFirst=any(runType==obj.valid_rtypes_1);
            if all(matches)
                if ~isFirst,return,end
                row=state(state.entry_id_1==id,:);
                if row.entry_id_2~=""
                    kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                        incompatible("A matching preferred-functional entry exists.");
                end
                correction=(row.hull_energy_2-row.hull_energy_1)* ...
                    entry.composition.num_atoms;
                adjustments={obj.mixingAdjustment(correction,adjustmentName)};
            elseif any(matches)
                if isFirst
                    row=state(state.entry_id_1==id,:);
                    if row.entry_id_2~=""
                        kssolv.analysis.matgenlab.analysis.compatibility. ...
                            internal.incompatible( ...
                            "A matching preferred-functional entry exists.");
                    end
                    return
                end
                compositionRows=state(state.formula==entry.reduced_formula,:);
                stableMatch=compositionRows(compositionRows.is_stable_1& ...
                    compositionRows.entry_id_2~="",:);
                if ~isempty(stableMatch)
                    above=entry.energy_per_atom-stableMatch.energy_2(1);
                    correction=(compositionRows.hull_energy_1(1)+above- ...
                        entry.energy_per_atom)*entry.composition.num_atoms;
                    adjustments={obj.mixingAdjustment(correction,adjustmentName)};return
                end
                matched=compositionRows(compositionRows.entry_id_2==id& ...
                    compositionRows.entry_id_1~="",:);
                if ~isempty(matched)
                    correction=(matched.energy_1(1)-entry.energy_per_atom)* ...
                        entry.composition.num_atoms;
                    adjustments={obj.mixingAdjustment(correction,adjustmentName)};return
                end
                kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                    incompatible("No matching base-functional material.");
            else
                if isFirst,return,end
                kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                    incompatible("No preferred-functional ground states are available.");
            end
        end
        function state=get_mixing_state_data(obj,entries)
            if ~iscell(entries),entries=num2cell(entries);end
            entries=entries(cellfun(@(item)isa(item, ...
                "kssolv.analysis.matgenlab.core.ComputedStructureEntry"),entries));
            first=entries(cellfun(@(item)any(string(item.parameters.run_type)== ...
                obj.valid_rtypes_1),entries));
            second=entries(cellfun(@(item)any(string(item.parameters.run_type)== ...
                obj.valid_rtypes_2),entries));
            pd1=[];pd2=[];
            try
                pd1=kssolv.analysis.matgenlab.analysis.PhaseDiagram(first);
            catch
            end
            try
                pd2=kssolv.analysis.matgenlab.analysis.PhaseDiagram(second);
            catch
            end
            allEntries=[first,second];groups={};
            used=false(1,numel(allEntries));
            for index=1:numel(allEntries)
                if used(index),continue,end
                group=index;used(index)=true;
                for other=index+1:numel(allEntries)
                    if used(other)||allEntries{other}.reduced_formula~= ...
                            allEntries{index}.reduced_formula,continue,end
                    fuzzy=obj.fuzzy_matching&&any(allEntries{index}.reduced_formula== ...
                        ["O2","H2","Cl2","F2","N2","I","Br","H2O"])&& ...
                        allEntries{index}.structure.num_sites== ...
                        allEntries{other}.structure.num_sites;
                    if fuzzy||obj.structure_matcher.fit( ...
                            allEntries{index}.structure,allEntries{other}.structure)
                        group(end+1)=other;used(other)=true; %#ok<AGROW>
                    end
                end
                groups{end+1}=group; %#ok<AGROW>
            end
            count=numel(groups);formula=strings(count,1);
            spacegroup=-ones(count,1);num_sites=zeros(count,1);
            is_stable_1=false(count,1);entry_id_1=strings(count,1); %#ok<PROP,MSNU>
            entry_id_2=strings(count,1);run_type_1=strings(count,1); %#ok<PROP,MSNU>
            run_type_2=strings(count,1);energy_1=NaN(count,1); %#ok<PROP,MSNU>
            energy_2=NaN(count,1);hull_energy_1=NaN(count,1);
            hull_energy_2=NaN(count,1);
            for rowIndex=1:count
                groupEntries=allEntries(groups{rowIndex});
                formula(rowIndex)=groupEntries{1}.reduced_formula; %#ok<PROP,MSNU>
                num_sites(rowIndex)=groupEntries{1}.structure.num_sites;
                groupFirst=groupEntries(cellfun(@(item)any( ...
                    string(item.parameters.run_type)==obj.valid_rtypes_1), ...
                    groupEntries));
                groupSecond=groupEntries(cellfun(@(item)any( ...
                    string(item.parameters.run_type)==obj.valid_rtypes_2), ...
                    groupEntries));
                if ~isempty(groupFirst)
                    [~,index]=min(cellfun(@(item)item.energy_per_atom,groupFirst));
                    item=groupFirst{index};
                    entry_id_1(rowIndex)=string(item.entry_id); %#ok<PROP,MSNU>
                    run_type_1(rowIndex)=string(item.parameters.run_type); %#ok<PROP>
                    energy_1(rowIndex)=item.energy_per_atom;
                    if ~isempty(pd1)
                        is_stable_1(rowIndex)=any(cellfun(@(stable)stable==item, ...
                            pd1.stable_entries));
                    end
                end
                if ~isempty(groupSecond)
                    [~,index]=min(cellfun(@(item)item.energy_per_atom,groupSecond));
                    item=groupSecond{index};
                    entry_id_2(rowIndex)=string(item.entry_id); %#ok<PROP,MSNU>
                    run_type_2(rowIndex)=string(item.parameters.run_type); %#ok<PROP>
                    energy_2(rowIndex)=item.energy_per_atom;
                end
                comp=groupEntries{1}.composition;
                if ~isempty(pd1),hull_energy_1(rowIndex)= ...
                        pd1.get_hull_energy_per_atom(comp);end
                if ~isempty(pd2),hull_energy_2(rowIndex)= ...
                        pd2.get_hull_energy_per_atom(comp);end
            end
            state=table(formula,spacegroup,num_sites,is_stable_1, ...
                entry_id_1,entry_id_2,run_type_1,run_type_2,energy_1, ...
                energy_2,hull_energy_1,hull_energy_2); %#ok<PROP>
            state=sortrows(state,["formula","energy_1","spacegroup","num_sites"]);
        end
        function output=display_entries(~,entries)
            if ~iscell(entries),entries=num2cell(entries);end
            count=numel(entries);entry_id=strings(count,1);
            formula=strings(count,1);run_type=strings(count,1);
            energy_per_atom=zeros(count,1);correction_per_atom=zeros(count,1);
            for index=1:count
                entry_id(index)=string(entries{index}.entry_id);
                formula(index)=entries{index}.reduced_formula;
                run_type(index)=string(entries{index}.parameters.run_type);
                energy_per_atom(index)=entries{index}.energy_per_atom;
                correction_per_atom(index)=entries{index}.correction_per_atom;
            end
            output=sortrows(table(entry_id,formula,run_type, ...
                energy_per_atom,correction_per_atom), ...
                ["formula","energy_per_atom"]);
            disp(output);
        end
        function data=as_dict(obj)
            data=as_dict@kssolv.analysis.matgenlab.analysis.compatibility. ...
                Compatibility(obj);
            data.run_type_1=obj.run_type_1;data.run_type_2=obj.run_type_2;
            data.fuzzy_matching=obj.fuzzy_matching;
            data.check_potcar=obj.check_potcar;
        end
    end
    methods (Access=private)
        function [first,second]=filterEntries(obj,entries)
            filtered={};ids=strings(1,0);
            for entry=entries
                runType=string(kssolv.analysis.matgenlab.analysis. ...
                    compatibility.internal.field_or(entry{1}.parameters, ...
                    "run_type",""));
                if ~any(runType==[obj.valid_rtypes_1,obj.valid_rtypes_2])|| ...
                        isempty(entry{1}.entry_id),continue,end
                id=string(entry{1}.entry_id);
                if any(ids==id)
                    error("KSSOLV:Matgenlab:MixingScheme:DuplicateId", ...
                        "All entry IDs must be unique.");
                end
                ids(end+1)=id;filtered{end+1}=entry{1}; %#ok<AGROW>
            end
            first=filtered(cellfun(@(item)any(string( ...
                item.parameters.run_type)==obj.valid_rtypes_1),filtered));
            second=filtered(cellfun(@(item)any(string( ...
                item.parameters.run_type)==obj.valid_rtypes_2),filtered));
            if ~isempty(obj.compat_1)
                first=obj.compat_1.process_entries(first);
            end
            if ~isempty(obj.compat_2)
                second=obj.compat_2.process_entries(second);
            end
            if ~isempty(first)
                allowed=unique([kssolv.analysis.matgenlab.core.EntrySet(first).chemsys]);
                second=second(cellfun(@(item)all(ismember( ...
                    kssolv.analysis.matgenlab.analysis.compatibility. ...
                    internal.entry_symbols(item),allowed)),second));
            end
        end
        function item=mixingAdjustment(obj,value,name)
            item=kssolv.analysis.matgenlab.core.ConstantEnergyAdjustment( ...
                value,"uncertainty",0,"name",name,"cls",obj.as_dict());
        end
    end
end
