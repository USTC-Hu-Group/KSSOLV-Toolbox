function [kpointParameterDefinitions, kpointDefinitions, kpointPath] = getPathData(extendedBravais)
%GETPATHDATA Retrieve k-point parameters, points, and paths for an extended Bravais lattice.
%
% This function retrieves data for the specified extended Bravais lattice symbol from
% the `BandPathData.mat` file. If the file does not exist, it triggers the generation
% of the data using `data.generateBandPathData`.
%
% Input:
%   extendedBravais - A string representing the extended Bravais lattice symbol (e.g., 'cF1').
%
% Output:
%   kpointParameterDefinitions - A cell array defining k-point parameters in order.
%   kpointDefinitions          - A structure with k-point labels as fields and their coordinates as values.
%   kpointPath                 - A cell array defining the suggested k-point paths.

% Define the path to the BandPathData.mat file
currentFolder = fileparts(mfilename('fullpath'));
seekpathFolder = fileparts(fileparts(currentFolder));
bandPathDataFilePath = fullfile(seekpathFolder, '+data', 'BandPathData.mat');

% Check if the BandPathData.mat file exists
if ~isfile(bandPathDataFilePath)
    fprintf('BandPathData.mat not found. Generating it...\n');
    kssolv.analysis.seekpath.data.generateBandPathData();
end

% Load the BandPathData.mat file
loadedData = load(bandPathDataFilePath, 'bandPathData');
bandPathData = loadedData.bandPathData;

% Check if the requested Bravais lattice exists in the data
if ~isfield(bandPathData, extendedBravais)
    error('Bravais lattice "%s" not found in the BandPathData.', extendedBravais);
end

% Extract the data for the specified Bravais lattice
latticeData = bandPathData.(extendedBravais);

% Extract k-point parameters, definitions, and paths from the loaded data
kpointParameterDefinitions = latticeData.k_vector_parameters;  % Ordered list of k-point parameters
kpointDefinitions = latticeData.points;          % Structure of k-point coordinates
kpointPath = latticeData.path;                       % List of paths connecting k-points

% Validate the data
% Check that all points in the path exist in kpointDefinitions
for i = 1:size(kpointPath, 1)  % Iterate over rows of kpointPath
    point1 = kpointPath{i, 1};
    point2 = kpointPath{i, 2};

    % Check if point1 is defined in kpointDefinitions
    if ~isfield(kpointDefinitions, point1)
        error('Point "%s" found in path but not defined in kpointDefinitions for "%s".', point1, extendedBravais);
    end

    % Check if point2 is defined in kpointDefinitions
    if ~isfield(kpointDefinitions, point2)
        error('Point "%s" found in path but not defined in kpointDefinitions for "%s".', point2, extendedBravais);
    end
end
end
