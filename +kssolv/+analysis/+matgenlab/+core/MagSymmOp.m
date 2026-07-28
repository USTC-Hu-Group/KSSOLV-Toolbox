classdef MagSymmOp < kssolv.analysis.matgenlab.core.SymmOp
    %MAGSYMMOP Symmetry operation augmented by a time-reversal operator.
    %
    % Magnetic moments are axial vectors and transform as
    % det(R) * timeReversal * R*m.

    properties (SetAccess = private)
        timeReversal (1, 1) double
    end

    properties (Dependent, SetAccess = private)
        time_reversal
    end

    methods
        function obj = MagSymmOp(affineMatrix, timeReversal, tol)
            arguments
                affineMatrix (4, 4) double
                timeReversal (1, 1) double
                tol (1, 1) double {mustBeNonnegative} = 0.01
            end
            if ~ismember(timeReversal, [-1, 1])
                error("KSSOLV:Matgenlab:MagSymmOp:InvalidTimeReversal", ...
                    "Time reversal must be either -1 or +1.");
            end
            obj@kssolv.analysis.matgenlab.core.SymmOp(affineMatrix, tol);
            obj.timeReversal = timeReversal;
        end

        function value = get.time_reversal(obj)
            value = obj.timeReversal;
        end

        function tf = eq(obj, other)
            tf = isa(other, "kssolv.analysis.matgenlab.core.MagSymmOp") && ...
                eq@kssolv.analysis.matgenlab.core.SymmOp(obj, other) && ...
                obj.timeReversal == other.timeReversal;
        end

        function result = mtimes(obj, other)
            if ~isa(other, "kssolv.analysis.matgenlab.core.MagSymmOp")
                error("KSSOLV:Matgenlab:MagSymmOp:InvalidComposition", ...
                    "MagSymmOp can only be composed with another MagSymmOp.");
            end
            result = kssolv.analysis.matgenlab.core.MagSymmOp( ...
                obj.affineMatrix * other.affineMatrix, ...
                obj.timeReversal * other.timeReversal, obj.tol);
        end

        function moment = operateMagmom(obj, moment)
            arguments
                obj
                moment double
            end
            moment = obj.applyRotationOnly(moment) * ...
                det(obj.rotationMatrix) * obj.timeReversal;
        end

        function moment = operate_magmom(obj, moment)
            moment = obj.operateMagmom(moment);
        end

        function text = asXyztString(obj)
            if obj.timeReversal > 0
                suffix = "+1";
            else
                suffix = "-1";
            end
            text = obj.asXyzString() + ", " + suffix;
        end

        function text = as_xyzt_str(obj)
            text = obj.asXyztString();
        end

        function data = asDict(obj)
            data = asDict@kssolv.analysis.matgenlab.core.SymmOp(obj);
            data.x_class = "MagSymmOp";
            data.time_reversal = obj.timeReversal;
        end

        function data = as_dict(obj)
            data = obj.asDict();
        end
    end

    methods (Static)
        function obj = fromSymmOp(symmOp, timeReversal)
            arguments
                symmOp (1, 1) kssolv.analysis.matgenlab.core.SymmOp
                timeReversal (1, 1) double
            end
            obj = kssolv.analysis.matgenlab.core.MagSymmOp( ...
                symmOp.affineMatrix, timeReversal, symmOp.tol);
        end

        function obj = from_symmop(symmOp, timeReversal)
            obj = kssolv.analysis.matgenlab.core.MagSymmOp. ...
                fromSymmOp(symmOp, timeReversal);
        end

        function obj = fromRotationAndTranslationAndTimeReversal( ...
                rotationMatrix, translationVector, timeReversal, tol)
            arguments
                rotationMatrix double = eye(3)
                translationVector double = [0, 0, 0]
                timeReversal (1, 1) double = 1
                tol (1, 1) double {mustBeNonnegative} = 0.1
            end
            op = kssolv.analysis.matgenlab.core.SymmOp. ...
                fromRotationAndTranslation(rotationMatrix, translationVector, tol);
            obj = kssolv.analysis.matgenlab.core.MagSymmOp. ...
                fromSymmOp(op, timeReversal);
        end

        function obj = from_rotation_and_translation_and_time_reversal( ...
                rotationMatrix, translationVector, options)
            arguments
                rotationMatrix double = eye(3)
                translationVector double = [0, 0, 0]
                options.time_reversal (1, 1) double = 1
                options.tol (1, 1) double {mustBeNonnegative} = 0.1
            end
            obj = kssolv.analysis.matgenlab.core.MagSymmOp. ...
                fromRotationAndTranslationAndTimeReversal(rotationMatrix, ...
                translationVector, options.time_reversal, options.tol);
        end

        function obj = fromXyztString(xyztString)
            arguments
                xyztString (1, 1) string
            end
            tokens = split(xyztString, ",");
            if numel(tokens) ~= 4
                error("KSSOLV:Matgenlab:MagSymmOp:InvalidXyztString", ...
                    "XYZT string must contain four comma-separated fields.");
            end
            timeReversal = str2double(strtrim(tokens(4)));
            if ~ismember(timeReversal, [-1, 1])
                error("KSSOLV:Matgenlab:MagSymmOp:InvalidTimeReversal", ...
                    "Time reversal should be -1 or +1.");
            end
            op = kssolv.analysis.matgenlab.core.SymmOp.fromXyzString( ...
                strjoin(tokens(1:3), ","));
            obj = kssolv.analysis.matgenlab.core.MagSymmOp. ...
                fromSymmOp(op, timeReversal);
        end

        function obj = from_xyzt_str(xyztString)
            obj = kssolv.analysis.matgenlab.core.MagSymmOp. ...
                fromXyztString(string(xyztString));
        end

        function obj = fromDict(data)
            obj = kssolv.analysis.matgenlab.core.MagSymmOp( ...
                data.matrix, data.time_reversal, data.tolerance);
        end

        function obj = from_dict(data)
            obj = kssolv.analysis.matgenlab.core.MagSymmOp.fromDict(data);
        end
    end
end
