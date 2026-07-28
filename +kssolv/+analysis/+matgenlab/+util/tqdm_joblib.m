function cleanup=tqdm_joblib(progressObject)
%TQDM_JOBLIB Return a scoped guard that closes a progress object.
% MATLAB parallel loops report progress through DataQueue rather than joblib;
% this guard provides the equivalent deterministic context lifetime.
if nargin<1||isempty(progressObject)
    error("KSSOLV:Matgenlab:Joblib:ProgressObject", ...
        "A progress object is required.");
end
cleanup=onCleanup(@()closeProgress(progressObject));
end

function closeProgress(progressObject)
if isobject(progressObject)&&ismethod(progressObject,"close")
    progressObject.close();
elseif isa(progressObject,"function_handle")
    progressObject();
elseif isgraphics(progressObject)
    close(progressObject);
end
end
