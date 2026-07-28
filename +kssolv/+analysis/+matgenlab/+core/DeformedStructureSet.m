classdef DeformedStructureSet
    %DEFORMEDSTRUCTURESET Independently strained structure collection.

    properties (SetAccess = protected)
        undeformed_structure
        deformations cell = cell(1, 0)
        deformed_structures cell = cell(1, 0)
        sym_dict = []
    end

    methods
        function obj = DeformedStructureSet( ...
                structure, normStrains, shearStrains, symmetry)
            if nargin < 2 || isempty(normStrains)
                normStrains = [-0.01, -0.005, 0.005, 0.01];
            end
            if nargin < 3 || isempty(shearStrains)
                shearStrains = [-0.06, -0.03, 0.03, 0.06];
            end
            if nargin < 4, symmetry = false; end
            obj.undeformed_structure = structure;
            for position = [1, 1; 2, 2; 3, 3].'
                for amount = reshape(normStrains, 1, [])
                    strain = kssolv.analysis.matgenlab.core.Strain. ...
                        from_index_amount(position.', amount);
                    obj.deformations{end + 1} = ... %#ok<AGROW>
                        strain.get_deformation_matrix();
                end
            end
            for position = [1, 2; 1, 3; 2, 3].'
                for amount = reshape(shearStrains, 1, [])
                    strain = kssolv.analysis.matgenlab.core.Strain. ...
                        from_index_amount(position.', amount);
                    obj.deformations{end + 1} = ... %#ok<AGROW>
                        strain.get_deformation_matrix();
                end
            end
            if symmetry
                obj.sym_dict = ...
                    kssolv.analysis.matgenlab.core.symmetry_reduce( ...
                        obj.deformations, structure);
                obj.deformations = obj.sym_dict.keys();
            end
            obj.deformed_structures = cellfun(@(deformation) ...
                deformation.apply_to_structure(structure), ...
                obj.deformations, "UniformOutput", false);
        end

        function value = length(obj), value = numel(obj.deformed_structures); end

        function varargout = subsref(obj, reference)
            if reference(1).type == "()"
                value = obj.deformed_structures{reference(1).subs{1}};
                if numel(reference) > 1
                    value = builtin("subsref", value, reference(2:end));
                end
                varargout{1} = value;
            else
                [varargout{1:nargout}] = builtin("subsref", obj, reference);
            end
        end
    end
end
