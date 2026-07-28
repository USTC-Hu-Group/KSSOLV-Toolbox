classdef BaseLammpsSetGenerator < handle
    %#ok<*ALIGN>
    properties
        inputfile=[]; settings; force_field=[]; data_type="periodic"
        calc_type="lammps"; include_defaults=true; validate_params=true
        keep_stages=true; override_updates=false
    end
    methods
        function obj=BaseLammpsSetGenerator(options)
            arguments
                options.inputfile=[]
                options.settings=struct()
                options.force_field=[]
                options.data_type="periodic"
                options.calc_type="lammps"
                options.include_defaults=true
                options.validate_params=true
                options.keep_stages=true
                options.override_updates=false
            end
            names=fieldnames(options); for k=1:numel(names), obj.(names{k})=options.(names{k}); end
            if isa(options.settings,'kssolv.analysis.matgenlab.io.lammps.LammpsSettings')
                obj.settings=options.settings;
            else
                d=options.settings;
                if options.include_defaults, d=obj.merge(obj.defaults(options.data_type),d); end
                d.validate_params=options.validate_params;
                obj.settings=kssolv.analysis.matgenlab.io.lammps.LammpsSettings(d);
            end
            if isstruct(options.force_field)&&~isempty(fieldnames(options.force_field))
                forceArgs=namedargs2cell(options.force_field);
                obj.force_field=kssolv.analysis.matgenlab.io.lammps.LammpsForceField(forceArgs{:});
            end
            if isempty(obj.inputfile)
                ensemble="nvt"; if isprop(obj.settings,'ensemble'), ensemble=string(obj.settings.ensemble); end
                if ensemble=="minimize", file='minimization.template';
                elseif ismember(ensemble,["nve","nvt","npt","nph"]), file='md.template';
                else, error("KSSOLV:Matgenlab:BaseLammpsSetGenerator:Ensemble","Unknown ensemble."); end
                obj.inputfile=fullfile(fileparts(mfilename('fullpath')),'templates',file);
            end
        end
        function update_settings(obj,updates,validate_params,include_defaults)
            if nargin>=3&&~isempty(validate_params), obj.validate_params=validate_params; end
            if nargin>=4&&~isempty(include_defaults), obj.include_defaults=include_defaults; end
            d=obj.settings.as_dict(); d=obj.merge(d,updates);
            if obj.include_defaults, d=obj.merge(obj.defaults(obj.data_type),d); end
            d.validate_params=obj.validate_params; obj.settings=kssolv.analysis.matgenlab.io.lammps.LammpsSettings(d);
        end
        function set=get_input_set(obj,data,additional_data,box_or_lattice,varargin)
            if nargin<3, additional_data=[]; end
            if nargin<4, box_or_lattice=[]; end
            if isa(data,'kssolv.analysis.matgenlab.core.Structure')
                data=kssolv.analysis.matgenlab.io.lammps.LammpsData.from_structure(data,[],obj.settings.atom_style);
            elseif isa(data,'kssolv.analysis.matgenlab.core.Molecule')
                if isempty(box_or_lattice)
                    span=max(range(data.cart_coords,1))+10;
                    box_or_lattice=kssolv.analysis.matgenlab.core.Lattice.cubic(span);
                end
                data=kssolv.analysis.matgenlab.io.lammps.LammpsData.from_molecule( ...
                    data,box_or_lattice,[],obj.settings.atom_style);
            end
            if isa(obj.inputfile,'kssolv.analysis.matgenlab.io.lammps.LammpsInputFile')
                text=obj.inputfile.get_str();
            elseif isfile(obj.inputfile), text=fileread(obj.inputfile);
            else, text=char(obj.inputfile); end
            d=obj.settings.as_dict();
            flags={'nve','nvt','npt','nph','restart','extra_data'};
            for k=1:numel(flags), d.([flags{k} '_flag'])='###'; end
            d.read_data_flag='read_data'; d.psymm='iso';
            if isfield(d,'ensemble'), d.([char(string(d.ensemble)) '_flag'])='fix'; end
            if isfield(d,'boundary')&&iscell(d.boundary), d.boundary=strjoin(string(d.boundary),' '); end
            if isfield(d,'friction'), d.tfriction=d.friction; d.pfriction=d.friction; end
            extra=[];
            if ~isempty(additional_data), extra=struct('extra_data',additional_data); d.extra_data_flag='include'; end
            if isa(obj.force_field,'kssolv.analysis.matgenlab.io.lammps.LammpsForceField')
                forceText=""; forceDict=obj.force_field.as_dict(); forceNames=fieldnames(forceDict);
                for k=1:numel(forceNames)
                    key=forceNames{k}; value=forceDict.(key);
                    if endsWith(key,'_style')&&~isempty(value), d.(key)=value; d.([key '_flag'])=key;
                    elseif endsWith(key,'_coeff')&&~isempty(value)
                        values=string(value); for vi=1:numel(values), forceText=forceText+key+" "+values(vi)+newline; end
                    end
                end
                if isempty(extra), extra=struct(); end
                extra.forcefield_lammps=char(forceText);
            end
            names=fieldnames(d);
            for k=1:numel(names)
                value=d.(names{k});
                if iscell(value)||numel(value)>1, value=join(string(value),' '); end
                text=regexprep(text,'\$\{?'+string(names{k})+'\}?',string(value));
            end
            renderedLines=splitlines(string(text));
            renderedLines(startsWith(strtrim(renderedLines),"###"))=[];
            text=join(renderedLines,newline);
            input=kssolv.analysis.matgenlab.io.lammps.LammpsInputFile.from_str(text,false,obj.keep_stages);
            set=kssolv.analysis.matgenlab.io.lammps.LammpsInputSet(input,data,obj.calc_type,obj.inputfile,extra,obj.keep_stages);
        end
    end
    methods (Static,Access=private)
        function d=defaults(kind)
            common=struct('dimension',3,'pair_style','lj/cut 10.0','thermo',100, ...
                'start_temp',300,'end_temp',300,'start_pressure',0,'end_pressure',0, ...
                'log_interval',100,'traj_interval',100,'ensemble','nvt','thermostat','nose-hoover', ...
                'barostat',[],'nsteps',1000,'restart','','tol',1e-6,'min_style','cg');
            if string(kind)=="periodic", specific=struct('units','metal','atom_style','atomic','boundary',{{'p','p','p'}},'timestep',.001,'friction',.1);
            else, specific=struct('units','real','atom_style','full','boundary',{{'f','f','f'}},'timestep',1,'friction',100); end
            d=kssolv.analysis.matgenlab.io.lammps.BaseLammpsSetGenerator.merge(common,specific);
        end
        function out=merge(a,b)
            out=a; n=fieldnames(b); for k=1:numel(n), out.(n{k})=b.(n{k}); end
        end
    end
end
