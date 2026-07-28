classdef Cp2kValidationError < MException
 methods
  function obj=Cp2kValidationError(message),obj@MException("KSSOLV:Matgenlab:Cp2k:Validation","CP2K v2022.1: "+string(message));end
 end
end
