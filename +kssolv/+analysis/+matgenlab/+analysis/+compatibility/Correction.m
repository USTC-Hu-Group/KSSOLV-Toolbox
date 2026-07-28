classdef Correction < handle
    %CORRECTION Base class for legacy scalar entry corrections.
    methods
        function value=get_correction(~,~)
            value=[]; %#ok<NASGU>
            error("KSSOLV:Matgenlab:Compatibility:Abstract", ...
                "Subclasses must implement get_correction.");
        end
        function value=get_uncertainty(~,~)
            % Legacy correction schemes without an error table report NaN.
            value=NaN;
        end
        function entry=correct_entry(obj,entry)
            value=obj.get_correction(entry);
            uncertainty=obj.get_uncertainty(entry);
            oldUncertainty=entry.correction_uncertainty;
            if ~isfinite(oldUncertainty),oldUncertainty=0;end
            if ~isfinite(uncertainty),uncertainty=0;end
            totalUncertainty=hypot(oldUncertainty,uncertainty);
            if totalUncertainty==0,totalUncertainty=NaN;end
            % This intentionally appends the updated total correction. It is
            % the historical pymatgen Correction.correct_entry contract.
            entry.energy_adjustments{end+1}= ...
                kssolv.analysis.matgenlab.core.ConstantEnergyAdjustment( ...
                entry.correction+value,"uncertainty",totalUncertainty);
        end
    end
end
