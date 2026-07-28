classdef PDEntry < kssolv.analysis.matgenlab.core.Entry
    %PDENTRY Composition-energy record used by phase diagrams.
    properties
        name (1,1) string = ""
        attribute = []
        decomposition cell = cell(0,2)
    end
    methods
        function obj=PDEntry(composition,energy,varargin)
            if nargin==0
                composition=kssolv.analysis.matgenlab.core.Composition();
                energy=0;emptyConstruction=true;
            else
                emptyConstruction=false;
            end
            obj@kssolv.analysis.matgenlab.core.Entry(composition,energy);
            if emptyConstruction,return,end
            options=struct(name="",attribute=[]);
            options=parseOptions(options,varargin);
            if strlength(string(options.name))==0
                obj.name=obj.reduced_formula;
            else
                obj.name=string(options.name);
            end
            obj.attribute=options.attribute;
        end
        function data=as_dict(obj)
            data=as_dict@kssolv.analysis.matgenlab.core.Entry(obj);
            data.x_module="pymatgen.analysis.phase_diagram";
            data.x_class="PDEntry";
            data.name=obj.name;
            data.attribute=obj.attribute;
        end
        function data=asDict(obj),data=obj.as_dict();end
        function text=char(obj)
            suffix="";
            if obj.name~=obj.reduced_formula,suffix=" ("+obj.name+")";end
            text=sprintf("PDEntry : %s%s with energy = %.4f", ...
                obj.formula,suffix,obj.energy);
        end
    end
    methods (Static)
        function obj=from_dict(data)
            name="";attribute=[];
            if isfield(data,"name"),name=data.name;end
            if isfield(data,"attribute"),attribute=data.attribute;end
            obj=kssolv.analysis.matgenlab.analysis.PDEntry( ...
                data.composition,data.energy,"name",name,"attribute",attribute);
        end
        function obj=fromDict(data),obj=kssolv.analysis.matgenlab.analysis.PDEntry.from_dict(data);end
    end
end

function output=parseOptions(output,input)
names=fieldnames(output);position=1;ii=1;
while ii<=numel(input)
    if (ischar(input{ii})||isstring(input{ii}))&& ...
            any(strcmpi(string(input{ii}),string(names)))
        key=names{strcmpi(string(input{ii}),string(names))};
        output.(key)=input{ii+1};ii=ii+2;
    else
        output.(names{position})=input{ii};position=position+1;ii=ii+1;
    end
end
end
