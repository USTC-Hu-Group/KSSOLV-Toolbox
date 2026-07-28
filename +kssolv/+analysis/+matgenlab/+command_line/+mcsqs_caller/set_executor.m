function set_executor(executor)
%SET_EXECUTOR Configure the explicit ATAT mcsqs execution boundary.
if nargin == 0, executor = []; end
kssolv.analysis.matgenlab.command_line.mcsqs_caller. ...
    mcsqsExecutorStore("set", executor);
end
