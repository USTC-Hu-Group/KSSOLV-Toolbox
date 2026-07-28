function summary = bader_analysis_from_path(path, suffix, varargin)
%BADER_ANALYSIS_FROM_PATH Run Bader analysis on VASP files in a folder.
if nargin < 2, suffix = ""; end
analysis = kssolv.analysis.matgenlab.command_line.bader_caller. ...
    BaderAnalysis.from_path(path, suffix, varargin{:});
summary = analysis.summary;
end
