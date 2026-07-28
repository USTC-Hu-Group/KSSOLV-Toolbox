classdef MPDocumentEndpoint < handle
    %MPDOCUMENTENDPOINT Search facade for a single MP API document route.

    properties (SetAccess = private)
        document (1,1) string
    end

    properties (Access = private)
        rester
    end

    methods
        function obj = MPDocumentEndpoint(rester, document)
            obj.rester = rester;
            obj.document = string(document);
        end

        function value = search(obj, varargin)
            value = obj.rester.search(obj.document, varargin{:});
        end
    end
end
