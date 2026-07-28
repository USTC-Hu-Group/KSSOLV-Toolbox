classdef CorrectionCalculator < handle
    %CORRECTIONCALCULATOR Fit MP-style composition corrections from references.
    properties
        species (1,:) string
        max_error (1,1) double = .1
        allow_unstable = .1
        exclude_polyanions (1,:) string
        corrections double = []
        corrections_std_error double = []
        corrections_dict struct = struct()
        exp_compounds = []
        calc_compounds = []
        names (1,:) string = strings(1,0)
        diffs double = []
        coeff_mat double = []
        exp_uncer double = []
        pcov double = []
    end
    methods
        function obj=CorrectionCalculator(varargin)
            defaults=["oxide","peroxide","superoxide","S","F","Cl","Br", ...
                "I","N","Se","Si","Sb","Te","V","Cr","Mn","Fe","Co", ...
                "Ni","W","Mo","H"];
            exclusions=["SO4","SO3","CO3","NO3","NO2","OCl3","ClO3", ...
                "ClO4","HO","ClO","SeO3","TiO3","TiO4","WO4","SiO3", ...
                "SiO4","Si2O5","PO3","PO4","P2O7"];
            options=struct(species=defaults,max_error=.1,allow_unstable=.1, ...
                exclude_polyanions=exclusions);
            options=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.options(options,varargin);
            obj.species=string(options.species);obj.max_error=options.max_error;
            if isequal(options.allow_unstable,false),obj.allow_unstable=.1;
            else,obj.allow_unstable=options.allow_unstable;end
            obj.exclude_polyanions=string(options.exclude_polyanions);
        end
        function result=compute_from_files(obj,expGz,calcGz)
            expData=obj.readJson(expGz);calcData=obj.readJson(calcGz);
            result=obj.compute_corrections(expData,calcData);
        end
        function result=compute_corrections(obj,expEntries,calcEntries)
            obj.exp_compounds=expEntries;obj.calc_compounds=calcEntries;
            [formulae,entries]=obj.decodeCalcEntries(calcEntries);
            if isstruct(expEntries),expEntries=num2cell(expEntries);end
            maximum=numel(expEntries);accepted=0;
            obj.names=strings(1,maximum);obj.diffs=NaN(maximum,1);
            obj.coeff_mat=zeros(maximum,numel(obj.species));
            obj.exp_uncer=NaN(maximum,1);
            for rowIndex=1:numel(expEntries)
                row=expEntries{rowIndex};
                formula=string(row.formula);
                comp=kssolv.analysis.matgenlab.core.Composition(formula);
                formula=comp.reduced_formula;
                entryIndex=find(formulae==formula,1);
                if isempty(entryIndex),continue,end
                entry=entries{entryIndex};entry.energy_adjustments={};
                expEnergy=obj.readField(row,["exp energy","exp_energy", ...
                    "expenergy","expEnergy"],NaN);
                uncertainty=obj.readField(row,"uncertainty",0);
                if abs(uncertainty/expEnergy)>obj.max_error,continue,end
                if any(contains(formula,obj.exclude_polyanions))|| ...
                        any(contains(string(row.formula),obj.exclude_polyanions))
                    continue
                end
                if isnumeric(obj.allow_unstable)&&isscalar(obj.allow_unstable)
                    above=kssolv.analysis.matgenlab.analysis.compatibility. ...
                        internal.field_or(entry.data,"e_above_hull",[]);
                    if isempty(above) %#ok<ALIGN>
                        error("KSSOLV:Matgenlab:CorrectionCalculator:Hull", ...
                            "Missing e_above_hull data.");
                    elseif above>obj.allow_unstable,continue,end
                end
                elemental=0;missingElement=false;
                symbols=string(cellfun(@(item)item.symbol,comp.elements, ...
                    "UniformOutput",false));
                for symbol=symbols
                    referenceFormula=kssolv.analysis.matgenlab.core. ...
                        Composition(symbol).reduced_formula;
                    referenceIndex=find(formulae==referenceFormula,1);
                    if isempty(referenceIndex),missingElement=true;break,end
                    elemental=elemental+comp.amountOf(symbol)* ...
                        entries{referenceIndex}.energy_per_atom;
                end
                if missingElement
                    error("KSSOLV:Matgenlab:CorrectionCalculator:Reference", ...
                        "Computed entries are missing an elemental reference.");
                end
                [~,compoundFactor]= ...
                    entry.composition.get_reduced_composition_and_factor();
                energy=entry.energy/compoundFactor-elemental;
                coefficients=zeros(1,numel(obj.species));
                for index=1:numel(obj.species)
                    specie=obj.species(index);
                    if any(specie==["oxide","peroxide","superoxide"])
                        oxide=string(kssolv.analysis.matgenlab.analysis. ...
                            compatibility.internal.field_or(entry.data, ...
                            "oxide_type",""));
                        if oxide==specie,coefficients(index)=comp.amountOf("O");end
                    elseif specie=="S"
                        sulfide=string(kssolv.analysis.matgenlab.analysis. ...
                            compatibility.internal.field_or(entry.data, ...
                            "sulfide_type",""));
                        if sulfide==""&&isa(entry, ...
                                "kssolv.analysis.matgenlab.core.ComputedStructureEntry") %#ok<ALIGN>
                            sulfide=string(kssolv.analysis.matgenlab.core. ...
                                sulfide_type(entry.structure));
                        elseif sulfide=="",sulfide="sulfide";end
                        if comp.contains("S")&&sulfide=="sulfide"
                            coefficients(index)=comp.amountOf("S");
                        end
                    else
                        coefficients(index)=comp.amountOf(specie);
                    end
                end
                accepted=accepted+1;obj.names(accepted)=formula;
                obj.diffs(accepted)=(expEnergy-energy)/comp.num_atoms;
                obj.coeff_mat(accepted,:)=coefficients/comp.num_atoms;
                obj.exp_uncer(accepted)=uncertainty/comp.num_atoms;
            end
            obj.names=obj.names(1:accepted);obj.diffs=obj.diffs(1:accepted);
            obj.coeff_mat=obj.coeff_mat(1:accepted,:);
            obj.exp_uncer=obj.exp_uncer(1:accepted);
            sigma=obj.exp_uncer;sigma(sigma==0)=NaN;
            meanUncertainty=mean(sigma,"omitnan");
            if isnan(meanUncertainty)
                initial=ones(numel(obj.species),1);
                obj.corrections=initial+pinv(obj.coeff_mat)* ...
                    (obj.diffs-obj.coeff_mat*initial);
                residual=obj.diffs-obj.coeff_mat*obj.corrections;
                dof=max(size(obj.coeff_mat,1)-rank(obj.coeff_mat),1);
                obj.pcov=(residual'*residual/dof)* ...
                    pinv(obj.coeff_mat'*obj.coeff_mat);
            else
                sigma(isnan(sigma))=meanUncertainty;
                weighted=obj.coeff_mat./sigma;
                target=obj.diffs./sigma;
                initial=ones(numel(obj.species),1);
                obj.corrections=initial+pinv(weighted)* ...
                    (target-weighted*initial);
                obj.pcov=pinv(weighted'*weighted);
            end
            obj.corrections_std_error=sqrt(max(diag(obj.pcov),0));
            result=struct();
            for index=1:numel(obj.species)
                key=matlab.lang.makeValidName(obj.species(index));
                result.(key)=[round(obj.corrections(index),3), ...
                    round(obj.corrections_std_error(index),4)];
            end
            result.ozonide=[0,0];obj.corrections_dict=result;
        end
        function axesHandle=graph_residual_error(obj)
            obj.requireFit();
            residual=abs(obj.diffs-obj.coeff_mat*obj.corrections);
            [residual,order]=sort(residual);
            axesHandle=axes(figure("Visible","off"));
            scatter(axesHandle,1:numel(residual),residual);
            title(axesHandle,"Residual Errors");
            ylabel(axesHandle,"Residual Error (eV/atom)");
            axesHandle.UserData.labels=obj.names(order);
        end
        function axesHandle=graph_residual_error_per_species(obj,specie)
            obj.requireFit();specie=string(specie);
            index=find(obj.species==specie,1);
            if isempty(index)
                error("KSSOLV:Matgenlab:CorrectionCalculator:Species", ...
                    "Not a valid species.");
            end
            keep=obj.coeff_mat(:,index)~=0;
            residual=abs(obj.diffs-obj.coeff_mat*obj.corrections);
            residual=residual(keep);labels=obj.names(keep);
            [residual,order]=sort(residual);
            axesHandle=axes(figure("Visible","off"));
            scatter(axesHandle,1:numel(residual),residual);
            title(axesHandle,"Residual Errors for "+specie);
            ylabel(axesHandle,"Residual Error (eV/atom)");
            axesHandle.UserData.labels=labels(order);
        end
        function path=make_yaml(obj,varargin)
            obj.requireFit();
            options=struct(name="MP2020",dir="");
            options=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.options(options,varargin);
            if strlength(string(options.dir))==0,folder=pwd;
            else,folder=string(options.dir);end
            path=fullfile(folder,string(options.name)+"Compatibility.yaml");
            file=fopen(path,"w");
            if file<0
                error("KSSOLV:Matgenlab:CorrectionCalculator:Write", ...
                    "Unable to create YAML output.");
            end
            cleanup=onCleanup(@()fclose(file));
            fprintf(file,"Name: %s\nCorrections:\n  CompositionCorrections:\n", ...
                string(options.name));
            transition=["V","Cr","Mn","Fe","Co","Ni","W","Mo"];
            for specie=obj.species
                if any(specie==transition),continue,end
                value=obj.corrections_dict.(matlab.lang.makeValidName(specie));
                fprintf(file,"    %s: %.6g\n",specie,value(1));
            end
            fprintf(file,"    ozonide: 0\n  GGAUMixingCorrections:\n    O:\n");
            for specie=transition
                if ~isfield(obj.corrections_dict,char(specie)),continue,end
                value=obj.corrections_dict.(char(specie));
                fprintf(file,"      %s: %.6g\n",specie,value(1));
            end
            fprintf(file,"    F:\n");
            for specie=transition
                if ~isfield(obj.corrections_dict,char(specie)),continue,end
                value=obj.corrections_dict.(char(specie));
                fprintf(file,"      %s: %.6g\n",specie,value(1));
            end
            clear cleanup
        end
    end
    methods (Access=private)
        function requireFit(obj)
            if isempty(obj.corrections)
                error("KSSOLV:Matgenlab:CorrectionCalculator:NotFit", ...
                    "Call compute_corrections first.");
            end
        end
        function value=readJson(~,path)
            path=string(path);
            if endsWith(path,".gz") %#ok<ALIGN>
                folder=tempname;mkdir(folder);
                cleanup=onCleanup(@()rmdir(folder,"s"));
                files=gunzip(path,folder);value=jsondecode(fileread(files{1}));
                clear cleanup
            else,value=jsondecode(fileread(path));end
        end
        function [formulae,entries]=decodeCalcEntries(~,raw)
            rawNames=fieldnames(raw);formulae=strings(1,numel(rawNames));
            entries=cell(1,numel(rawNames));
            for index=1:numel(rawNames)
                item=raw.(rawNames{index});
                if isfield(item,"structure")
                    entries{index}=kssolv.analysis.matgenlab.core. ...
                        ComputedStructureEntry.from_dict(item);
                else
                    entries{index}=kssolv.analysis.matgenlab.core. ...
                        ComputedEntry.from_dict(item);
                end
                formulae(index)=entries{index}.reduced_formula;
            end
        end
        function value=readField(~,row,names,default)
            names=string(names);value=default;
            for name=names
                candidates=[name,matlab.lang.makeValidName(name), ...
                    erase(name,[" ","_"])];
                for candidate=candidates
                    if isfield(row,char(candidate))
                        value=row.(char(candidate));return
                    end
                end
            end
        end
    end
end
