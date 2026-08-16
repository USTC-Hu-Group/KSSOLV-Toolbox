classdef MathWorksCloudCenterProvider < ...
        kssolv.services.remote.cloud.CloudProviderAdapter
    %MATHWORKSCLOUDCENTERPROVIDER Profiles discovered from Cloud Center.

    methods
        function this = MathWorksCloudCenterProvider()
            this@kssolv.services.remote.cloud.CloudProviderAdapter( ...
                "MathWorksCloudCenter", ...
                "https://cloudcenter.mathworks.com");
        end
    end
end
