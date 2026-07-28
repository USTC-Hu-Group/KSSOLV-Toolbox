classdef IonEntry < kssolv.analysis.matgenlab.analysis.PDEntry
    %IONENTRY Phase-diagram entry carrying an explicitly charged Ion.
    properties
        ion
    end
    methods
        function obj=IonEntry(ion,energy,varargin)
            if nargin==0
                ion=kssolv.analysis.matgenlab.core.Ion();energy=0;
            end
            name="";attribute=[];
            if ~isempty(varargin)&&isName(varargin{1},["name","attribute"])
                for index=1:2:numel(varargin)
                    if index==numel(varargin)
                        error("KSSOLV:Matgenlab:Pourbaix:Arguments", ...
                            "A value is required after '%s'.",varargin{index});
                    end
                    switch lower(string(varargin{index}))
                        case "name",name=varargin{index+1};
                        case "attribute",attribute=varargin{index+1};
                    end
                end
            else
                if ~isempty(varargin),name=varargin{1};end
                if numel(varargin)>1,attribute=varargin{2};end
            end
            if strlength(string(name))==0,name=ion.reduced_formula;end
            obj@kssolv.analysis.matgenlab.analysis.PDEntry( ...
                ion.composition,energy,"name",name,"attribute",attribute);
            obj.ion=ion;
        end
        function value=asDict(obj)
            value=struct(ion=obj.ion.as_dict(),energy=obj.energy, ...
                name=obj.name,attribute=obj.attribute);
        end
        function value=as_dict(obj),value=obj.asDict();end
    end
    methods (Static)
        function obj=from_dict(value)
            attribute=[];if isfield(value,"attribute"),attribute=value.attribute;end
            name="";if isfield(value,"name"),name=value.name;end
            obj=kssolv.analysis.matgenlab.analysis.IonEntry( ...
                kssolv.analysis.matgenlab.core.Ion.from_dict(value.ion), ...
                value.energy,name,attribute);
        end
        function obj=fromDict(value)
            obj=kssolv.analysis.matgenlab.analysis.IonEntry.from_dict(value);
        end
    end
end
function tf=isName(value,names)
tf=(ischar(value)||isstring(value))&&isscalar(string(value))&& ...
    any(strcmpi(string(value),names));
end
