classdef BoltztrapError
    %BOLTZTRAPERROR Stable error identifiers for the external runner boundary.

    methods (Static)
        function throw(message, varargin)
            error("KSSOLV:Matgenlab:Boltztrap:Runner", ...
                char(join(string(message), "")), varargin{:});
        end
    end
end
