function generateBandPathData()
%GENERATEBANDPATHDATA Clone and parse band path data from the seekpath repository.
%
% This function retrieves and processes band path data from the 'seekpath' GitHub repository. 
% Specifically, it:
%   1. Checks if the 'seekpath' repository is present in a parent directory; if not, it clones the repository.
%   2. Navigates to the 'band_path_data' directory within 'seekpath', where various subfolders contain 
%      reference data files (e.g., 'points', 'path', 'k_vector_parameters').
%   3. Reads and structures these data files into a MATLAB struct, organizing the information by subfolder.
%   4. Saves the resulting struct to 'BandPathData.mat' in the '+data' directory.
%
% The output MAT file serves as a convenient dataset for high-symmetry k-point paths, points, and parameters,
% which can be used in subsequent workflows (e.g., band structure calculations).

% Get the current script's folder
currentFolder = fileparts(mfilename('fullpath'));
parentFolder = fileparts(fileparts(currentFolder));
seekpathFolder = fullfile(parentFolder, 'seekpath');

% Check if 'seekpath' folder exists; if not, clone the repository
if ~exist(seekpathFolder, 'dir')
    disp('Cloning seekpath repository...');
    status = system(sprintf('git clone https://github.com/giovannipizzi/seekpath.git "%s"', seekpathFolder));
    if status ~= 0
        error('Failed to clone seekpath repository. Please check your Git installation and internet connection.');
    end
end

% Set the root folder for BandPathData
bandPathDataFolder = fullfile(seekpathFolder, 'seekpath', 'hpkot', 'band_path_data');
if ~exist(bandPathDataFolder, 'dir')
    error('BandPathData directory not found in seekpath.');
end

% Ensure the 'data' directory exists; if not, create it
dataFolder = fullfile(parentFolder, '+seekpath', '+data');
if ~exist(dataFolder, 'dir')
    mkdir(dataFolder);
end

% Initialize structure to hold all data
bandPathData = struct();

% Process each subfolder in bandPathDataFolder
subfolders = dir(bandPathDataFolder);
for i = 1:length(subfolders)
    if subfolders(i).isdir && ~startsWith(subfolders(i).name, '.')
        subfolderPath = fullfile(bandPathDataFolder, subfolders(i).name);
        bandPathData.(subfolders(i).name) = readSubfolderData(subfolderPath);
    end
end

% Save the structure to a .mat file
outputFileName = fullfile(dataFolder, 'BandPathData.mat');
save(outputFileName, 'bandPathData', '-v7.3');

disp('Band path data has been saved to BandPathData.mat.');
end

function dataStruct = readSubfolderData(folderPath)
% Read data files from a subfolder and store them in a structure.

dataStruct = struct();

% Get list of files in the subfolder
files = dir(folderPath);

for i = 1:length(files)
    if ~files(i).isdir
        fileName = files(i).name;
        [~, name, ~] = fileparts(fileName);
        filePath = fullfile(folderPath, fileName);
        fileContents = readFileContents(filePath);

        if strcmp(name, 'points')
            % Split the contents by lines, then by spaces
            lines = splitlines(strtrim(fileContents));
            pointsStruct = struct();
            for j = 1:length(lines)
                if isempty(lines{j})
                    continue;
                end
                parts = split(strtrim(lines{j}), ' ');
                pointName = parts{1};
                coordinates = parts(2:end);
                pointsStruct.(pointName) = coordinates;
            end
            dataStruct.(name) = pointsStruct;
        elseif strcmp(name, 'path')
            % Split lines and convert to Nx2 cell array
            lines = splitlines(strtrim(fileContents));
            pathArray = cell(length(lines), 2);
            for j = 1:length(lines)
                if isempty(lines{j})
                    continue;
                end
                parts = split(strtrim(lines{j}), ' ');
                if numel(parts) ~= 2
                    error('Invalid path format in line: %s. Each line must contain exactly two points.', lines{j});
                end
                pathArray(j, :) = parts';
            end
            dataStruct.(name) = pathArray;
        elseif strcmp(name, 'k_vector_parameters')
            % Convert to an Nx2 cell array
            lines = splitlines(strtrim(fileContents));
            cellArray = cell(length(lines), 2);
            rowIndex = 1;

            for j = 1:length(lines)
                if isempty(strtrim(lines{j}))
                    continue; % Skip empty lines
                end
                parts = split(strtrim(lines{j}), ' ');
                if numel(parts) ~= 2
                    error('Invalid format in line: %s. Each line must contain exactly two entries.', lines{j});
                end
                cellArray(rowIndex, :) = parts';
                rowIndex = rowIndex + 1;
            end

            % Remove any pre-allocated empty rows
            cellArray = cellArray(1:rowIndex-1, :);
            dataStruct.(name) = cellArray;
        else
            % Default behavior for other types
            dataStruct.(name) = fileContents;
        end
    end
end
end

function lines = readFileContents(filePath)
% Read the contents of a file and return as a cell array of lines.

fid = fopen(filePath, 'r');
if fid == -1
    error('Failed to open file: %s', filePath);
end

lines = {};
tline = fgetl(fid);
while ischar(tline)
    lines{end+1} = tline; %#ok<AGROW>
    tline = fgetl(fid);
end
fclose(fid);
end
