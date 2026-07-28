classdef SOCSpillage
    %SOCSPILLAGE Spin-orbit spillage topological-screening criterion.

    properties
        wf_noso (1,1) string = ""
        wf_so (1,1) string = ""
    end

    methods
        function obj = SOCSpillage(wfNoso, wfSo)
            if nargin >= 1, obj.wf_noso = string(wfNoso); end
            if nargin >= 2, obj.wf_so = string(wfSo); end
        end

        function gammaMax = overlap_so_spinpol(obj)
            noSo = kssolv.analysis.matgenlab.io.vasp.Wavecar(obj.wf_noso);
            so = kssolv.analysis.matgenlab.io.vasp.Wavecar(obj.wf_so);
            if noSo.spin ~= 2
                error("KSSOLV:Matgenlab:SOCSpillage:NonSpinPolarized", ...
                    "The non-SOC WAVECAR must contain two spin channels.");
            end
            if so.spin ~= 1 || ...
                    ~startsWith(lower(string(so.vasp_type)), "n")
                error("KSSOLV:Matgenlab:SOCSpillage:NonSpinor", ...
                    "The SOC WAVECAR must contain noncollinear spinors.");
            end

            matches = cell(noSo.nk, 1);
            occupied = zeros(noSo.nk, 3);
            matchCount = 0;
            for noIndex = 1:noSo.nk
                differences = max(abs(so.kpoints - ...
                    noSo.kpoints(noIndex, :)), [], 2);
                soIndices = find(differences < 1e-7);
                matches{noIndex} = reshape(soIndices, 1, []);
                if isempty(soIndices), continue; end
                matchCount = matchCount + numel(soIndices);
                up = find(noSo.band_energy{1, noIndex}(:, 3) < 0.5, ...
                    1) - 1;
                down = find(noSo.band_energy{2, noIndex}(:, 3) < 0.5, ...
                    1) - 1;
                if isempty(up), up = noSo.nb; end
                if isempty(down), down = noSo.nb; end
                occupied(noIndex, :) = [up, down, up + down];
            end
            if matchCount == 0
                error("KSSOLV:Matgenlab:SOCSpillage:NoCommonKpoints", ...
                    "The WAVECAR files have no matching k-points.");
            end
            % Preserve pymatgen/JARVIS ordering semantics: the occupation
            % table contains one row for every matched k-point pair, while
            % the later coefficient loop indexes it by the non-SOC k-point.
            occupationRows = zeros(matchCount, 3);
            occupationIndex = 0;
            for noIndex = 1:noSo.nk
                for unused = matches{noIndex}
                    occupationIndex = occupationIndex + 1;
                    occupationRows(occupationIndex, :) = ...
                        occupied(noIndex, :);
                end
            end

            gamma = nan(matchCount, 1);
            gammaIndex = 0;
            for noIndex = 1:noSo.nk
                if isempty(matches{noIndex}), continue; end
                nUp = occupationRows(noIndex, 1);
                nDown = occupationRows(noIndex, 2);
                nTotal = occupationRows(noIndex, 3);
                for soIndex = matches{noIndex}
                    gammaIndex = gammaIndex + 1;
                    noSize = numel(noSo.coeffs{1, noIndex, 1});
                    soCoefficients = so.coeffs{soIndex, 1};
                    soSize = numel(soCoefficients);
                    vectorSize = min(2 * noSize, soSize);
                    halfSize = floor(vectorSize / 2);
                    if numel(noSo.coeffs{2, noIndex, 1}) ~= halfSize
                        continue
                    end

                    noSocVectors = complex(zeros(vectorSize, nTotal));
                    socVectors = complex(zeros(vectorSize, nTotal));
                    for band = 1:nUp
                        vector = noSo.coeffs{1, noIndex, band};
                        noSocVectors(1:halfSize, band) = ...
                            vector(1:halfSize);
                    end
                    for band = 1:nDown
                        vector = noSo.coeffs{2, noIndex, band};
                        noSocVectors(halfSize + 1:vectorSize, nUp + band) = ...
                            vector(1:halfSize);
                    end
                    for band = 1:nTotal
                        vector = so.coeffs{soIndex, band};
                        socVectors(1:halfSize, band) = ...
                            reshape(vector(1, 1:halfSize), [], 1);
                        socVectors(halfSize + 1:vectorSize, band) = ...
                            reshape(vector(2, 1:halfSize), [], 1);
                    end
                    [noBasis, ~] = ...
                        kssolv.analysis.matgenlab.analysis.topological. ...
                        SOCSpillage.orth(noSocVectors);
                    [soBasis, ~] = ...
                        kssolv.analysis.matgenlab.analysis.topological. ...
                        SOCSpillage.orth(socVectors);
                    overlap = noBasis' * soBasis;
                    gamma(gammaIndex) = nTotal - ...
                        sum(abs(overlap).^2, "all");
                end
            end
            if all(isnan(gamma))
                error("KSSOLV:Matgenlab:SOCSpillage:CoefficientMismatch", ...
                    "No compatible coefficient sets were found.");
            end
            gammaMax = max(real(gamma), [], "omitnan");
        end
    end

    methods (Static)
        function close = isclose(first, second, relativeTolerance)
            if nargin < 3, relativeTolerance = 1e-7; end
            close = abs(first - second) < relativeTolerance;
        end

        function [basis, rankValue] = orth(matrix)
            [left, singularValues, ~] = svd(matrix, "econ");
            singularValues = diag(singularValues);
            if isempty(singularValues)
                tolerance = 0;
            else
                tolerance = max(size(matrix)) * ...
                    max(singularValues) * eps;
            end
            rankValue = sum(singularValues > tolerance);
            basis = left(:, 1:rankValue);
        end
    end
end
