classdef BaseLammpsGenerator
    %#ok<*ALIGN,*PROP>
    properties
        inputfile=[]; template=""; data=[]; settings=struct()
        calc_type="lammps"; keep_stages=true
    end
    methods
        function obj=BaseLammpsGenerator(options)
            arguments
                options.inputfile=[]
                options.template=""
                options.data=[]
                options.settings=struct()
                options.calc_type="lammps"
                options.keep_stages=true
            end
            n=fieldnames(options); for k=1:numel(n), obj.(n{k})=options.(n{k}); end
        end
        function inputSet=get_input_set(obj,structure)
            if isa(structure,'kssolv.analysis.matgenlab.core.Structure')
                style='full'; if isfield(obj.settings,'atom_style'), style=obj.settings.atom_style; end
                data=kssolv.analysis.matgenlab.io.lammps.LammpsData.from_structure(structure,[],style);
            else, data=structure; end
            if isa(obj.template,'kssolv.analysis.matgenlab.io.lammps.LammpsInputFile'), text=obj.template.get_str();
            elseif isfile(obj.template), text=fileread(obj.template); else, text=char(obj.template); end
            n=fieldnames(obj.settings);
            for k=1:numel(n), text=regexprep(text,'\$\{?'+string(n{k})+'\}?',string(obj.settings.(n{k}))); end
            file=kssolv.analysis.matgenlab.io.lammps.LammpsInputFile.from_str(text,false,obj.keep_stages);
            inputSet=kssolv.analysis.matgenlab.io.lammps.LammpsInputSet(file,data,obj.calc_type,obj.template,[],obj.keep_stages);
        end
    end
end
