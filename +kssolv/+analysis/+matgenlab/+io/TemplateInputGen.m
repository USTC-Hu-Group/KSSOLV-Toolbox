classdef TemplateInputGen < kssolv.analysis.matgenlab.io.InputGenerator
    %TEMPLATEINPUTGEN Produce an InputSet using safe template substitution.
    properties
        template
        variables
        filename (1,1) string = "input.txt"
        data (1,1) string = ""
    end
    methods
        function inputSet=get_input_set(obj,template,variables,filename)
            if nargin<3||isempty(variables),variables=struct();end
            if nargin<4||isempty(filename),filename="input.txt";end
            obj.template=template;obj.variables=variables;
            obj.filename=string(filename);
            text=string(fileread(template));
            if isa(variables,"containers.Map")
                names=string(keys(variables));
                values=cellfun(@(key)variables(key),keys(variables), ...
                    "UniformOutput",false);
            elseif isstruct(variables)
                names=string(fieldnames(variables));
                values=struct2cell(variables);
            else
                error("KSSOLV:Matgenlab:Template:Variables", ...
                    "variables must be a struct or containers.Map.");
            end
            for index=1:numel(names)
                replacement=string(values{index});
                text=replace(text,"${"+names(index)+"}",replacement);
                pattern="\$"+regexptranslate("escape", ...
                    names(index))+"(?![A-Za-z0-9_])";
                text=regexprep(text,pattern,replacement);
            end
            obj.data=text;
            inputSet=kssolv.analysis.matgenlab.io.InputSet( ...
                {char(obj.filename),char(text)});
        end
    end
end
