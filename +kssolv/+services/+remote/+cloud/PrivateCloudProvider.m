classdef PrivateCloudProvider < ...
        kssolv.services.remote.cloud.CloudProviderAdapter
    %PRIVATECLOUDPROVIDER Administrator-provided cluster profiles.

    methods
        function this = PrivateCloudProvider()
            this@kssolv.services.remote.cloud.CloudProviderAdapter( ...
                "PrivateCloud", "");
        end
    end
end
