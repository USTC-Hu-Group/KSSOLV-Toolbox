classdef Provider
    %PROVIDER Metadata for one OPTIMADE provider or child database.

    properties (SetAccess = private)
        name (1,1) string
        base_url (1,1) string
        description (1,1) string
        homepage (1,1) string
        prefix (1,1) string
    end

    methods
        function obj = Provider(name, baseUrl, description, homepage, prefix)
            if nargin == 0
                name = "";
                baseUrl = "";
                description = "";
                homepage = "";
                prefix = "";
            end
            obj.name = string(name);
            obj.base_url = string(baseUrl);
            obj.description = stringOrEmpty(description);
            obj.homepage = stringOrEmpty(homepage);
            obj.prefix = stringOrEmpty(prefix);
        end

        function text = char(obj)
            text = char("Provider(" + strjoin([ ...
                "name='" + obj.name + "'", ...
                "base_url='" + obj.base_url + "'", ...
                "description='" + obj.description + "'", ...
                "homepage='" + obj.homepage + "'", ...
                "prefix='" + obj.prefix + "'"], ", ") + ")");
        end

        function text = string(obj)
            text = string(char(obj));
        end
    end
end

function value = stringOrEmpty(input)
if isempty(input)
    value = "";
else
    value = string(input);
end
end
