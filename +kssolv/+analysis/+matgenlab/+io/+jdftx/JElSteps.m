classdef JElSteps
    %JELSTEPS Series of electronic minimization iterations.
    properties
        opt_type = []
        etype = []
        iter_flag = []
        converged = []
        converged_reason = []
        slices cell = {}
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
        nstep = 0
    end
    methods
        function obj = JElSteps(varargin)
            obj = kssolv.analysis.matgenlab.io.jdftx.assign_options( ...
                obj, varargin{:});
            obj = obj.refresh();
        end

        function result = as_dict(obj)
            names = properties(obj);
            result = struct();
            for idx = 1:numel(names)
                name = names{idx};
                if strcmp(name, "slices")
                    result.slices = cellfun(@(x) x.as_dict(), ...
                        obj.slices, "UniformOutput", false);
                else
                    result.(name) = obj.(name);
                end
            end
        end

        function result = to_dict(obj)
            result = obj.as_dict();
        end

        function value = get(obj, key)
            if isnumeric(key)
                value = obj.slices{key + 1};
            else
                value = obj.(char(key));
            end
        end

        function text = string(obj)
            text = string(jsonencode(obj.as_dict()));
        end

        function text = char(obj)
            text = char(string(obj));
        end
    end

    methods (Static)
        function obj = from_text_slice(text, options)
            arguments
                text
                options.opt_type = "ElecMinimize"
                options.etype = "F"
            end
            lines = string(text);
            flag = string(options.opt_type) + ": Iter:";
            groups = {};
            pending = strings(0, 1);
            for idx = 1:numel(lines)
                line = lines(idx);
                if strlength(strtrim(line)) == 0
                    continue
                end
                pending(end + 1, 1) = line; %#ok<AGROW>
                if contains(line, flag)
                    groups{end + 1} = pending; %#ok<AGROW>
                    pending = strings(0, 1);
                end
            end
            slices = cellfun(@(x) ...
                kssolv.analysis.matgenlab.io.jdftx.JElStep. ...
                from_lines_collect(x, options.opt_type, options.etype), ...
                groups, "UniformOutput", false);
            converged = any(contains(lines, ...
                string(options.opt_type) + ": Converged"));
            reason = [];
            hit = find(contains(lines, ...
                string(options.opt_type) + ": Converged"), 1, "last");
            if ~isempty(hit)
                token = regexp(lines(hit), "\((.*?)\)", "tokens", "once");
                if ~isempty(token)
                    reason = string(token{1});
                end
            end
            obj = kssolv.analysis.matgenlab.io.jdftx.JElSteps( ...
                "opt_type", string(options.opt_type), ...
                "etype", string(options.etype), ...
                "iter_flag", flag, "slices", slices, ...
                "converged", converged, "converged_reason", reason);
        end

        function obj = from_nothing(options)
            arguments
                options.opt_type = "ElecMinimize"
                options.etype = "F"
            end
            obj = kssolv.analysis.matgenlab.io.jdftx.JElSteps( ...
                "opt_type", options.opt_type, "etype", options.etype, ...
                "slices", {}, "converged", false);
        end
    end

    methods (Access = private)
        function obj = refresh(obj)
            if isempty(obj.slices)
                obj.nstep = 0;
                return
            end
            last = obj.slices{end};
            names = ["e", "grad_k", "alpha", "linmin", "t_s", "mu", ...
                "nelectrons", "abs_magneticmoment", ...
                "tot_magneticmoment", "subspacerotationadjust"];
            for name = names
                for idx = numel(obj.slices):-1:1
                    candidate = obj.slices{idx}.(name);
                    if ~isempty(candidate)
                        obj.(name) = candidate;
                        break
                    end
                end
            end
            if isempty(last.nstep)
                obj.nstep = numel(obj.slices) - 1;
            else
                obj.nstep = last.nstep;
            end
        end
    end
end
