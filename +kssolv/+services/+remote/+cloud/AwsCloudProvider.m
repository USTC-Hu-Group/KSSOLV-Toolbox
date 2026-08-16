classdef AwsCloudProvider < kssolv.services.remote.cloud.CloudProviderAdapter
    %AWSCLOUDPROVIDER Profiles from AWS reference architectures.

    methods
        function this = AwsCloudProvider()
            this@kssolv.services.remote.cloud.CloudProviderAdapter( ...
                "AWS", "https://aws.amazon.com/console/");
        end
    end
end
