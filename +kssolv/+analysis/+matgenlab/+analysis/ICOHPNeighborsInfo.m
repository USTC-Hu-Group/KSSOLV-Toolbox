classdef ICOHPNeighborsInfo
    %ICOHPNEIGHBORSINFO Immutable record of selected LOBSTER interactions.
    properties (SetAccess = private)
        total_icohp (1,1) double = 0
        list_icohps (1,:) double = []
        n_bonds (1,1) double = 0
        labels (1,:) string = strings(1, 0)
        atoms cell = {}
        central_isites = []
    end

    methods
        function obj = ICOHPNeighborsInfo(totalIcohp, listIcohps, ...
                nBonds, labels, atoms, centralIsites)
            if nargin == 0, return; end
            obj.total_icohp = double(totalIcohp);
            obj.list_icohps = reshape(double(listIcohps), 1, []);
            obj.n_bonds = double(nBonds);
            obj.labels = reshape(string(labels), 1, []);
            obj.atoms = atoms;
            obj.central_isites = centralIsites;
        end

        function value = cell(obj)
            value = {obj.total_icohp, obj.list_icohps, obj.n_bonds, ...
                obj.labels, obj.atoms, obj.central_isites};
        end

        function value = length(~), value = 6; end
        function value = numel(~, varargin)
            value = 1;
        end

        function varargout = subsref(obj, reference)
            if strcmp(reference(1).type, "()")
                indices = reference(1).subs{1};
                values = cell(obj);
                value = values(indices);
                if isscalar(indices), value = value{1}; end
                if numel(reference) > 1
                    value = builtin("subsref", value, reference(2:end));
                end
                varargout{1} = value;
                return
            end
            [varargout{1:nargout}] = builtin("subsref", obj, reference);
        end
    end
end
