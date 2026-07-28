classdef AbinitPseudo < kssolv.analysis.matgenlab.io.abinit.Pseudo
    methods
        function obj = AbinitPseudo(path, header, kind)
            if nargin < 3, kind = "NC"; end
            obj@kssolv.analysis.matgenlab.io.abinit.Pseudo(path, header, kind);
        end
    end
end
