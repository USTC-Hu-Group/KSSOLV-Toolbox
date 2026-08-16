classdef RoutedRemoteClusterDelegate < handle
    %ROUTEDREMOTECLUSTERDELEGATE Expose login-host primitives to a router.

    properties (SetAccess = immutable)
        Owner
    end

    methods
        function this = RoutedRemoteClusterDelegate(owner)
            this.Owner = owner;
        end

        function [status, output] = runCommand(this, command)
            [status, output] = this.Owner.runCommand(command, true);
        end

        function [status, output] = runCommandUntilMarker( ...
                this, command, ~)
            [status, output] = this.Owner.runCommand(command, true);
        end

        function varargout = copyFileToRemote( ...
                this, source, destination)
            [varargout{1:nargout}] = this.Owner. ...
                copyFileToRemote(source, destination);
        end

        function varargout = copyFileFromRemote( ...
                this, source, destination)
            [varargout{1:nargout}] = this.Owner. ...
                copyFileFromRemote(source, destination);
        end

        function remoteDelete(this, path)
            this.Owner.remoteDelete(path);
        end
    end
end
