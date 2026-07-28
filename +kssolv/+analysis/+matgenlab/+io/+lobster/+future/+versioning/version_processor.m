function decorator = version_processor(min_version, max_version)
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
%VERSION_PROCESSOR Describe an inclusive LOBSTER version interval.
if nargin < 1 || isempty(min_version), min_version = "0.0"; end
if nargin < 2, max_version = []; end
decorator = struct("minimum", string(min_version), "maximum", string(max_version));
end
