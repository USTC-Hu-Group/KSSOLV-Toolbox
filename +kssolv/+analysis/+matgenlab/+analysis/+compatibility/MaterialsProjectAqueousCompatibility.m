classdef MaterialsProjectAqueousCompatibility < kssolv.analysis.matgenlab.analysis.compatibility.Compatibility
    %MATERIALSPROJECTAQUEOUSCOMPATIBILITY MP Pourbaix free-energy referencing.
    properties
        solid_compat = []
        o2_energy = []
        h2o_energy = []
        h2_energy = []
        h2o_adjustments = []
        fit_h2_energy = []
        cpd_entropies struct
        name (1,1) string = "MP Aqueous free energy adjustment"
    end
    methods
        function obj=MaterialsProjectAqueousCompatibility(varargin)
            options=struct(solid_compat="default",o2_energy=[], ...
                h2o_energy=[],h2o_adjustments=[]);
            options=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.options(options,varargin);
            if ischar(options.solid_compat)||isstring(options.solid_compat)
                if string(options.solid_compat)=="default"
                    obj.solid_compat=kssolv.analysis.matgenlab.analysis. ...
                        compatibility.MaterialsProject2020Compatibility();
                elseif string(options.solid_compat)=="none"
                    obj.solid_compat=[];
                else
                    error("KSSOLV:Matgenlab:Compatibility:SolidCompat", ...
                        "Unknown solid compatibility scheme.");
                end
            elseif isempty(options.solid_compat)|| ...
                    isa(options.solid_compat, ...
                    "kssolv.analysis.matgenlab.analysis.compatibility.Compatibility")
                obj.solid_compat=options.solid_compat;
            else
                error("KSSOLV:Matgenlab:Compatibility:SolidCompat", ...
                    "Expected a Compatibility instance or empty.");
            end
            obj.o2_energy=options.o2_energy;obj.h2o_energy=options.h2o_energy;
            obj.h2o_adjustments=options.h2o_adjustments;
            obj.cpd_entropies=struct(O2=.316731,N2=.295729,F2=.313025, ...
                Cl2=.344373,Br=.235039,Hg=.234421,H2O=.071963);
            if isempty(obj.o2_energy)||isempty(obj.h2o_energy)|| ...
                    isempty(obj.h2o_adjustments)||obj.o2_energy==0|| ...
                    obj.h2o_energy==0||obj.h2o_adjustments==0
                warning("KSSOLV:Matgenlab:Compatibility:AqueousReferences", ...
                    "O2 and H2O reference energies were not fully provided.");
            end
        end
        function adjustments=get_adjustments(obj,entry)
            if isempty(obj.o2_energy)||isempty(obj.h2o_energy)|| ...
                    isempty(obj.h2o_adjustments)
                kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                    incompatible("O2 and H2O reference energies are required.");
            end
            entropyH2O=obj.cpd_entropies.H2O;
            entropyO2=obj.cpd_entropies.O2;
            obj.fit_h2_energy=round(.5*(3*(obj.h2o_energy-entropyH2O)- ...
                (obj.o2_energy-entropyO2)+2.4583),6);
            adjustments={};comp=entry.composition;formula=entry.reduced_formula;
            cls=obj.as_dict();
            if formula=="H2"
                if isempty(obj.h2_energy)
                    error("KSSOLV:Matgenlab:Compatibility:H2Reference", ...
                        "H2 energy is not set.");
                end
                adjustments{end+1}= ... %#ok<AGROW>
                    kssolv.analysis.matgenlab.core.ConstantEnergyAdjustment( ...
                    (obj.fit_h2_energy-obj.h2_energy)*comp.num_atoms, ...
                    "uncertainty",NaN,"name", ...
                    "MP Aqueous H2 / H2O referencing","cls",cls);
            end
            entropy=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.map_get(obj.cpd_entropies,formula,[]);
            if ~isempty(entropy)
                adjustments{end+1}= ... %#ok<AGROW>
                    kssolv.analysis.matgenlab.core.TemperatureEnergyAdjustment( ...
                    -entropy/298,298,comp.num_atoms, ...
                    "uncertainty_per_deg",NaN, ...
                    "name","Compound entropy at room temperature","cls",cls);
            end
            if formula~="H2O"
                [reduced,factor]=comp.get_reduced_composition_and_factor();
                waters=floor(min(reduced.amountOf("H")/2, ...
                    reduced.amountOf("O")))*factor;
                if waters>0
                    value=-(obj.h2o_adjustments*3-2.4583);
                    adjustments{end+1}= ... %#ok<AGROW>
                        kssolv.analysis.matgenlab.core.CompositionEnergyAdjustment( ...
                        value,waters,"uncertainty_per_atom",NaN, ...
                        "name","MP Aqueous hydrate","cls",cls);
                end
            end
        end
        function values=process_entries(obj,entries,varargin)
            options=struct(clean=false,verbose=false,inplace=true, ...
                n_workers=1,on_error="ignore");
            options=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.options(options,varargin);
            if ~iscell(entries),entries=num2cell(entries);end
            if ~options.inplace
                entries=cellfun(@(item)item.copy(),entries,"UniformOutput",false);
            end
            if ~isempty(obj.solid_compat)
                entries=obj.solid_compat.process_entries(entries,"clean",true, ...
                    "verbose",options.verbose,"inplace",true, ...
                    "n_workers",options.n_workers,"on_error",options.on_error);
            end
            if numel(entries)>1
                oxygen=entries(cellfun(@(item)item.reduced_formula=="O2",entries));
                if isempty(obj.o2_energy)&&~isempty(oxygen)
                    obj.o2_energy=min(cellfun(@(item)item.energy_per_atom,oxygen));
                end
                water=entries(cellfun(@(item)item.reduced_formula=="H2O",entries));
                if isempty(obj.h2o_energy)&&isempty(obj.h2o_adjustments)&&~isempty(water)
                    [~,index]=min(cellfun(@(item)item.energy_per_atom,water));
                    obj.h2o_energy=water{index}.energy_per_atom;
                    obj.h2o_adjustments=water{index}.correction/ ...
                        water{index}.composition.num_atoms;
                end
            end
            hydrogen=entries(cellfun(@(item)item.reduced_formula=="H2",entries));
            if ~isempty(hydrogen)
                obj.h2_energy=min(cellfun(@(item)item.energy_per_atom,hydrogen));
            end
            values=process_entries@kssolv.analysis.matgenlab.analysis. ...
                compatibility.Compatibility(obj,entries,"clean",options.clean, ...
                "verbose",options.verbose,"inplace",true, ...
                "n_workers",options.n_workers,"on_error",options.on_error);
        end
        function data=as_dict(obj)
            data=as_dict@kssolv.analysis.matgenlab.analysis.compatibility. ...
                Compatibility(obj);
            data.o2_energy=obj.o2_energy;data.h2o_energy=obj.h2o_energy;
            data.h2o_adjustments=obj.h2o_adjustments;
        end
    end
end
