classdef GasCorrection < kssolv.analysis.matgenlab.analysis.compatibility.Correction
    %GASCORRECTION Legacy fitted molecular-reference correction.
    properties
        name (1,1) string
        cpd_energies struct
    end
    methods
        function obj=GasCorrection(configFile)
            config=kssolv.analysis.matgenlab.util.yaml_load(configFile);
            obj.name=string(config.Name);
            obj.cpd_energies=config.Advanced.CompoundEnergies;
        end
        function value=get_correction(obj,entry)
            target=kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                map_get(obj.cpd_energies,entry.reduced_formula,[]);
            if isempty(target),value=0;
            else,value=target*entry.composition.num_atoms-entry.uncorrected_energy;end
        end
    end
end
