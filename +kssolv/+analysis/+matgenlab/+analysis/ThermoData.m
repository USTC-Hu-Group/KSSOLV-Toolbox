classdef ThermoData < kssolv.analysis.matgenlab.util.MSONable
    %THERMODATA Experimental thermochemical data record.
    properties
        type
        formula
        composition
        reduced_formula
        compound_name
        phaseinfo
        value
        temp_range
        method
        ref
        uncertainty
    end
    methods
        function obj=ThermoData(dataType,name,phase,formula,value, ...
                reference,method,tempRange,uncertainty)
            if nargin<6,reference="";end
            if nargin<7,method="";end
            if nargin<8,tempRange=[298,298];end
            if nargin<9,uncertainty=[];end
            obj.type=dataType;obj.formula=formula;
            obj.composition=kssolv.analysis.matgenlab.core.Composition(formula);
            obj.reduced_formula=obj.composition.reduced_formula;
            obj.compound_name=name;obj.phaseinfo=phase;obj.value=value;
            obj.temp_range=tempRange;obj.method=method;obj.ref=reference;
            obj.uncertainty=uncertainty;
        end
        function value=as_dict(obj)
            value=struct("x_module","pymatgen.analysis.thermochemistry", ...
                "x_class","ThermoData","type",obj.type, ...
                "formula",obj.formula,"compound_name",obj.compound_name, ...
                "phaseinfo",obj.phaseinfo,"value",obj.value, ...
                "temp_range",obj.temp_range,"method",obj.method, ...
                "ref",obj.ref,"uncertainty",obj.uncertainty);
        end
        function value=asDict(obj),value=obj.as_dict();end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.ThermoData( ...
                value.type,value.compound_name,value.phaseinfo, ...
                value.formula,value.value,value.ref,value.method, ...
                value.temp_range,value.uncertainty);
        end
    end
end
