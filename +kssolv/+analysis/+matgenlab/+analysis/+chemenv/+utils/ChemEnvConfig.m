%#ok<*ALIGN>
classdef ChemEnvConfig
    %CHEMENVCONFIG Persistent configuration for ChemEnv workflows.
    properties (Constant)
        DEFAULT_PACKAGE_OPTIONS=struct( ...
            default_strategy=struct(strategy="SimplestChemenvStrategy", ...
            strategy_options=struct(distance_cutoff=1.4,angle_cutoff=.3, ...
            additional_condition=1,continuous_symmetry_measure_cutoff=10)), ...
            default_max_distance_factor=1.5)
    end
    properties
        materials_project_configuration=[]
        package_options struct
    end
    properties (Dependent,SetAccess=private)
        has_materials_project_access
    end
    methods
        function obj=ChemEnvConfig(varargin)
            apiKey=string(getenv("PMG_MAPI_KEY"));
            if strlength(apiKey)>0,obj.materials_project_configuration=apiKey;end
            options=[];
            if ~isempty(varargin)
                if ischar(varargin{1})||isstring(varargin{1})
                    if string(varargin{1})=="package_options",options=varargin{2};
                    else,options=varargin{1};end
                else,options=varargin{1};end
            end
            if isempty(options),obj.package_options=obj.DEFAULT_PACKAGE_OPTIONS;
            else,obj.package_options=options;end
        end
        function obj=setup(obj)
            fprintf("\n=> Configuration of the ChemEnv package <=\n%s\n", ...
                obj.package_options_description());
            answer=input("Enter 1 to configure options, S to save, q to quit: ","s");
            if answer=="1",obj=obj.setup_package_options();
            elseif answer=="S",obj.save();end
        end
        function value=get.has_materials_project_access(obj)
            value=~isempty(obj.materials_project_configuration);
        end
        function obj=setup_package_options(obj)
            obj.package_options=obj.DEFAULT_PACKAGE_OPTIONS;
            strategy=input("Default strategy [SimplestChemenvStrategy]: ","s");
            if strlength(strategy)>0
                obj.package_options.default_strategy.strategy=string(strategy);
            end
        end
        function value=package_options_description(obj)
            options=obj.package_options.default_strategy.strategy_options;
            description="Simplest ChemenvStrategy using fixed angle and distance parameters "+newline+ ...
                "for the definition of neighbors in the Voronoi approach. "+newline+ ...
                "The coordination environment is then given as the one with the "+newline+ ...
                "lowest continuous symmetry measure.";
            value="Package options :"+newline+sprintf( ...
                " - Maximum distance factor : %.4f\n", ...
                obj.package_options.default_max_distance_factor)+ ...
                " - Default strategy is """+ ...
                string(obj.package_options.default_strategy.strategy)+""":" ...
                +newline+description+newline+"   with options :"+newline+ ...
                sprintf("     - distance_cutoff : %g\n",options.distance_cutoff)+ ...
                sprintf("     - angle_cutoff : %g\n",options.angle_cutoff)+ ...
                sprintf("     - additional_condition : %g\n", ...
                options.additional_condition)+sprintf( ...
                "     - continuous_symmetry_measure_cutoff : %g\n", ...
                options.continuous_symmetry_measure_cutoff);
        end
        function value=save(obj,varargin)
            root=defaultRoot();
            if ~isempty(varargin)
                if ischar(varargin{1})||isstring(varargin{1})
                    if string(varargin{1})=="root_dir",root=string(varargin{2});
                    else,root=string(varargin{1});end
                else,root=string(varargin{1});end
            end
            if ~isfolder(root),mkdir(root);end
            value=fullfile(root,"config.json");
            if isfile(value)
                answer=input("Overwrite existing configuration? [Y/N] ","s");
                if answer~="Y",return,end
            end
            handle=fopen(value,"w");
            if handle<0
                error("KSSOLV:Matgenlab:ChemEnv:Config", ...
                    "Unable to write configuration '%s'.",value);
            end
            cleanup=onCleanup(@()fclose(handle));
            fwrite(handle,jsonencode(struct( ...
                package_options=obj.package_options)),"char");
        end
    end
    methods (Static)
        function obj=auto_load(varargin)
            root=defaultRoot();
            if ~isempty(varargin)
                if ischar(varargin{1})||isstring(varargin{1})
                    if string(varargin{1})=="root_dir",root=string(varargin{2});
                    else,root=string(varargin{1});end
                else,root=string(varargin{1});end
            end
            path=fullfile(root,"config.json");
            if isfile(path)
                data=jsondecode(fileread(path));
                obj=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
                    ChemEnvConfig(data.package_options);
            else
                warning("KSSOLV:Matgenlab:ChemEnv:Config", ...
                    "Unable to load '%s'; using defaults.",path);
                obj=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
                    ChemEnvConfig();
            end
        end
    end
end
function value=defaultRoot()
value=fullfile(string(java.lang.System.getProperty("user.home")),".chemenv");
end
