classdef RemoteCommandExecutor < handle
    %REMOTECOMMANDEXECUTOR Own one persistent remote MATLAB session.

    properties (SetAccess = immutable)
        AccessFactory
        SessionFactory
    end

    properties (SetAccess = private)
        Session = []
        ConfigurationId (1, 1) string = ""
    end

    methods
        function this = RemoteCommandExecutor(accessFactory, options)
            arguments
                accessFactory = ...
                    kssolv.services.remote.transport.RemoteAccessFactory()
                options.SessionFactory = ...
                    @kssolv.services.remote.execution. ...
                    RemoteCommandExecutor.createSession
            end
            this.AccessFactory = accessFactory;
            this.SessionFactory = options.SessionFactory;
        end

        function output = execute(this, command, configuration, options)
            arguments
                this
                command (1, 1) string
                configuration struct
                options.StatusReporter = []
            end
            if strlength(strip(command)) == 0
                output = "";
                return
            end
            configuration = kssolv.services.remote.config. ...
                RemoteConfiguration.sanitized(configuration);
            validateMatlabSessionConfiguration(configuration);
            if isempty(this.Session) || ~isvalid(this.Session) || ...
                    this.ConfigurationId ~= configuration.Id || ...
                    ~isequaln(this.Session.Configuration, configuration)
                this.closeSession();
                reportStatus(options.StatusReporter, "Connecting", ...
                    configuration.DisplayName);
                this.Session = this.SessionFactory( ...
                    configuration, this.AccessFactory);
                this.ConfigurationId = configuration.Id;
            end
            try
                output = string(this.Session.execute(command, ...
                    StatusReporter=options.StatusReporter));
            catch exception
                reportStatus(options.StatusReporter, "Failed", ...
                    string(exception.message));
                this.closeSession();
                rethrow(exception)
            end
            if ~isscalar(output)
                output = join(output, newline);
            end
        end

        function closeSession(this)
            session = this.Session;
            this.Session = [];
            this.ConfigurationId = "";
            if isempty(session) || ~isvalid(session)
                return
            end
            session.close();
            delete(session);
        end

        function delete(this)
            try
                this.closeSession();
            catch
            end
        end
    end

    methods (Static, Hidden)
        function session = createSession(configuration, accessFactory)
            session = kssolv.services.remote.execution. ...
                RemoteMatlabSession(configuration, accessFactory);
        end
    end
end

function reportStatus(reporter, phase, detail)
if isempty(reporter)
    return
end
try
    reporter(string(phase), string(detail));
catch
end
end

function validateMatlabSessionConfiguration(configuration)
if ~configuration.Enabled
    error("KSSOLV:Remote:ConfigurationDisabled", ...
        "The selected remote configuration is disabled.");
end
required = ["Host", "Username", "ClusterMatlabRoot", ...
    "RemoteJobStorageLocation"];
missing = strings(0, 1);
for name = required
    if strlength(string(configuration.(name))) == 0
        missing(end + 1, 1) = name; %#ok<AGROW>
    end
end
if ~isempty(missing)
    error("KSSOLV:Remote:MatlabSessionConfigurationIncomplete", ...
        "Remote Command Window requires an SSH host, username, remote " + ...
        "MATLAB root, and remote job storage location. Missing: %s.", ...
        join(missing, ", "));
end
end
