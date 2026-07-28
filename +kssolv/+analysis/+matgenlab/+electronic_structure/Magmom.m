classdef Magmom < kssolv.analysis.matgenlab.util.MSONable
    %MAGMOM Magnetic moment and spin-axis representation.

    properties (SetAccess = immutable)
        moment (1,3) double
        saxis (1,3) double
    end

    properties (Dependent, SetAccess = private)
        global_moment
        projection
    end

    methods
        function obj = Magmom(moment, saxis)
            arguments
                moment
                saxis (1,3) double = [0, 0, 1]
            end
            if isa(moment, ...
                    "kssolv.analysis.matgenlab.electronic_structure.Magmom")
                obj.moment = moment.moment;
                obj.saxis = moment.saxis;
                return
            end
            value = double(moment);
            if isscalar(value)
                value = [0, 0, value];
            end
            if ~isvector(value) || numel(value) ~= 3 || ...
                    any(~isfinite(value))
                error("KSSOLV:Matgenlab:Magmom:InvalidMoment", ...
                    "moment must be a finite scalar or three-vector.");
            end
            axisNorm = norm(saxis);
            if axisNorm == 0 || any(~isfinite(saxis))
                error("KSSOLV:Matgenlab:Magmom:InvalidSaxis", ...
                    "saxis must be a finite, nonzero three-vector.");
            end
            obj.moment = reshape(value, 1, 3);
            obj.saxis = reshape(saxis / axisNorm, 1, 3);
        end

        function value = get.global_moment(obj)
            value = obj.get_moment();
        end

        function value = get.projection(obj)
            value = dot(obj.moment, obj.saxis);
        end

        function value = get_moment(obj, saxis)
            arguments
                obj
                saxis (1,3) double = [0, 0, 1]
            end
            inverse = ...
                kssolv.analysis.matgenlab.electronic_structure.Magmom. ...
                transformationInverse(obj.saxis);
            forward = ...
                kssolv.analysis.matgenlab.electronic_structure.Magmom. ...
                transformation(saxis);
            value = obj.moment * inverse * forward;
            value(abs(value) < 1e-8) = 0;
        end

        function value = get_xyz_magmom_with_001_saxis(obj)
            value = kssolv.analysis.matgenlab.electronic_structure. ...
                Magmom(obj.get_moment());
        end

        function value = get_00t_magmom_with_xyz_saxis(obj)
            total = abs(obj);
            if total == 0
                value = kssolv.analysis.matgenlab.electronic_structure. ...
                    Magmom(obj);
                return
            end
            newAxis = obj.moment / norm(obj.moment);
            if dot([1.01, 1.02, 1.03], newAxis) < 0
                total = -total;
                newAxis = -newAxis;
            end
            value = kssolv.analysis.matgenlab.electronic_structure. ...
                Magmom([0, 0, total], newAxis);
        end

        function value = get_moment_relative_to_crystal_axes(obj, lattice)
            unitMatrix = lattice.matrix ./ vecnorm(lattice.matrix, 2, 2);
            value = obj.global_moment / unitMatrix;
            value(abs(value) < 1e-8) = 0;
        end

        function value = abs(obj)
            value = norm(obj.moment);
        end

        function value = double(obj)
            converted = obj.get_00t_magmom_with_xyz_saxis();
            value = converted.moment(3);
        end

        function value = uminus(obj)
            value = kssolv.analysis.matgenlab.electronic_structure. ...
                Magmom(-obj.moment, obj.saxis);
        end

        function value = eq(obj, other)
            try
                other = kssolv.analysis.matgenlab.electronic_structure. ...
                    Magmom(other);
                value = all(abs(obj.global_moment - other.global_moment) ...
                    <= 1e-8);
            catch
                value = false;
            end
        end

        function value = ne(obj, other)
            value = ~eq(obj, other);
        end

        function value = lt(obj, other)
            value = abs(obj) < abs(other);
        end

        function value = char(obj)
            value = char(string(double(obj)));
        end

        function value = string(obj)
            value = string(double(obj));
        end

        function varargout = subsref(obj, index)
            if index(1).type == "()"
                indices = index(1).subs;
                value = obj.moment(indices{:});
                if numel(index) > 1
                    value = builtin("subsref", value, index(2:end));
                end
                varargout{1} = value;
            else
                [varargout{1:nargout}] = builtin("subsref", obj, index);
            end
        end

        function value = as_dict(obj)
            value = struct( ...
                "x_module", "pymatgen.electronic_structure.core", ...
                "x_class", "Magmom", ...
                "x_version", [], ...
                "moment", obj.moment, ...
                "saxis", obj.saxis);
        end

        function value = asDict(obj)
            value = obj.as_dict();
        end
    end

    methods (Static)
        function obj = from_global_moment_and_saxis(globalMoment, saxis)
            base = kssolv.analysis.matgenlab.electronic_structure. ...
                Magmom(globalMoment);
            obj = kssolv.analysis.matgenlab.electronic_structure. ...
                Magmom(base.get_moment(saxis), saxis);
        end

        function value = have_consistent_saxis(magmoms)
            objects = ...
                kssolv.analysis.matgenlab.electronic_structure.Magmom. ...
                normalizeSequence(magmoms);
            if isempty(objects)
                value = true;
                return
            end
            reference = objects{1}.saxis;
            value = all(cellfun(@(item) ...
                isequal(item.saxis, reference), objects));
        end

        function [moments, saxis] = ...
                get_consistent_set_and_saxis(magmoms, saxis)
            if nargin < 2 || isempty(saxis)
                saxis = ...
                    kssolv.analysis.matgenlab.electronic_structure. ...
                    Magmom.get_suggested_saxis(magmoms);
            else
                saxis = reshape(double(saxis), 1, 3);
                saxis = saxis / norm(saxis);
            end
            objects = ...
                kssolv.analysis.matgenlab.electronic_structure.Magmom. ...
                normalizeSequence(magmoms);
            moments = zeros(numel(objects), 3);
            for index = 1:numel(objects)
                moments(index, :) = objects{index}.get_moment(saxis);
            end
        end

        function saxis = get_suggested_saxis(magmoms)
            objects = ...
                kssolv.analysis.matgenlab.electronic_structure.Magmom. ...
                normalizeSequence(magmoms);
            magnitudes = cellfun(@abs, objects);
            if isempty(magnitudes) || ~any(magnitudes)
                saxis = [0, 0, 1];
                return
            end
            [~, index] = max(magnitudes);
            converted = objects{index}.get_00t_magmom_with_xyz_saxis();
            saxis = converted.saxis;
        end

        function value = are_collinear(magmoms)
            [moments, ~] = ...
                kssolv.analysis.matgenlab.electronic_structure.Magmom. ...
                get_consistent_set_and_saxis(magmoms);
            moments = moments(any(moments ~= 0, 2), :);
            if isempty(moments)
                value = true;
                return
            end
            products = cross(repmat(moments(1, :), size(moments, 1), 1), ...
                moments, 2);
            value = nnz(vecnorm(products, 2, 2)) == 0;
        end

        function obj = from_moment_relative_to_crystal_axes(moment, lattice)
            unitMatrix = lattice.matrix ./ vecnorm(lattice.matrix, 2, 2);
            value = reshape(double(moment), 1, 3) * unitMatrix;
            value(abs(value) < 1e-8) = 0;
            obj = kssolv.analysis.matgenlab.electronic_structure. ...
                Magmom(value);
        end

        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.electronic_structure. ...
                Magmom(value.moment, value.saxis);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.electronic_structure. ...
                Magmom.from_dict(value);
        end
    end

    methods (Static, Access = private)
        function matrix = transformation(saxis)
            saxis = reshape(double(saxis), 1, 3);
            saxis = saxis / norm(saxis);
            alpha = atan2(saxis(2), saxis(1));
            beta = atan2(hypot(saxis(1), saxis(2)), saxis(3));
            ca = cos(alpha); cb = cos(beta);
            sa = sin(alpha); sb = sin(beta);
            matrix = [cb*ca, -sa, sb*ca; ...
                cb*sa, ca, sb*sa; -sb, 0, cb];
        end

        function matrix = transformationInverse(saxis)
            saxis = reshape(double(saxis), 1, 3);
            saxis = saxis / norm(saxis);
            alpha = atan2(saxis(2), saxis(1));
            beta = atan2(hypot(saxis(1), saxis(2)), saxis(3));
            ca = cos(alpha); cb = cos(beta);
            sa = sin(alpha); sb = sin(beta);
            matrix = [cb*ca, cb*sa, -sb; ...
                -sa, ca, 0; sb*ca, sb*sa, cb];
        end

        function objects = normalizeSequence(values)
            if isa(values, ...
                    "kssolv.analysis.matgenlab.electronic_structure.Magmom")
                objects = arrayfun(@(item) {item}, values);
            elseif iscell(values)
                objects = cellfun(@(item) ...
                    kssolv.analysis.matgenlab.electronic_structure. ...
                    Magmom(item), values, UniformOutput=false);
            elseif isnumeric(values)
                if isscalar(values) || isvector(values) && numel(values) == 3
                    objects = {kssolv.analysis.matgenlab. ...
                        electronic_structure.Magmom(values)};
                elseif isvector(values)
                    objects = arrayfun(@(item) ...
                        {kssolv.analysis.matgenlab.electronic_structure. ...
                        Magmom(item)}, values);
                elseif size(values, 2) == 3
                    objects = arrayfun(@(index) ...
                        {kssolv.analysis.matgenlab.electronic_structure. ...
                        Magmom(values(index, :))}, 1:size(values, 1));
                else
                    error("KSSOLV:Matgenlab:Magmom:InvalidSequence", ...
                        "Magmom sequences must contain scalars or 3-vectors.");
                end
            else
                error("KSSOLV:Matgenlab:Magmom:InvalidSequence", ...
                    "Unsupported magnetic moment sequence.");
            end
            objects = reshape(objects, 1, []);
        end
    end
end
