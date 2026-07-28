classdef KabschMatcher < kssolv.analysis.matgenlab.util.MSONable
    %KABSCHMATCHER Rigid alignment for molecules with identical atom order.

    properties (SetAccess = protected)
        target
    end

    methods
        function obj = KabschMatcher(target)
            if ~isa(target, "kssolv.analysis.matgenlab.core.IMolecule")
                error("KSSOLV:Matgenlab:KabschMatcher:Target", ...
                    "target must be a Molecule.");
            end
            obj.target = target;
        end

        function [rotation, translation, rmsd] = match(obj, molecule)
            if ~isequal(obj.target.atomic_numbers, molecule.atomic_numbers)
                error("KSSOLV:Matgenlab:KabschMatcher:SpeciesOrder", ...
                    "The order of the species are not matching. " + ...
                    "Use BruteForceOrderMatcher for arbitrary ordering.");
            end
            source = molecule.cart_coords;
            destination = obj.target.cart_coords;
            sourceCenter = mean(source, 1);
            destinationCenter = mean(destination, 1);
            centeredSource = source - sourceCenter;
            centeredDestination = destination - destinationCenter;
            rotation = kssolv.analysis.matgenlab.core.KabschMatcher. ...
                kabsch(centeredSource, centeredDestination);
            difference = centeredSource * rotation - centeredDestination;
            rmsd = sqrt(mean(sum(difference.^2, 2)));
            translation = destinationCenter - sourceCenter * rotation;
        end

        function [molecule, rmsd] = fit(obj, source)
            [rotation, translation, rmsd] = obj.match(source);
            coordinates = source.cart_coords * rotation + translation;
            molecule = kssolv.analysis.matgenlab.core.KabschMatcher. ...
                moleculeFrom(source, 1:source.num_sites, coordinates);
        end

        function value = asDict(obj)
            pieces = split(string(class(obj)), ".");
            value = struct("x_module", ...
                "pymatgen.core.molecule_matcher", ...
                "x_class", pieces(end), "target", obj.target.as_dict());
        end

        function value = as_dict(obj), value = obj.asDict(); end
    end

    methods (Static)
        function rotation = kabsch(source, destination)
            covariance = double(source).' * double(destination);
            [left, ~, right] = svd(covariance);
            handedness = det(left * right.');
            rotation = left * diag([1, 1, handedness]) * right.';
        end

        function obj = from_dict(value)
            target = kssolv.analysis.matgenlab.core.Molecule. ...
                from_dict(value.target);
            name = string(value.x_class);
            switch name
                case "KabschMatcher"
                    obj = kssolv.analysis.matgenlab.core.KabschMatcher(target);
                case "BruteForceOrderMatcher"
                    obj = kssolv.analysis.matgenlab.core. ...
                        BruteForceOrderMatcher(target);
                case "HungarianOrderMatcher"
                    obj = kssolv.analysis.matgenlab.core. ...
                        HungarianOrderMatcher(target);
                case "GeneticOrderMatcher"
                    obj = kssolv.analysis.matgenlab.core. ...
                        GeneticOrderMatcher(target, value.threshold);
                otherwise
                    error("KSSOLV:Matgenlab:KabschMatcher:Dictionary", ...
                        "Unknown matcher class '%s'.", name);
            end
        end
    end

    methods (Static, Access = protected)
        function molecule = moleculeFrom(source, indices, coordinates)
            species = source.species_and_occu(indices);
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                species, coordinates, charge = source.charge, ...
                spin_multiplicity = source.spin_multiplicity, ...
                charge_spin_check = false);
        end
    end
end
