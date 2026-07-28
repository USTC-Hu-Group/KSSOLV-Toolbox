classdef JElStep
    %JELSTEP Electronic minimization data for one logged SCF iteration.
    properties
        opt_type = []
        etype = []
        nstep = []
        e = []
        grad_k = []
        alpha = []
        linmin = []
        t_s = []
        mu = []
        nelectrons = []
        abs_magneticmoment = []
        tot_magneticmoment = []
        subspacerotationadjust = []
        converged (1, 1) logical = false
        converged_reason = []
    end
    methods
        function obj = JElStep(varargin)
            obj = kssolv.analysis.matgenlab.io.jdftx.assign_options( ...
                obj, varargin{:});
        end

        function result = as_dict(obj)
            names = properties(obj);
            result = struct();
            for idx = 1:numel(names)
                result.(names{idx}) = obj.(names{idx});
            end
        end

        function result = to_dict(obj)
            result = obj.as_dict();
        end

        function text = string(obj)
            text = string(jsonencode(obj.as_dict()));
        end

        function text = char(obj)
            text = char(string(obj));
        end
    end

    methods (Static)
        function obj = from_lines_collect(lines, opt_type, etype)
            arguments
                lines
                opt_type = "ElecMinimize"
                etype = "F"
            end
            obj = kssolv.analysis.matgenlab.io.jdftx.JElStep( ...
                "opt_type", string(opt_type), "etype", string(etype));
            lines = string(lines);
            ha_to_ev = 27.21138624598059;
            for idx = 1:numel(lines)
                line = lines(idx);
                if contains(line, string(opt_type) + ": Iter:")
                    obj.nstep = read_colon(line, "Iter:");
                    value = read_colon(line, string(etype) + ":");
                    if ~isempty(value)
                        obj.e = value * ha_to_ev;
                    end
                    obj.grad_k = read_colon(line, "|grad|_K:");
                    obj.alpha = read_colon(line, "alpha:");
                    obj.linmin = read_colon(line, "linmin:");
                    obj.t_s = read_colon(line, "t[s]:");
                elseif contains(line, "FillingsUpdate:")
                    value = read_colon(line, "mu:");
                    if ~isempty(value)
                        obj.mu = value * ha_to_ev;
                    end
                    obj.nelectrons = read_colon(line, "nElectrons:");
                    obj.abs_magneticmoment = read_colon(line, "Abs:");
                    obj.tot_magneticmoment = read_colon(line, "Tot:");
                elseif contains(line, "SubspaceRotationAdjust")
                    token = regexp(line, ...
                        "SubspaceRotationAdjust:\s*set factor to\s*(\S+)", ...
                        "tokens", "once");
                    if ~isempty(token)
                        obj.subspacerotationadjust = str2double(token{1});
                    end
                elseif contains(line, string(opt_type) + ": Converged")
                    obj.converged = true;
                    token = regexp(line, "\((.*?)\)", "tokens", "once");
                    if ~isempty(token)
                        obj.converged_reason = string(token{1});
                    end
                end
            end
        end

    end
end

function value = read_colon(line, key)
value = kssolv.analysis.matgenlab.io.jdftx.get_colon_val(line, key);
end
