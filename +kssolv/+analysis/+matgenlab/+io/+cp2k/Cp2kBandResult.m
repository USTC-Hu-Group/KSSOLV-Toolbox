classdef Cp2kBandResult
%#ok<*NOCOMMA,*NOSEMI>
 properties,gap=0;end
 methods,function obj=Cp2kBandResult(gap),obj.gap=gap;end;function value=get_band_gap(obj),value=struct("energy",obj.gap);end,end
end
