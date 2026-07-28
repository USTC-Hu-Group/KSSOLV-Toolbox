classdef Eigenval
    %EIGENVAL Reader for VASP eigenvalues and occupations.
    properties (SetAccess = private)
        filename (1,1) string = ""
        occu_tol (1,1) double = 1e-8
        separate_spins (1,1) logical = false
        ispin (1,1) double = 1
        nelect (1,1) double = 0
        nkpt (1,1) double = 0
        nbands (1,1) double = 0
        kpoints double = zeros(0,3)
        kpoints_weights double = zeros(0,1)
        eigenvalues (1,1) struct = struct()
    end
    properties (Dependent, SetAccess = private)
        eigenvalue_band_properties
    end
    methods
        function obj = Eigenval(filename, occu_tol, separate_spins)
            if nargin == 0, return; end
            if nargin < 2 || isempty(occu_tol), occu_tol = 1e-8; end
            if nargin < 3, separate_spins = false; end
            obj.filename = string(filename);
            obj.occu_tol = occu_tol;
            obj.separate_spins = logical(separate_spins);
            lines = splitlines(string( ...
                kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                readText(filename)));
            first = sscanf(lines(1), "%f").';
            obj.ispin = round(first(end));
            header = sscanf(lines(6), "%d").';
            if numel(header) ~= 3
                error("KSSOLV:Matgenlab:Eigenval:Header", ...
                    "EIGENVAL electron/k-point/band header is invalid.");
            end
            obj.nelect = header(1);
            obj.nkpt = header(2);
            obj.nbands = header(3);
            obj.kpoints = zeros(obj.nkpt,3);
            obj.kpoints_weights = zeros(obj.nkpt,1);
            obj.eigenvalues.up = zeros(obj.nkpt,obj.nbands,2);
            if obj.ispin == 2
                obj.eigenvalues.down = zeros(obj.nkpt,obj.nbands,2);
            end
            pointer = 7;
            pointIndex = 0;
            while pointer <= numel(lines) && pointIndex < obj.nkpt
                line = strtrim(lines(pointer));
                pointer = pointer + 1;
                if line == "", continue; end
                values = sscanf(line, "%f").';
                if numel(values) ~= 4, continue; end
                pointIndex = pointIndex + 1;
                obj.kpoints(pointIndex,:) = values(1:3);
                obj.kpoints_weights(pointIndex) = values(4);
                for bandIndex = 1:obj.nbands
                    while pointer <= numel(lines) && ...
                            strlength(strtrim(lines(pointer))) == 0
                        pointer = pointer + 1;
                    end
                    row = sscanf(lines(pointer), "%f").';
                    pointer = pointer + 1;
                    if numel(row) == 3
                        obj.eigenvalues.up(pointIndex,bandIndex,:) = ...
                            row(2:3);
                    elseif numel(row) == 5
                        obj.eigenvalues.up(pointIndex,bandIndex,:) = ...
                            [row(2),row(4)];
                        obj.eigenvalues.down(pointIndex,bandIndex,:) = ...
                            [row(3),row(5)];
                    else
                        error("KSSOLV:Matgenlab:Eigenval:BandRow", ...
                            "Invalid EIGENVAL band row.");
                    end
                end
            end
            if pointIndex ~= obj.nkpt
                error("KSSOLV:Matgenlab:Eigenval:Kpoints", ...
                    "Expected %d k-points, parsed %d.", ...
                    obj.nkpt, pointIndex);
            end
        end

        function value = get.eigenvalue_band_properties(obj)
            spinNames = string(fieldnames(obj.eigenvalues));
            if obj.separate_spins && numel(spinNames) ~= 2
                error("KSSOLV:Matgenlab:Eigenval:SeparateSpins", ...
                    "separate_spins can only be true when ISPIN = 2.");
            end
            if obj.separate_spins
                vbms = zeros(1,2);
                cbms = zeros(1,2);
                direct = false(1,2);
                for spinIndex = 1:2
                    [vbms(spinIndex), cbms(spinIndex), vki, cki] = ...
                        obj.bandEdges(obj.eigenvalues.( ...
                        spinNames(spinIndex)));
                    direct(spinIndex) = vki == cki;
                end
                value = {max(cbms - vbms,0), cbms, vbms, direct};
            else
                vbm = -Inf;
                cbm = Inf;
                vbmK = NaN;
                cbmK = NaN;
                for spinName = spinNames.'
                    [localVbm, localCbm, localVbmK, localCbmK] = ...
                        obj.bandEdges(obj.eigenvalues.(spinName));
                    if localVbm > vbm
                        vbm = localVbm;
                        vbmK = localVbmK;
                    end
                    if localCbm < cbm
                        cbm = localCbm;
                        cbmK = localCbmK;
                    end
                end
                value = {max(cbm-vbm,0), cbm, vbm, vbmK == cbmK};
            end
        end
    end
    methods (Access = private)
        function [vbm, cbm, vbmK, cbmK] = bandEdges(obj, data)
            vbm = -Inf;
            cbm = Inf;
            vbmK = NaN;
            cbmK = NaN;
            for pointIndex = 1:size(data,1)
                for bandIndex = 1:size(data,2)
                    energy = data(pointIndex,bandIndex,1);
                    occupation = data(pointIndex,bandIndex,2);
                    if occupation > obj.occu_tol && energy > vbm
                        vbm = energy;
                        vbmK = pointIndex;
                    elseif occupation <= obj.occu_tol && energy < cbm
                        cbm = energy;
                        cbmK = pointIndex;
                    end
                end
            end
        end
    end
end
