function [cell, positions, atomicNumbers] = simpleReadPoscar(contents)
%SIMPLEREADPOSCAR Processes the contents of a VASP POSCAR file
%
% Input:
%   contents - Cell array where each element is a line from the POSCAR file
%
% Output:
%   cell - 3x3 matrix containing the scaled lattice vectors
%   positions - Nx3 matrix of atomic positions in direct coordinates
%   atomicNumbers - Nx1 vector of atomic numbers corresponding to each atom

% Get the lattice scaling factor
alat = str2double(contents{2});

% Extract and scale the lattice vectors
v1 = sscanf(contents{3}, '%f')' * alat;
v2 = sscanf(contents{4}, '%f')' * alat;
v3 = sscanf(contents{5}, '%f')' * alat;
cell = [v1; v2; v3];

% Get the species and the number of atoms of each species
species = strsplit(strtrim(contents{6}));
numAtoms = sscanf(contents{7}, '%d');

% Check for "direct" specification
if ~strcmpi(strtrim(contents{8}), 'direct')
    error('This simple routine can only handle "direct" POSCARs');
end

% Calculate the total number of atoms for pre-allocation
totalAtoms = sum(numAtoms);

% Pre-allocate arrays for positions and atomic numbers
positions = zeros(totalAtoms, 3);
atomicNumbers = zeros(totalAtoms, 1);

% Counter for lines containing positions
positionLineIndex = 9;
atomIndex = 1;

% Process each species and its corresponding number of atoms
for i = 1:length(species)
    atomNumber = kssolv.analysis.seekpath.utils.getAtomicNumber(species{i});
    num = numAtoms(i);
    for j = 1:num
        atomicNumbers(atomIndex) = atomNumber;
        positions(atomIndex, :) = sscanf(contents{positionLineIndex}, '%f')';
        positionLineIndex = positionLineIndex + 1;
        atomIndex = atomIndex + 1;
    end
end
end
