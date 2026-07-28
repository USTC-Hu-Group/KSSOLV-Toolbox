classdef BandstructureLoader < ...
        kssolv.analysis.matgenlab.electronic_structure.VasprunBSLoader
    %BANDSTRUCTURELOADER Compatibility loader for BandStructure objects.

    methods
        function obj = BandstructureLoader(bs, structure, nelect, mommat, magmom)
            if nargin < 2, structure = []; end
            if nargin < 3, nelect = []; end
            obj@kssolv.analysis.matgenlab.electronic_structure. ...
                VasprunBSLoader(bs, structure, nelect);
            if nargin >= 4, obj.mommat_all = mommat; obj.mommat = mommat; end
            if nargin >= 5, obj.magmom = magmom; end
        end

        function set_upper_lower_bands(obj, lowerEnergy, upperEnergy)
            columns = size(obj.ebands, 2);
            obj.ebands = [repmat(lowerEnergy, 1, columns); ...
                obj.ebands; repmat(upperEnergy, 1, columns)];
            names = fieldnames(obj.proj);
            for index = 1:numel(names)
                name = names{index};
                values = obj.proj.(name);
                obj.proj.(name) = cat(2, values(:, 1, :, :), ...
                    values, values(:, end, :, :));
            end
        end
    end
end
