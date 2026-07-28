classdef LammpsSettings < dynamicprops
    %#ok<*ISCL>
    properties
        validate_params (1,1) logical = false
    end
    methods
        function obj=LammpsSettings(varargin)
            args=varargin;
            if ~isempty(args)&&islogical(args{1}), obj.validate_params=args{1}; args=args(2:end); end
            if numel(args)==1&&isstruct(args{1})
                d=args{1};
            else
                d=struct();
                for k=1:2:numel(args), d.(char(args{k}))=args{k+1}; end
            end
            if isfield(d,'validate_params'), obj.validate_params=d.validate_params; d=rmfield(d,'validate_params'); end
            obj.update(d); obj.validate();
        end
        function update(obj,updates)
            names=fieldnames(updates);
            for k=1:numel(names)
                if ~isprop(obj,names{k}), addprop(obj,names{k}); end
                obj.(names{k})=updates.(names{k});
            end
            obj.validate();
        end
        function d=as_dict(obj)
            names=properties(obj); d=struct();
            for k=1:numel(names), d.(names{k})=obj.(names{k}); end
        end
    end
    methods (Static)
        function obj=from_dict(d), obj=kssolv.analysis.matgenlab.io.lammps.LammpsSettings(d); end
    end
    methods (Access=private)
        function validate(obj)
            if isprop(obj,'restart')&&~isempty(obj.restart)&&~ischar(obj.restart)&&~isstring(obj.restart)
                error("KSSOLV:Matgenlab:LammpsSettings:Restart","restart should be the path to the restart file.");
            end
            if ~obj.validate_params, return; end
            allowed=struct('units',{{'metal','lj','real','si','cgs','electron','micro','nano'}}, ...
                'atom_style',{{'atomic','angle','body','bond','charge','electron','full','molecular'}}, ...
                'boundary',{{'p','f','s','m','fs','fm'}}, ...
                'ensemble',{{'nve','nvt','npt','nph','minimize'}}, ...
                'thermostat',{{'nose-hoover','langevin'}}, ...
                'barostat',{{'nose-hoover','berendsen','langevin'}}, ...
                'min_style',{{'cg','sd','fire','hftn','quickmin','spin','spin/cg','spin/lbfgs'}});
            names=fieldnames(allowed);
            for k=1:numel(names)
                key=names{k}; if ~isprop(obj,key)||isempty(obj.(key)), continue; end
                vals=string(obj.(key));
                if any(~ismember(vals,string(allowed.(key))))
                    error("KSSOLV:Matgenlab:LammpsSettings:Validation", ...
                        "Error validating key %s: set to an unsupported value.",key);
                end
            end
            if isprop(obj,'start_pressure')&&numel(obj.start_pressure)>1&&numel(obj.start_pressure)~=3
                error("KSSOLV:Matgenlab:LammpsSettings:Pressure","start_pressure should be a list of 3 values.");
            end
            if isprop(obj,'end_pressure')&&numel(obj.end_pressure)>1&&numel(obj.end_pressure)~=3
                error("KSSOLV:Matgenlab:LammpsSettings:Pressure","end_pressure should be a list of 3 values.");
            end
            if isprop(obj,'ensemble')&&string(obj.ensemble)=="minimize"
                if isprop(obj,'nsteps')&&obj.nsteps<1, error("KSSOLV:Matgenlab:LammpsSettings:Steps","nsteps should be greater than 0."); end
                if isprop(obj,'tol')&&obj.tol>1e-4, warning("KSSOLV:Matgenlab:LammpsSettings:Tolerance","Tolerance for minimization is larger than 1e-4."); end
            elseif isprop(obj,'friction')&&isprop(obj,'timestep')&&obj.friction<obj.timestep
                warning("KSSOLV:Matgenlab:LammpsSettings:Friction","Friction is smaller than the timestep.");
            end
        end
    end
end
