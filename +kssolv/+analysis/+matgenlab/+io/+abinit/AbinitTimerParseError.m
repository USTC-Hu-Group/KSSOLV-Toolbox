classdef AbinitTimerParseError < MException
    methods
        function obj=AbinitTimerParseError(message),obj@MException("KSSOLV:Matgenlab:Abinit:TimerParse",message);end
    end
end
