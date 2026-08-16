classdef CloudProviderFactory
    %CLOUDPROVIDERFACTORY Resolve a cloud profile provider adapter.

    methods (Static)
        function provider = create(name)
            name = string(name);
            switch name
                case "MathWorksCloudCenter"
                    provider = kssolv.services.remote.cloud. ...
                        MathWorksCloudCenterProvider();
                case "AWS"
                    provider = kssolv.services.remote.cloud.AwsCloudProvider();
                case "PrivateCloud"
                    provider = ...
                        kssolv.services.remote.cloud.PrivateCloudProvider();
                otherwise
                    error("KSSOLV:Remote:InvalidCloudProvider", ...
                        "Unsupported cloud provider %s.", name);
            end
        end
    end
end
