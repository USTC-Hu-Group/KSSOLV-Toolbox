classdef AnionCorrection < kssolv.analysis.matgenlab.analysis.compatibility.Correction
    %ANIONCORRECTION Legacy oxide and sulfide composition correction.
    properties
        name (1,1) string
        oxide_correction struct
        sulfide_correction struct = struct()
        correct_peroxide (1,1) logical = true
    end
    methods
        function obj=AnionCorrection(configFile,varargin)
            options=struct(correct_peroxide=true);
            options=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.options(options,varargin);
            config=kssolv.analysis.matgenlab.util.yaml_load(configFile);
            obj.name=string(config.Name);obj.oxide_correction=config.OxideCorrections;
            obj.sulfide_correction=kssolv.analysis.matgenlab.analysis. ...
                compatibility.internal.field_or(config,"SulfideCorrections",struct());
            obj.correct_peroxide=options.correct_peroxide;
        end
        function value=get_correction(obj,entry)
            value=0;comp=entry.composition;
            if isscalar(entry.elements),return,end
            if comp.contains("S")
                kind="sulfide";
                if isfield(entry.data,"sulfide_type")
                    kind=string(entry.data.sulfide_type);
                elseif isa(entry,"kssolv.analysis.matgenlab.core.ComputedStructureEntry")
                    kind=kssolv.analysis.matgenlab.core.sulfide_type(entry.structure);
                end
                if kind=="polysulfide",kind="sulfide";end
                correction=kssolv.analysis.matgenlab.analysis.compatibility. ...
                    internal.map_get(obj.sulfide_correction,kind,[]);
                if ~isempty(correction),value=value+correction*comp.amountOf("S");end
            end
            if ~comp.contains("O"),return,end
            kind="oxide";count=comp.amountOf("O");
            if obj.correct_peroxide
                if isfield(entry.data,"oxide_type")
                    kind=string(entry.data.oxide_type);
                    if kind=="hydroxide",kind="oxide";end
                elseif isa(entry,"kssolv.analysis.matgenlab.core.ComputedStructureEntry")
                    result=kssolv.analysis.matgenlab.core.oxide_type( ...
                        entry.structure,1.05,true);
                    kind=string(result{1});count=double(result{2});
                    if kind=="hydroxide",kind="oxide";count=comp.amountOf("O");end
                else
                    formula=entry.reduced_formula;
                    if any(formula==["Li2O2","Na2O2","K2O2","Cs2O2","Rb2O2", ...
                            "BeO2","MgO2","CaO2","SrO2","BaO2"])
                        kind="peroxide";
                    elseif any(formula==["LiO2","NaO2","KO2","RbO2","CsO2"])
                        kind="superoxide";
                    elseif any(formula==["LiO3","NaO3","KO3","NaO5"])
                        kind="ozonide";
                    end
                end
            end
            correction=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.map_get(obj.oxide_correction,kind,[]);
            if ~isempty(correction),value=value+correction*count;end
        end
    end
end
