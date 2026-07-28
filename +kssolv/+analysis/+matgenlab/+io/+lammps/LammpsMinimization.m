classdef LammpsMinimization < kssolv.analysis.matgenlab.io.lammps.BaseLammpsGenerator
    properties (Dependent)
        units; atom_style; dimension; boundary; read_data; force_field
    end
    methods
        function obj=LammpsMinimization(template,units,atom_style,dimension,boundary,read_data,force_field,keep_stages)
            if nargin<1||isempty(template), template=fullfile(fileparts(mfilename('fullpath')),'templates','minimization.template'); end
            if nargin<2, units='metal'; end
            if nargin<3, atom_style='full'; end
            if nargin<4, dimension=3; end
            if nargin<5, boundary='p p p'; end
            if nargin<6, read_data='system.data'; end
            if nargin<7, force_field='Unspecified force field!'; end
            if nargin<8, keep_stages=false; end
            settings=struct('units',units,'atom_style',atom_style,'dimension',dimension, ...
                'boundary',boundary,'read_data',read_data,'force_field',force_field);
            obj@kssolv.analysis.matgenlab.io.lammps.BaseLammpsGenerator( ...
                template=template,settings=settings,calc_type="minimization",keep_stages=keep_stages);
        end
        function v=get.units(obj), v=obj.settings.units; end
        function v=get.atom_style(obj), v=obj.settings.atom_style; end
        function v=get.dimension(obj), v=obj.settings.dimension; end
        function v=get.boundary(obj), v=obj.settings.boundary; end
        function v=get.read_data(obj), v=obj.settings.read_data; end
        function v=get.force_field(obj), v=obj.settings.force_field; end
    end
end
