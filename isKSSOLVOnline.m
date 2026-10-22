function value = isKSSOLVOnline()
%ISKSSOLVONLINE True for a KSSOLV Toolbox Online server session.
% Set KSSOLV_ONLINE=true before starting MATLAB or MATLAB Runtime. Browser
% hosting alone does not imply that files belong to a remote client.
value = ismember(lower(strtrim(getenv('KSSOLV_ONLINE'))), ...
    {'1', 'true', 'yes', 'on'});
end
