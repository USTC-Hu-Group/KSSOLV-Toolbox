classdef MatSciTest
    %MATSCITEST Materials-science test helpers compatible with pymatgen.
    methods (Static)
        function text=assert_msonable(obj,testIsSubclass)
            if nargin<2,testIsSubclass=true;end
            if testIsSubclass&&~ismethod(obj,"as_dict")
                error("KSSOLV:Matgenlab:Testing:NotMSONable", ...
                    "%s object is not MSONable.",class(obj));
            end
            original=obj.as_dict();
            text=kssolv.analysis.matgenlab.util.encode(original);
            restored=kssolv.analysis.matgenlab.util.decode(text);
            if isstruct(restored)
                if ismethod(obj,"from_dict")
                    restored=feval(class(obj)+".from_dict",restored);
                else
                    error("KSSOLV:Matgenlab:Testing:RoundTrip", ...
                        "%s cannot be reconstructed from its dictionary.", ...
                        class(obj));
                end
            end
            if ~isa(restored,class(obj))
                error("KSSOLV:Matgenlab:Testing:WrongClass", ...
                    "The reconstructed object is not a %s.",class(obj));
            end
            second=restored.as_dict();
            normalizedOriginal=jsondecode( ...
                kssolv.analysis.matgenlab.util.encode(original));
            normalizedSecond=jsondecode( ...
                kssolv.analysis.matgenlab.util.encode(second));
            if ~isequaln(normalizedOriginal,normalizedSecond)
                error("KSSOLV:Matgenlab:Testing:RoundTrip", ...
                    "%s could not be reconstructed accurately.",class(obj));
            end
        end

        function assert_str_content_equal(actual,expected)
            first=regexprep(string(actual),"\s","");
            second=regexprep(string(expected),"\s","");
            if first~=second
                error("KSSOLV:Matgenlab:Testing:StringContent", ...
                    "Strings are not equal when whitespace is ignored.");
            end
        end

        function structure=get_structure(name)
            root=fullfile(fileparts(mfilename("fullpath")),"structures");
            path=fullfile(root,string(name)+".json");
            if ~isfile(path)
                error("KSSOLV:Matgenlab:Testing:MissingStructure", ...
                    "Structure for %s does not exist.",name);
            end
            structure=kssolv.analysis.matgenlab.core.Structure. ...
                from_dict(jsondecode(fileread(path)));
            structure=structure.copy();
        end

        function restored=serialize_with_pickle(objects,protocols,testEq)
            if nargin<2||isempty(protocols),protocols=5;end
            if nargin<3,testEq=true;end
            single=~iscell(objects);
            if single,objects={objects};end
            restored=cell(1,numel(protocols));
            for index=1:numel(protocols)
                path=string(tempname)+".mat";
                cleanup=onCleanup(@()deleteIfPresent(path));
                save(path,"objects","-v7");
                loaded=load(path,"objects");
                values=loaded.objects;
                if testEq
                    for objectIndex=1:numel(objects)
                        if ~isequaln(objects{objectIndex}, ...
                                values{objectIndex})
                            error("KSSOLV:Matgenlab:Testing:Serialization", ...
                                "Serialized and original objects are unequal.");
                        end
                    end
                end
                if single,restored{index}=values{1};
                else,restored{index}=values;end
                clear cleanup
            end
        end
    end
end

function deleteIfPresent(path)
if isfile(path),delete(path);end
end
