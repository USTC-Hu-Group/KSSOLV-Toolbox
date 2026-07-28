classdef AqueousCorrection < kssolv.analysis.matgenlab.analysis.compatibility.Correction
    %AQUEOUSCORRECTION Legacy MIT aqueous compound correction.
    properties
        name (1,1) string
        cpd_energies struct
        comp_correction struct = struct()
        oxide_correction struct = struct()
        cpd_errors struct = struct()
    end
    methods
        function obj=AqueousCorrection(configFile,varargin)
            options=struct(error_file="");
            options=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.options(options,varargin);
            config=kssolv.analysis.matgenlab.util.yaml_load(configFile);
            obj.name=string(config.Name);obj.cpd_energies=config.AqueousCompoundEnergies;
            obj.comp_correction=kssolv.analysis.matgenlab.analysis. ...
                compatibility.internal.field_or(config,"CompositionCorrections",struct());
            obj.oxide_correction=kssolv.analysis.matgenlab.analysis. ...
                compatibility.internal.field_or(config,"OxideCorrections",struct());
            if strlength(string(options.error_file))>0
                errors=kssolv.analysis.matgenlab.util.yaml_load(options.error_file);
                obj.cpd_errors=kssolv.analysis.matgenlab.analysis. ...
                    compatibility.internal.field_or(errors,"AqueousCompoundEnergies",struct());
            end
        end
        function value=get_correction(obj,entry)
            comp=entry.composition;formula=entry.reduced_formula;value=0;
            target=kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                map_get(obj.cpd_energies,formula,[]);
            if ~isempty(target)
                if any(formula==["H2","H2O"]) %#ok<ALIGN>
                    value=value+target*comp.num_atoms-entry.uncorrected_energy-entry.correction;
                else,value=value+target*comp.num_atoms;end
            end
            if formula=="H2O",return,end
            waters=floor(min(comp.amountOf("H")/2,comp.amountOf("O")));
            if waters<=0,return,end
            hCorr=kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                map_get(obj.comp_correction,"H",0);
            oCorr=kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                map_get(obj.comp_correction,"oxide",0)+ ...
                kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                map_get(obj.oxide_correction,"oxide",0);
            value=value-(comp.amountOf("H")-waters/2)*hCorr;
            value=value-(comp.amountOf("O")-waters)*oCorr+2.4583*waters;
        end
        function value=get_uncertainty(obj,entry)
            errorPerAtom=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.map_get(obj.cpd_errors,entry.reduced_formula,0);
            value=abs(errorPerAtom*entry.composition.num_atoms);
        end
    end
end
