function value = mcsqsExecutorStore(action, replacement)
%MCSQSEXECUTORSTORE Shared private-like executor storage.
persistent executor
if nargin > 1 && action == "set", executor = replacement; end
value = executor;
end
