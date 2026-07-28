classdef NcPseudo < kssolv.analysis.matgenlab.io.abinit.Pseudo
    methods
        function obj = NcPseudo(path, header), obj@kssolv.analysis.matgenlab.io.abinit.Pseudo(path, header, "NC"); end
    end
end
