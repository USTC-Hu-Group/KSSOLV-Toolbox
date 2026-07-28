classdef LammpsTemplateGen
    methods
        function inputSet=get_input_set(~,script_template,settings,script_filename,data,data_filename)
            if nargin<3||isempty(settings), settings=struct(); end
            if nargin<4||isempty(script_filename), script_filename='in.lammps'; end
            if nargin<5, data=[]; end
            if nargin<6||isempty(data_filename), data_filename='system.data'; end
            text=fileread(script_template); names=fieldnames(settings);
            for k=1:numel(names)
                text=regexprep(text,'\$\{?'+string(names{k})+'\}?',string(settings.(names{k})));
            end
            inputSet=struct(); inputSet.(matlab.lang.makeValidName(script_filename))=char(text);
            if ~isempty(data), inputSet.(matlab.lang.makeValidName(data_filename))=data; end
        end
    end
end
