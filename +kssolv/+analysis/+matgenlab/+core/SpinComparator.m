classdef SpinComparator < ...
        kssolv.analysis.matgenlab.core.AbstractComparator
    methods
        function tf = are_equal(~, first, second)
            [firstSpecies, ~] = first.items();
            [secondSpecies, ~] = second.items();
            for firstIndex = 1:numel(firstSpecies)
                firstItem = firstSpecies{firstIndex};
                firstSpin = firstItem.spin;
                if isnan(firstSpin), firstSpin = 0; end
                found = false;
                for secondIndex = 1:numel(secondSpecies)
                    secondItem = secondSpecies{secondIndex};
                    secondSpin = secondItem.spin;
                    if isnan(secondSpin), secondSpin = 0; end
                    firstOxidation = firstItem.oxi_state;
                    secondOxidation = secondItem.oxi_state;
                    if isnan(firstOxidation), firstOxidation = 0; end
                    if isnan(secondOxidation), secondOxidation = 0; end
                    if firstItem.symbol == secondItem.symbol && ...
                            firstOxidation == secondOxidation && ...
                            abs(secondSpin + firstSpin) <= 1e-8
                        found = true;
                        break
                    end
                end
                if ~found, tf = false; return; end
            end
            tf = true;
        end

        function value = get_hash(~, composition)
            value = composition.fractional_composition;
        end
    end
end
