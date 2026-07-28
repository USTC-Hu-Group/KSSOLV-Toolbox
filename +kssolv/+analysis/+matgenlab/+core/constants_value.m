function result = constants_value(key)
%CONSTANTS_VALUE Return a CODATA physical constant by scipy-compatible key.
result = kssolv.analysis.matgenlab.core.Constants.value(key);
end
