classdef RLSVolumePredictor
    %RLSVOLUMEPREDICTOR Reference-lattice volume scaling.

    properties (SetAccess = protected)
        check_isostructural (1,1) logical = true
        radii_type (1,1) string = "ionic-atomic"
        use_bv (1,1) logical = true
    end

    methods
        function obj = RLSVolumePredictor(checkIsostructural, radiiType, useBv)
            if nargin >= 1 && ~isempty(checkIsostructural)
                obj.check_isostructural = logical(checkIsostructural);
            end
            if nargin >= 2 && ~isempty(radiiType)
                obj.radii_type = string(radiiType);
            end
            if nargin >= 3 && ~isempty(useBv), obj.use_bv = logical(useBv); end
        end

        function volume = predict(obj, structure, reference)
            if obj.check_isostructural && ~obj.isAnonymousMatch(structure, reference)
                error("KSSOLV:Matgenlab:RLSVolumePredictor:NotIsostructural", ...
                    "Input structures do not match.");
            end

            if contains(obj.radii_type, "ionic")
                [ok, numerator] = obj.radiusSum(structure, "ionic");
                [refOk, denominator] = obj.radiusSum(reference, "ionic");
                if ok && refOk
                    volume = reference.volume * (numerator / denominator)^3;
                    return
                end
                if obj.radii_type == "ionic"
                    error("KSSOLV:Matgenlab:RLSVolumePredictor:MissingIonicRadius", ...
                        "Not all the ionic radii are available.");
                end
            end

            if contains(obj.radii_type, "atomic")
                [ok, numerator] = obj.radiusSum(structure, "atomic");
                [refOk, denominator] = obj.radiusSum(reference, "atomic");
                if ~ok || ~refOk
                    error("KSSOLV:Matgenlab:RLSVolumePredictor:MissingAtomicRadius", ...
                        "Not all the atomic radii are available.");
                end
                volume = reference.volume * (numerator / denominator)^3;
                return
            end
            error("KSSOLV:Matgenlab:RLSVolumePredictor:InvalidRadiiType", ...
                "Cannot find volume scaling based on radii choices specified.");
        end

        function structure = get_predicted_structure(obj, structure, reference)
            structure = structure.copy();
            structure = structure.scale_lattice(obj.predict(structure, reference));
        end
    end

    methods (Access = protected)
        function [valid, total] = radiusSum(~, structure, kind)
            composition = structure.composition;
            [species, amounts] = composition.items();
            total = 0;
            valid = true;
            for index = 1:numel(species)
                if kind == "ionic"
                    if ~isa(species{index}, ...
                            "kssolv.analysis.matgenlab.core.Species")
                        valid = false; return
                    end
                    radius = species{index}.ionic_radius;
                else
                    radius = species{index}.atomic_radius;
                end
                if isempty(radius) || isnan(radius)
                    valid = false; return
                end
                total = total + radius * amounts(index)^(1/3);
            end
        end

        function match = isAnonymousMatch(~, left, right)
            if left.num_sites ~= right.num_sites
                match = false; return
            end
            [~, leftAmounts] = left.composition.items();
            [~, rightAmounts] = right.composition.items();
            leftPattern = sort(leftAmounts / min(leftAmounts));
            rightPattern = sort(rightAmounts / min(rightAmounts));
            match = numel(leftPattern) == numel(rightPattern) && ...
                all(abs(leftPattern - rightPattern) < 1e-8);
        end
    end
end
