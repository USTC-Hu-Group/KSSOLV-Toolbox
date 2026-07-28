classdef MaterialsProject2020Compatibility < kssolv.analysis.matgenlab.analysis.compatibility.Compatibility
    %MATERIALSPROJECT2020COMPATIBILITY MP2020 correction and uncertainty model.
    properties
        compat_type (1,1) string = "Advanced"
        correct_peroxide (1,1) logical = true
        strict_anions (1,1) string = "require_bound"
        check_potcar (1,1) logical = true
        check_potcar_hash (1,1) logical = false
        config_file (1,1) string = ""
        name (1,1) string
        comp_correction struct = struct()
        comp_errors struct = struct()
        u_corrections struct = struct()
        u_errors struct = struct()
    end
    methods
        function obj=MaterialsProject2020Compatibility(varargin)
            options=struct(compat_type="Advanced",correct_peroxide=true, ...
                strict_anions="require_bound",check_potcar=true, ...
                check_potcar_hash=false,config_file="");
            options=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.options(options,varargin);
            if ~any(string(options.compat_type)==["GGA","Advanced"])
                kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                    incompatible("Invalid compatibility type.");
            end
            obj.compat_type=string(options.compat_type);
            obj.correct_peroxide=options.correct_peroxide;
            obj.strict_anions=string(options.strict_anions);
            obj.check_potcar=options.check_potcar;
            obj.check_potcar_hash=options.check_potcar_hash;
            obj.config_file=string(options.config_file);
            if strlength(obj.config_file)==0
                config=kssolv.analysis.matgenlab.analysis.compatibility. ...
                    internal.config_data("MP2020");
            elseif isfile(obj.config_file)
                config=kssolv.analysis.matgenlab.util.yaml_load(obj.config_file);
            else
                error("KSSOLV:Matgenlab:Compatibility:MissingConfig", ...
                    "Custom compatibility configuration does not exist.");
            end
            obj.name=string(config.Name);
            obj.comp_correction=kssolv.analysis.matgenlab.analysis. ...
                compatibility.internal.map_get(config.Corrections, ...
                "CompositionCorrections",struct());
            obj.comp_errors=kssolv.analysis.matgenlab.analysis. ...
                compatibility.internal.map_get(config.Uncertainties, ...
                "CompositionCorrections",struct());
            if obj.compat_type=="Advanced"
                obj.u_corrections=kssolv.analysis.matgenlab.analysis. ...
                    compatibility.internal.map_get(config.Corrections, ...
                    "GGAUMixingCorrections",struct());
                obj.u_errors=kssolv.analysis.matgenlab.analysis. ...
                    compatibility.internal.map_get(config.Uncertainties, ...
                    "GGAUMixingCorrections",struct());
            end
        end
        function adjustments=get_adjustments(obj,entry)
            runType=string(kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.field_or(entry.parameters,"run_type",""));
            if ~any(runType==["GGA","GGA+U"])
                kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                    incompatible("Entry has invalid run type '%s'.",runType);
            end
            software=string(kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.field_or(entry.parameters,"software","vasp"));
            if software=="vasp"
                checker=kssolv.analysis.matgenlab.analysis.compatibility. ...
                    PotcarCorrection("MP","check_potcar",obj.check_potcar, ...
                    "check_hash",obj.check_potcar_hash);
                checker.get_correction(entry);
            end
            adjustments={};comp=entry.composition;
            if isscalar(entry.elements),return,end
            symbols=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.entry_symbols(entry);
            electroneg=arrayfun(@(item) ...
                kssolv.analysis.matgenlab.core.Element(item).X,symbols);
            [~,electroIndex]=max(electroneg);mostElectro=symbols(electroIndex);
            cls=obj.as_dict();
            if comp.contains("S")
                kind="sulfide";
                if isfield(entry.data,"sulfide_type")
                    kind=string(entry.data.sulfide_type);
                elseif isa(entry,"kssolv.analysis.matgenlab.core.ComputedStructureEntry")
                    kind=kssolv.analysis.matgenlab.core.sulfide_type(entry.structure);
                end
                if any(kind==["sulfide","polysulfide"])
                    adjustments{end+1}=obj.compositionAdjustment( ... %#ok<AGROW>
                        "S",comp.amountOf("S"),"S",cls);
                end
            end
            if comp.contains("O")
                kind=obj.oxygenType(entry);
                adjustments{end+1}=obj.compositionAdjustment( ... %#ok<AGROW>
                    kind,comp.amountOf("O"),kind,cls);
            end
            if ~isfield(entry.data,"oxidation_states")
                try
                    guesses=entry.composition.oxi_state_guesses([],0,false,-20);
                catch
                    guesses={};
                end
                if isempty(guesses),entry.data.oxidation_states=struct();
                else,entry.data.oxidation_states=guesses{1};end
            end
            anions=["Br","I","Se","Si","Sb","Te","H","N","F","Cl"];
            for anion=anions
                if ~comp.contains(anion)||~isfield(obj.comp_correction,char(anion))
                    continue
                end
                oxidation=kssolv.analysis.matgenlab.analysis.compatibility. ...
                    internal.map_get(entry.data.oxidation_states,anion,0);
                apply=(oxidation<0)||(oxidation>=0&&anion==mostElectro);
                if obj.strict_anions=="require_bound"&&oxidation<0&&oxidation>-1
                    apply=false;
                elseif obj.strict_anions=="require_exact"
                    apply=obj.inFittedRange(anion,oxidation);
                end
                if apply
                    adjustments{end+1}=obj.compositionAdjustment( ...
                        anion,comp.amountOf(anion),anion,cls); %#ok<AGROW>
                end
            end
            if obj.compat_type=="Advanced"
                expected=kssolv.analysis.matgenlab.analysis.compatibility. ...
                    internal.u_values("MP",mostElectro);
            else
                expected=struct();
            end
            corrections=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.map_get(obj.u_corrections,mostElectro,struct());
            errors=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.map_get(obj.u_errors,mostElectro,struct());
            hubbards=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.field_or(entry.parameters,"hubbards",struct());
            for symbol=symbols
                actual=kssolv.analysis.matgenlab.analysis.compatibility. ...
                    internal.map_get(hubbards,symbol,0);
                wanted=kssolv.analysis.matgenlab.analysis.compatibility. ...
                    internal.map_get(expected,symbol,0);
                if abs(actual-wanted)>1e-8
                    kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                        incompatible("Invalid U value on %s.",symbol);
                end
                correction=kssolv.analysis.matgenlab.analysis.compatibility. ...
                    internal.map_get(corrections,symbol,[]);
                if ~isempty(correction)
                    uncertainty=kssolv.analysis.matgenlab.analysis. ...
                        compatibility.internal.map_get(errors,symbol,NaN);
                    adjustments{end+1}= ...
                        kssolv.analysis.matgenlab.core.CompositionEnergyAdjustment( ...
                        correction,comp.amountOf(symbol), ...
                        "uncertainty_per_atom",uncertainty, ...
                        "name",obj.name+" GGA/GGA+U mixing correction ("+ ...
                        symbol+")","cls",cls); %#ok<AGROW>
                end
            end
        end
        function data=as_dict(obj)
            data=as_dict@kssolv.analysis.matgenlab.analysis.compatibility. ...
                Compatibility(obj);
            data.compat_type=obj.compat_type;data.correct_peroxide=obj.correct_peroxide;
            data.strict_anions=obj.strict_anions;data.check_potcar=obj.check_potcar;
            data.check_potcar_hash=obj.check_potcar_hash;
            data.config_file=obj.config_file;
        end
    end
    methods (Access=protected)
        function item=compositionAdjustment(obj,key,count,label,cls)
            correction=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.map_get(obj.comp_correction,key,0);
            uncertainty=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.map_get(obj.comp_errors,key,0);
            item=kssolv.analysis.matgenlab.core.CompositionEnergyAdjustment( ...
                correction,count,"uncertainty_per_atom",uncertainty, ...
                "name",obj.name+" anion correction ("+label+")","cls",cls);
        end
        function kind=oxygenType(obj,entry)
            if ~obj.correct_peroxide,kind="oxide";return,end
            if isfield(entry.data,"oxide_type")
                kind=string(entry.data.oxide_type);
            elseif isa(entry,"kssolv.analysis.matgenlab.core.ComputedStructureEntry")
                kind=string(kssolv.analysis.matgenlab.core.oxide_type( ...
                    entry.structure,1.05,false));
            else
                formula=entry.reduced_formula;kind="oxide";
                if any(formula==["Li2O2","Na2O2","K2O2","Cs2O2","Rb2O2", ...
                        "BeO2","MgO2","CaO2","SrO2","BaO2"])
                    kind="peroxide";
                elseif any(formula==["LiO2","NaO2","KO2","RbO2","CsO2"])
                    kind="superoxide";
                elseif any(formula==["LiO3","NaO3","KO3","NaO5"])
                    kind="ozonide";
                end
            end
            if kind=="hydroxide",kind="oxide";end
        end
        function tf=inFittedRange(~,anion,value)
            ranges=struct(Br=[-1,-1],Cl=[-1,-1],F=[-1,-1],H=[-1,-1], ...
                I=[-1,-1],N=[-3,-2],Sb=[-3,-2],Se=[-2,-1], ...
                Si=[-4,-1],Te=[-2,-1]);
            range=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.map_get(ranges,anion,[]);
            tf=~isempty(range)&&value>=range(1)&&value<=range(2);
        end
    end
end
