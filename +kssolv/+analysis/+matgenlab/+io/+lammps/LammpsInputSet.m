classdef LammpsInputSet
    properties
        inputfile; data; calc_type; template_file; additional_data; keep_stages
        inputs
    end
    methods
        function obj=LammpsInputSet(inputfile,data,calc_type,template_file,additional_data,keep_stages)
            if nargin<3, calc_type=""; end
            if nargin<4, template_file=""; end
            if nargin<5, additional_data=[]; end
            if nargin<6, keep_stages=false; end
            if ~isa(inputfile,'kssolv.analysis.matgenlab.io.lammps.LammpsInputFile')
                inputfile=kssolv.analysis.matgenlab.io.lammps.LammpsInputFile.from_str(inputfile,false,keep_stages);
            end
            obj.inputfile=inputfile; obj.data=data; obj.calc_type=calc_type;
            obj.template_file=template_file; obj.additional_data=additional_data; obj.keep_stages=keep_stages;
            obj.inputs=struct('in_lammps',inputfile,'input_data',data);
            if isstruct(additional_data)
                n=fieldnames(additional_data); for k=1:numel(n), obj.inputs.(n{k})=additional_data.(n{k}); end
            end
        end
        function tf=validate(obj) %#ok<MANU,STOUT>
            error("KSSOLV:Matgenlab:LammpsInputSet:NotImplemented", ...
                ".validate() has not been implemented in LammpsInputSet");
        end
    end
    methods (Static)
        function obj=from_directory(directory,keep_stages)
            if nargin<2, keep_stages=false; end
            input=kssolv.analysis.matgenlab.io.lammps.LammpsInputFile.from_file( ...
                fullfile(directory,'in.lammps'),false,keep_stages);
            style=input.get_args('atom_style');
            if iscell(style), error("Variable atom_style is specified multiple times."); end
            data=kssolv.analysis.matgenlab.io.lammps.LammpsData.from_file( ...
                fullfile(directory,'system.data'),style);
            obj=kssolv.analysis.matgenlab.io.lammps.LammpsInputSet(input,data,'read_from_dir',"",[],keep_stages);
        end
    end
end
