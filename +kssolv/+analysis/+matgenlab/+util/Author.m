classdef Author
    %AUTHOR Named and email-addressed contributor.
    properties
        name (1,1) string
        email (1,1) string
    end
    methods
        function obj=Author(name,email)
            obj.name=string(name);obj.email=string(email);
        end
        function text=char(obj)
            text=char(obj.name+" <"+obj.email+">");
        end
        function data=as_dict(obj)
            data=struct("name",obj.name,"email",obj.email);
        end
        function data=asDict(obj),data=obj.as_dict();end
        function equal=eq(obj,other)
            equal=isa(other,class(obj))&&obj.name==other.name&& ...
                obj.email==other.email;
        end
    end
    methods (Static)
        function obj=from_dict(data)
            obj=kssolv.analysis.matgenlab.util.Author( ...
                data.name,data.email);
        end
        function obj=fromDict(data)
            obj=kssolv.analysis.matgenlab.util.Author.from_dict(data);
        end
        function obj=parse_author(value)
            if isa(value,"kssolv.analysis.matgenlab.util.Author")
                obj=value;return
            end
            if ischar(value)||(isstring(value)&&isscalar(value))
                token=regexp(char(value), ...
                    '^\s*(.*?)\s*<(.*?@.*?)>\s*$',"tokens","once");
                if isempty(token)
                    error("KSSOLV:Matgenlab:Author:Format", ...
                        "Invalid author format: %s",string(value));
                end
                obj=kssolv.analysis.matgenlab.util.Author( ...
                    token{1},token{2});
            elseif isstruct(value)
                obj=kssolv.analysis.matgenlab.util.Author.from_dict(value);
            elseif iscell(value)&&numel(value)==2
                obj=kssolv.analysis.matgenlab.util.Author( ...
                    value{1},value{2});
            else
                error("KSSOLV:Matgenlab:Author:Format", ...
                    "Author must be a formatted string, struct or pair.");
            end
        end
        function obj=parseAuthor(value)
            obj=kssolv.analysis.matgenlab.util.Author.parse_author(value);
        end
    end
end
