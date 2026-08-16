classdef FakeRemoteAccessFactory < handle
    properties (SetAccess = immutable)
        Access
    end

    properties (SetAccess = private)
        Configurations cell = {}
    end

    methods
        function this = FakeRemoteAccessFactory(access)
            this.Access = access;
        end

        function value = create(this, configuration)
            this.Configurations{end + 1, 1} = configuration;
            value = this.Access;
        end
    end
end
