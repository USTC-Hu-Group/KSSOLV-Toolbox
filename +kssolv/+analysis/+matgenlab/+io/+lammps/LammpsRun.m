classdef LammpsRun
    properties
        script_template; settings; data; script_filename
    end
    methods
        function obj=LammpsRun(script_template,settings,data,script_filename)
            obj.script_template=script_template; obj.settings=settings;
            obj.data=data; obj.script_filename=script_filename;
        end
        function write_inputs(obj,output_dir,varargin)
            kssolv.analysis.matgenlab.io.lammps.write_lammps_inputs( ...
                output_dir,obj.script_template,obj.settings,obj.data,obj.script_filename,varargin{:});
        end
    end
    methods (Static)
        function obj=md(data,force_field,temperature,nsteps,other_settings)
            if nargin<5||isempty(other_settings), other_settings=struct(); end
            path=fullfile(fileparts(mfilename('fullpath')),'templates','md.template');
            settings=other_settings; settings.force_field=force_field;
            settings.temperature=temperature; settings.nsteps=nsteps;
            obj=kssolv.analysis.matgenlab.io.lammps.LammpsRun( ...
                fileread(path),settings,data,'in.md');
        end
    end
end
