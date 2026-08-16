classdef ThrowingClusterFactory < handle
    %THROWINGCLUSTERFACTORY Deterministic factory failure for state tests.

    properties
        ErrorIdentifier (1, 1) string
        ErrorMessage (1, 1) string
    end

    methods
        function this = ThrowingClusterFactory(identifier, message)
            this.ErrorIdentifier = identifier;
            this.ErrorMessage = message;
        end

        function cluster = ensureProfile(this, ~) %#ok<STOUT>
            error(this.ErrorIdentifier, this.ErrorMessage);
        end
    end
end
