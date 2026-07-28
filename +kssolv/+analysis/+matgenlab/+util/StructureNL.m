classdef StructureNL
    %STRUCTURENL Structure Notation Language provenance container.
    properties (Constant)
        MAX_HNODE_SIZE=64000
        MAX_DATA_SIZE=256000
        MAX_HNODES=100
        MAX_BIBTEX_CHARS=20000
    end
    properties
        structure
        authors cell
        projects cell
        references (1,1) string
        remarks cell
        data
        history cell
        created_at
    end
    methods
        function obj=StructureNL(structure,authors,projects, ...
                references,remarks,data,history,createdAt)
            if nargin<3||isempty(projects),projects={};end
            if nargin<4,references="";end
            if nargin<5||isempty(remarks),remarks={};end
            if nargin<6||isempty(data),data=struct();end
            if nargin<7||isempty(history),history={};end
            if nargin<8||isempty(createdAt)
                createdAt=string(datetime("now","TimeZone","UTC", ...
                    "Format","yyyy-MM-dd HH:mm:ss.SSSSSSxx"));
            end
            obj.structure=structure;
            if ischar(authors)||(isstring(authors)&&isscalar(authors))
                authors=cellstr(split(string(authors),","));
            elseif ~iscell(authors)
                authors=num2cell(authors);
            end
            obj.authors=cellfun(@(value) ...
                kssolv.analysis.matgenlab.util.Author.parse_author(value), ...
                authors,"UniformOutput",false);
            if ischar(projects)||(isstring(projects)&&isscalar(projects))
                projects={char(projects)};
            end
            obj.projects=reshape(cellstr(string(projects)),1,[]);
            if ~(ischar(references)|| ...
                    (isstring(references)&&isscalar(references)))
                error("KSSOLV:Matgenlab:StructureNL:ReferenceType", ...
                    "Reference must be an empty string or BibTeX string.");
            end
            references=string(references);
            if strlength(references)>0&& ...
                    ~kssolv.analysis.matgenlab.util. ...
                    is_valid_bibtex(references)
                error("KSSOLV:Matgenlab:StructureNL:Reference", ...
                    "Reference must be valid BibTeX.");
            end
            if strlength(references)>obj.MAX_BIBTEX_CHARS
                error("KSSOLV:Matgenlab:StructureNL:ReferenceSize", ...
                    "BibTeX reference exceeds %d characters.", ...
                    obj.MAX_BIBTEX_CHARS);
            end
            obj.references=references;
            if ischar(remarks)||(isstring(remarks)&&isscalar(remarks))
                remarks={char(remarks)};
            end
            obj.remarks=reshape(cellstr(string(remarks)),1,[]);
            if any(cellfun(@(value)strlength(string(value)), ...
                    obj.remarks)>140)
                error("KSSOLV:Matgenlab:StructureNL:RemarkSize", ...
                    "Remarks may not exceed 140 characters.");
            end
            serializedData=kssolv.analysis.matgenlab.util.toDict(data);
            if strlength(jsonencode(serializedData))>=obj.MAX_DATA_SIZE
                error("KSSOLV:Matgenlab:StructureNL:DataSize", ...
                    "Data exceeds the maximum serialized size.");
            end
            names=dataNames(data);
            if any(~startsWith(string(names),"_"))
                error("KSSOLV:Matgenlab:StructureNL:Namespace", ...
                    "Data keys must start with an underscore.");
            end
            obj.data=data;
            if ~iscell(history),history=num2cell(history);end
            if numel(history)>obj.MAX_HNODES
                error("KSSOLV:Matgenlab:StructureNL:HistoryCount", ...
                    "At most %d history nodes are supported.", ...
                    obj.MAX_HNODES);
            end
            obj.history=cellfun(@(value) ...
                kssolv.analysis.matgenlab.util.HistoryNode. ...
                parse_history_node(value),history,"UniformOutput",false);
            if any(cellfun(@(value)strlength(jsonencode( ...
                    kssolv.analysis.matgenlab.util.toDict( ...
                    value.as_dict())))>=obj.MAX_HNODE_SIZE,obj.history))
                error("KSSOLV:Matgenlab:StructureNL:HistorySize", ...
                    "A history node exceeds the maximum size.");
            end
            obj.created_at=createdAt;
        end
        function text=char(obj)
            structureText=strtrim(evalc("disp(obj.structure)"));
            authorsText=strjoin(cellfun(@char,obj.authors, ...
                "UniformOutput",false),", ");
            text=sprintf(strjoin(["structure","%s","authors","%s", ...
                "projects","%s","references","%s","remarks","%s", ...
                "data","%s","history","%s","created_at","%s"], ...
                newline),structureText,authorsText, ...
                strjoin(obj.projects,", "),obj.references, ...
                strjoin(obj.remarks,", "), ...
                strtrim(evalc("disp(obj.data)")), ...
                strtrim(evalc("disp(obj.history)")), ...
                string(obj.created_at));
        end
        function equal=eq(obj,other)
            equal=isa(other,class(obj))&& ...
                obj.structure==other.structure&& ...
                isequal(obj.authors,other.authors)&& ...
                isequal(obj.projects,other.projects)&& ...
                obj.references==other.references&& ...
                isequal(obj.remarks,other.remarks)&& ...
                mappingsEqual(obj.data,other.data)&& ...
                isequal(obj.history,other.history)&& ...
                isequal(obj.created_at,other.created_at);
        end
        function data=as_dict(obj)
            data=obj.structure.as_dict();
            data.x_module="pymatgen.util.provenance";
            data.x_class="StructureNL";
            about=containers.Map("KeyType","char","ValueType","any");
            about("authors")=cellfun(@(value)value.as_dict(), ...
                obj.authors,"UniformOutput",false);
            about("projects")=obj.projects;
            about("references")=obj.references;
            about("remarks")=obj.remarks;
            about("history")=cellfun(@(value)value.as_dict(),obj.history, ...
                "UniformOutput",false);
            about("created_at")=obj.created_at;
            about=mergeData(about,obj.data);
            data.about=about;
        end
        function data=asDict(obj),data=obj.as_dict();end
    end
    methods (Static)
        function obj=from_dict(data)
            about=data.about;names=dataNames(about);
            metadata=containers.Map("KeyType","char","ValueType","any");
            for index=1:numel(names)
                name=string(names{index});
                if startsWith(name,"_")
                    metadata(char(name))=dataValue(about,char(name));
                elseif startsWith(name,"x_")&& ...
                        ~any(name==["x_module","x_class","x_version"])
                    metadata(char(extractAfter(name,1)))= ...
                        dataValue(about,char(name));
                end
            end
            if isfield(data,"lattice")
                value=kssolv.analysis.matgenlab.core.Structure. ...
                    from_dict(data);
            else
                value=kssolv.analysis.matgenlab.core.Molecule. ...
                    from_dict(data);
            end
            optional=struct("projects",{{}},"references","", ...
                "remarks",{{}},"history",{{}},"created_at",[]);
            names=fieldnames(optional);
            for index=1:numel(names)
                if dataHas(about,names{index})
                    optional.(names{index})=dataValue( ...
                        about,names{index});
                end
            end
            authors=dataValue(about,"authors");
            if isstruct(authors)
                authors=num2cell(authors);
            end
            history=optional.history;
            if isstruct(history)
                history=num2cell(history);
            end
            obj=kssolv.analysis.matgenlab.util.StructureNL( ...
                value,authors,optional.projects,optional.references, ...
                optional.remarks,metadata,history,optional.created_at);
        end
        function obj=fromDict(data)
            obj=kssolv.analysis.matgenlab.util.StructureNL.from_dict(data);
        end
        function values=from_structures(structures,authors, ...
                projects,references,remarks,data,histories,createdAt)
            if nargin<3,projects={};end
            if nargin<4,references="";end
            if nargin<5,remarks={};end
            if ~iscell(structures),structures=num2cell(structures);end
            count=numel(structures);
            if nargin<6||isempty(data),data=repmat({struct()},1,count);end
            if nargin<7||isempty(histories)
                histories=repmat({{}},1,count);
            end
            if nargin<8,createdAt=[];end
            values=cell(1,count);
            for index=1:count
                values{index}=kssolv.analysis.matgenlab.util.StructureNL( ...
                    structures{index},authors,projects,references,remarks, ...
                    data{index},histories{index},createdAt);
            end
        end
        function values=fromStructures(varargin)
            values=kssolv.analysis.matgenlab.util.StructureNL. ...
                from_structures(varargin{:});
        end
    end
end

function names=dataNames(data)
if isstruct(data),names=fieldnames(data);
elseif isa(data,"containers.Map"),names=keys(data);
else
    error("KSSOLV:Matgenlab:StructureNL:DataType", ...
        "Data must be a struct or containers.Map.");
end
end
function output=mergeData(output,data)
if isstruct(data)
    names=fieldnames(data);
    for index=1:numel(names)
        output(names{index})=data.(names{index});
    end
else
    names=keys(data);
    for index=1:numel(names)
        output(names{index})=data(names{index});
    end
end
end
function present=dataHas(data,name)
if isstruct(data)
    present=isfield(data,name);
else
    present=isKey(data,char(name));
end
end
function value=dataValue(data,name)
if isstruct(data)
    value=data.(name);
else
    value=data(char(name));
end
end
function equal=mappingsEqual(first,second)
if isa(first,"containers.Map")&&isa(second,"containers.Map")
    firstNames=sort(string(keys(first)));
    secondNames=sort(string(keys(second)));
    if ~isequal(firstNames,secondNames),equal=false;return,end
    equal=true;
    for index=1:numel(firstNames)
        name=char(firstNames(index));
        if ~isequaln(first(name),second(name))
            equal=false;return
        end
    end
elseif isstruct(first)&&isstruct(second)
    equal=isequaln(first,second);
else
    equal=false;
end
end
