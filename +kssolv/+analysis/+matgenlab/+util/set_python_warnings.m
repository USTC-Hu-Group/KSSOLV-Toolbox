function cleanup=set_python_warnings(value)
%SET_PYTHON_WARNINGS Set PYTHONWARNINGS for a scoped MATLAB operation.
original=getenv("PYTHONWARNINGS");
hadOriginal=~isempty(original);
setenv("PYTHONWARNINGS",char(string(value)));
cleanup=onCleanup(@()restoreWarnings(original,hadOriginal));
end

function restoreWarnings(original,hadOriginal)
if hadOriginal
    setenv("PYTHONWARNINGS",original);
else
    setenv("PYTHONWARNINGS","");
end
end
