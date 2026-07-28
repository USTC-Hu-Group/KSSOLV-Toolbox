classdef FeffParseError < MException
 methods
  function obj=FeffParseError(message),obj@MException("KSSOLV:Matgenlab:Feff:Parse",string(message));end
 end
end
