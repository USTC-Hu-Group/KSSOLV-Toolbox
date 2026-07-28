classdef AbstractVoltagePair < kssolv.analysis.matgenlab.util.MSONable
    %ABSTRACTVOLTAGEPAIR Common normalized data for one voltage plateau.
    properties
        voltage (1,1) double = 0
        mAh (1,1) double = 0
        mass_charge (1,1) double = 0
        mass_discharge (1,1) double = 0
        vol_charge (1,1) double = NaN
        vol_discharge (1,1) double = NaN
        frac_charge (1,1) double = 0
        frac_discharge (1,1) double = 0
        working_ion_entry = []
        framework_formula (1,1) string = ""
    end
    properties (Dependent,SetAccess=private)
        working_ion
        framework
        x_charge
        x_discharge
    end
    methods
        function obj=AbstractVoltagePair(varargin)
            if nargin==0,return,end
            fields=["voltage","mAh","mass_charge","mass_discharge", ...
                "vol_charge","vol_discharge","frac_charge","frac_discharge", ...
                "working_ion_entry","framework_formula"];
            obj=assignFields(obj,fields,varargin{:});
            if strlength(obj.framework_formula)==0,return,end
            obj.framework_formula=obj.framework.reduced_formula;
        end
        function value=get.working_ion(obj)
            value=obj.working_ion_entry.elements{1};
        end
        function value=get.framework(obj)
            value=kssolv.analysis.matgenlab.core.Composition(obj.framework_formula);
        end
        function value=get.x_charge(obj)
            value=obj.frac_charge*obj.framework.num_atoms/(1-obj.frac_charge);
        end
        function value=get.x_discharge(obj)
            value=obj.frac_discharge*obj.framework.num_atoms/(1-obj.frac_discharge);
        end
        function data=as_dict(obj)
            data=struct("x_module","pymatgen.apps.battery.battery_abc", ...
                "x_class",classLeaf(obj),"voltage",obj.voltage,"mAh",obj.mAh, ...
                "mass_charge",obj.mass_charge,"mass_discharge",obj.mass_discharge, ...
                "vol_charge",obj.vol_charge,"vol_discharge",obj.vol_discharge, ...
                "frac_charge",obj.frac_charge,"frac_discharge",obj.frac_discharge, ...
                "working_ion_entry",obj.working_ion_entry.as_dict(), ...
                "framework_formula",obj.framework_formula);
        end
        function data=asDict(obj),data=obj.as_dict();end
    end
end
function obj=assignFields(obj,fields,varargin)
position=1;index=1;
while index<=numel(varargin)
    if (ischar(varargin{index})||isstring(varargin{index}))&& ...
            any(strcmpi(string(varargin{index}),fields))
        field=fields(find(strcmpi(string(varargin{index}),fields),1));
        obj.(field)=varargin{index+1};index=index+2;
    else
        obj.(fields(position))=varargin{index};
        position=position+1;index=index+1;
    end
end
end
function name=classLeaf(obj)
parts=split(string(class(obj)),".");name=parts(end);
end
