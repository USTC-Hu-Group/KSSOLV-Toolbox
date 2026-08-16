classdef FakeEnvironmentProbeAccess < handle
    properties
        Status (1, 1) double = 0
        Output (1, 1) string = ""
        Command (1, 1) string = ""
        ConnectionStatus (1, 1) double = 0
        ConnectionOutput (1, 1) string = "KSSOLV_CONNECTION_OK"
        LoginCommand (1, 1) string = ""
    end

    methods
        function this = FakeEnvironmentProbeAccess(output)
            arguments
                output (1, 1) string = ""
            end
            this.Output = output;
        end

        function [status, output] = runCommand(this, command)
            this.Command = string(command);
            status = this.Status;
            output = char(this.Output);
        end

        function [status, output] = runLoginCommand(this, command)
            this.LoginCommand = string(command);
            status = this.ConnectionStatus;
            output = char(this.ConnectionOutput);
        end
    end
end
