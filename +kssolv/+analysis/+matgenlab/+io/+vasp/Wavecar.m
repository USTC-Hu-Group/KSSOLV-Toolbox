classdef Wavecar < handle
    %WAVECAR Native reader for VASP direct-access WAVECAR files.

    properties
        filename (1,1) string = "WAVECAR"
        vasp_type = []
        spin (1,1) double = 1
        nk (1,1) double = 0
        nb (1,1) double = 0
        encut (1,1) double = 0
        efermi (1,1) double = 0
        a double = zeros(3)
        b double = zeros(3)
        vol (1,1) double = 0
        kpoints double = zeros(0, 3)
        band_energy cell = cell(0)
        Gpoints cell = cell(0)
        coeffs cell = cell(0)
        ng (1,3) double = [0, 0, 0]
    end

    properties (Access = private)
        C_ (1,1) double = 0.262465831
        nbmax_ (1,3) double = [0, 0, 0]
        rtag_ (1,1) double = 0
        recl_ (1,1) double = 0
    end

    methods
        function obj = Wavecar(filename, varargin)
            if nargin < 1 || isempty(filename), filename = "WAVECAR"; end
            options = struct("verbose", false, "precision", "normal", ...
                "vasp_type", []);
            names = fieldnames(options); positional = 1; index = 1;
            while index <= numel(varargin)
                current = varargin{index};
                if (ischar(current) || (isstring(current) && isscalar(current))) ...
                        && any(strcmpi(string(current), string(names)))
                    match = find(strcmpi(string(current), string(names)), 1);
                    options.(names{match}) = varargin{index + 1};
                    index = index + 2;
                else
                    options.(names{positional}) = current;
                    positional = positional + 1; index = index + 1;
                end
            end
            if ~isempty(options.vasp_type)
                initial = extractBefore(lower(string(options.vasp_type)) + "x", 2);
                if ~any(initial == ["s","g","n"])
                    error("KSSOLV:Matgenlab:Wavecar:VaspType", ...
                        "vasp_type must be std, gam, or ncl.");
                end
                obj.vasp_type = char(string(options.vasp_type));
            end
            obj.filename = string(filename);
            obj.readFile(logical(options.verbose), string(options.precision));
        end

        function value = evaluate_wavefunc(obj, kpoint, band, r, spin, spinor)
            if nargin < 5 || isempty(spin), spin = 1; end
            if nargin < 6 || isempty(spinor), spinor = 1; end
            kpoint = obj.index(kpoint, obj.nk, "kpoint");
            band = obj.index(band, obj.nb, "band");
            spin = obj.index(spin, obj.spin, "spin");
            spinor = obj.index(spinor, 2, "spinor");
            vectors = obj.Gpoints{kpoint} + obj.kpoints(kpoint, :);
            phases = (vectors * obj.b) * reshape(double(r), 3, 1);
            coefficients = obj.coefficients(kpoint, band, spin, spinor);
            value = sum(coefficients(:) .* exp(1i * phases(:))) / ...
                sqrt(obj.vol);
        end

        function mesh = fft_mesh(obj, kpoint, band, spin, spinor, shift)
            if nargin < 4 || isempty(spin), spin = 1; end
            if nargin < 5 || isempty(spinor), spinor = 1; end
            if nargin < 6 || isempty(shift), shift = true; end
            kpoint = obj.index(kpoint, obj.nk, "kpoint");
            band = obj.index(band, obj.nb, "band");
            spin = obj.index(spin, obj.spin, "spin");
            spinor = obj.index(spinor, 2, "spinor");
            coefficients = obj.coefficients(kpoint, band, spin, spinor);
            mesh = complex(zeros(obj.ng));
            points = obj.Gpoints{kpoint};
            count = min(size(points, 1), numel(coefficients));
            center = floor(obj.ng / 2) + 1;
            for index = 1:count
                location = points(index, :) + center;
                mesh(location(1), location(2), location(3)) = ...
                    coefficients(index);
            end
            if shift, mesh = ifftshift(mesh); end
        end

        function output = get_parchg(obj, poscar, kpoint, band, varargin)
            options = struct("spin", [], "spinor", [], ...
                "phase", false, "scale", 2);
            names = fieldnames(options); index = 1;
            while index <= numel(varargin)
                match = find(strcmpi(string(varargin{index}), ...
                    string(names)), 1);
                if isempty(match)
                    error("KSSOLV:Matgenlab:Wavecar:Arguments", ...
                        "Unknown get_parchg option.");
                end
                options.(names{match}) = varargin{index + 1};
                index = index + 2;
            end
            kpointIndex = obj.index(kpoint, obj.nk, "kpoint");
            if options.phase && any(abs(obj.kpoints(kpointIndex, :)) > 1e-8)
                warning("KSSOLV:Matgenlab:Wavecar:NonGammaPhase", ...
                    "phase=true is normally meaningful only at Gamma.");
            end
            originalGrid = obj.ng;
            cleanup = onCleanup(@() obj.restoreGrid(originalGrid));
            obj.ng = obj.ng * options.scale;
            count = prod(obj.ng);
            data = struct();
            if obj.spin == 2
                if ~isempty(options.spin)
                    wave = ifftn(obj.fft_mesh(kpoint, band, ...
                        options.spin, 1)) * count;
                    density = abs(conj(wave) .* wave);
                    if options.phase
                        density = sign(real(wave)) .* density;
                    end
                    data.total = density;
                else
                    up = ifftn(obj.fft_mesh(kpoint, band, 1, 1)) * count;
                    down = ifftn(obj.fft_mesh(kpoint, band, 2, 1)) * count;
                    upDensity = abs(conj(up) .* up);
                    downDensity = abs(conj(down) .* down);
                    data.total = upDensity + downDensity;
                    data.diff = upDensity - downDensity;
                end
            else
                if ~isempty(options.spinor)
                    wave = ifftn(obj.fft_mesh(kpoint, band, ...
                        1, options.spinor)) * count;
                    density = abs(conj(wave) .* wave);
                else
                    wave = ifftn(obj.fft_mesh(kpoint, band, 1, 1)) * count;
                    partner = ifftn(obj.fft_mesh(kpoint, band, 1, 2)) * count;
                    density = abs(conj(wave) .* wave) + ...
                        abs(conj(partner) .* partner);
                end
                if options.phase && ...
                        (~startsWith(lower(string(obj.vasp_type)), "n") || ...
                        ~isempty(options.spinor))
                    density = sign(real(wave)) .* density;
                end
                data.total = density;
            end
            clear cleanup
            obj.ng = originalGrid;
            output = kssolv.analysis.matgenlab.io.vasp.Chgcar(poscar, data);
        end

        function write_unks(obj, directory)
            directory = string(directory);
            if isfile(directory)
                error("KSSOLV:Matgenlab:Wavecar:UnkDirectory", ...
                    "UNK destination must be a directory.");
            end
            if ~isfolder(directory), mkdir(directory); end
            count = prod(obj.ng);
            noncollinear = startsWith(lower(string(obj.vasp_type)), "n");
            for point = 1:obj.nk
                if noncollinear
                    outputFile = fullfile(directory, ...
                        sprintf("UNK%05d.NC", point));
                    obj.writeUnkHeader(outputFile, point);
                    identifier = fopen(outputFile, "a", "ieee-le");
                    cleanup = onCleanup(@() fclose(identifier));
                    for band = 1:obj.nb
                        for spinor = 1:2
                            wave = ifftn(obj.fft_mesh(point, band, ...
                                1, spinor)) * count;
                            obj.writeComplexRecord(identifier, wave);
                        end
                    end
                    clear cleanup
                else
                    for spinIndex = 1:obj.spin
                        outputFile = fullfile(directory, ...
                            sprintf("UNK%05d.%d", point, spinIndex));
                        obj.writeUnkHeader(outputFile, point);
                        identifier = fopen(outputFile, "a", "ieee-le");
                        cleanup = onCleanup(@() fclose(identifier));
                        for band = 1:obj.nb
                            wave = ifftn(obj.fft_mesh(point, band, ...
                                spinIndex, 1)) * count;
                            obj.writeComplexRecord(identifier, wave);
                        end
                        clear cleanup
                    end
                end
            end
        end
    end

    methods (Access = private)
        function readFile(obj, verbose, precision)
            identifier = fopen(obj.filename, "r", "ieee-le");
            if identifier < 0
                error("KSSOLV:Matgenlab:Wavecar:Open", ...
                    "Cannot open WAVECAR '%s'.", obj.filename);
            end
            cleanup = onCleanup(@() fclose(identifier));
            header = fread(identifier, 3, "double=>double").';
            if numel(header) ~= 3
                error("KSSOLV:Matgenlab:Wavecar:Header", ...
                    "WAVECAR header is truncated.");
            end
            obj.recl_ = round(header(1));
            obj.spin = round(header(2));
            obj.rtag_ = round(header(3));
            if ~any(obj.rtag_ == [45200,45210,53300,53310])
                error("KSSOLV:Matgenlab:Wavecar:Rtag", ...
                    "Invalid rtag=%d.", obj.rtag_);
            end
            fseek(identifier, obj.recl_, "bof");
            second = fread(identifier, 13, "double=>double").';
            if numel(second) ~= 13
                error("KSSOLV:Matgenlab:Wavecar:Header", ...
                    "WAVECAR second record is truncated.");
            end
            obj.nk = round(second(1)); obj.nb = round(second(2));
            obj.encut = second(3);
            obj.a = reshape(second(4:12), 3, 3).';
            obj.efermi = second(13);
            obj.vol = dot(obj.a(1,:), cross(obj.a(2,:), obj.a(3,:)));
            obj.b = 2 * pi * [cross(obj.a(2,:),obj.a(3,:)); ...
                cross(obj.a(3,:),obj.a(1,:)); ...
                cross(obj.a(1,:),obj.a(2,:))] / obj.vol;
            obj.generateNbmax();
            if startsWith(lower(precision), "n")
                obj.ng = obj.nbmax_ * 3;
            else
                obj.ng = obj.nbmax_ * 4;
            end
            obj.Gpoints = cell(1, obj.nk);
            obj.kpoints = zeros(obj.nk, 3);
            if obj.spin == 2
                obj.coeffs = cell(obj.spin, obj.nk, obj.nb);
                obj.band_energy = cell(obj.spin, obj.nk);
            else
                obj.coeffs = cell(obj.nk, obj.nb);
                obj.band_energy = cell(1, obj.nk);
            end
            offset = 2 * obj.recl_;
            for spinIndex = 1:obj.spin
                for point = 1:obj.nk
                    fseek(identifier, offset, "bof");
                    nplane = round(fread(identifier, 1, "double=>double"));
                    currentK = fread(identifier, 3, "double=>double").';
                    energyRaw = fread(identifier, 3 * obj.nb, ...
                        "double=>double").';
                    energies = reshape(energyRaw, 3, obj.nb).';
                    if spinIndex == 1
                        obj.kpoints(point, :) = currentK;
                    elseif any(abs(obj.kpoints(point,:) - currentK) > 1e-7)
                        error("KSSOLV:Matgenlab:Wavecar:KpointMismatch", ...
                            "Spin channels contain different kpoints.");
                    end
                    if obj.spin == 2
                        obj.band_energy{spinIndex, point} = energies;
                    else
                        obj.band_energy{point} = energies;
                    end
                    [points, extra, extraIndices] = ...
                        obj.generateGpoints(currentK, ...
                        ~isempty(obj.vasp_type) && ...
                        startsWith(lower(string(obj.vasp_type)), "g"));
                    if isempty(obj.vasp_type)
                        [gammaPoints, gammaExtra, gammaIndices] = ...
                            obj.generateGpoints(currentK, true);
                        if size(gammaPoints, 1) == nplane
                            obj.vasp_type = "gam";
                            points = gammaPoints; extra = gammaExtra;
                            extraIndices = gammaIndices;
                        else
                            [points, extra, extraIndices] = ...
                                obj.generateGpoints(currentK, false);
                            if size(points, 1) == nplane
                                obj.vasp_type = "std";
                            else
                                obj.vasp_type = "ncl";
                            end
                        end
                    end
                    if size(points,1) ~= nplane && ...
                            2 * size(points,1) ~= nplane
                        error("KSSOLV:Matgenlab:Wavecar:VaspType", ...
                            "Incorrect vasp_type for WAVECAR plane-wave count.");
                    end
                    obj.Gpoints{point} = [points; extra];
                    recordsUsed = ceil((4 + 3 * obj.nb) / ...
                        (obj.recl_ / 8));
                    offset = offset + recordsUsed * obj.recl_;
                    for band = 1:obj.nb
                        fseek(identifier, offset, "bof");
                        coefficients = obj.readCoefficients(identifier, nplane);
                        if ~isempty(extraIndices)
                            coefficients(extraIndices) = ...
                                coefficients(extraIndices) / sqrt(2);
                            coefficients = [coefficients; ...
                                conj(coefficients(extraIndices))]; %#ok<AGROW>
                        end
                        if startsWith(lower(string(obj.vasp_type)), "n")
                            half = nplane / 2;
                            coefficients = [ ...
                                coefficients(1:half).'; ...
                                coefficients(half+1:end).'];
                        end
                        if obj.spin == 2
                            obj.coeffs{spinIndex, point, band} = coefficients;
                        else
                            obj.coeffs{point, band} = coefficients;
                        end
                        offset = offset + obj.recl_;
                    end
                    if verbose
                        fprintf("WAVECAR spin %d kpoint %d: %d plane waves\n", ...
                            spinIndex, point, nplane);
                    end
                end
            end
            clear cleanup
        end

        function generateNbmax(obj)
            magnitude = vecnorm(obj.b, 2, 2).';
            b = obj.b;
            phi12 = acos(dot(b(1,:),b(2,:))/(magnitude(1)*magnitude(2)));
            triple = dot(b(3,:),cross(b(1,:),b(2,:))) / ...
                (magnitude(3)*norm(cross(b(1,:),b(2,:))));
            first = sqrt(obj.encut*obj.C_)./magnitude;
            first(1:2) = first(1:2)/abs(sin(phi12));
            first(3) = first(3)/abs(triple);
            phi13 = acos(dot(b(1,:),b(3,:))/(magnitude(1)*magnitude(3)));
            triple = dot(b(2,:),cross(b(1,:),b(3,:))) / ...
                (magnitude(2)*norm(cross(b(1,:),b(3,:))));
            second = sqrt(obj.encut*obj.C_)./magnitude;
            second([1,3]) = second([1,3])/abs(sin(phi13));
            second(2) = second(2)/abs(triple);
            phi23 = acos(dot(b(2,:),b(3,:))/(magnitude(2)*magnitude(3)));
            triple = dot(b(1,:),cross(b(2,:),b(3,:))) / ...
                (magnitude(1)*norm(cross(b(2,:),b(3,:))));
            third = sqrt(obj.encut*obj.C_)./magnitude;
            third([2,3]) = third([2,3])/abs(sin(phi23));
            third(1) = third(1)/abs(triple);
            obj.nbmax_ = floor(max([first+1;second+1;third+1],[],1));
        end

        function [points, extra, indices] = generateGpoints(obj, kpoint, gamma)
            maximum = obj.nbmax_;
            if gamma, kmax = maximum(1); else, kmax = 2*maximum(1); end
            points = zeros(0,3); extra = zeros(0,3); indices = zeros(1,0);
            for i = 0:2*maximum(3)
                if i > maximum(3), i3 = i-2*maximum(3)-1; else, i3=i; end
                for j = 0:2*maximum(2)
                    if j > maximum(2), j2=j-2*maximum(2)-1; else, j2=j; end
                    for k = 0:kmax
                        if k > maximum(1), k1=k-2*maximum(1)-1; else, k1=k; end
                        if gamma && (k1==0 && j2<0 || ...
                                k1==0 && j2==0 && i3<0)
                            continue
                        end
                        point = [k1,j2,i3];
                        reciprocal = (kpoint + point) * obj.b;
                        energy = dot(reciprocal,reciprocal) / obj.C_;
                        if obj.encut > energy
                            points(end+1,:) = point; %#ok<AGROW>
                            if gamma && any(point ~= 0)
                                extra(end+1,:) = -point; %#ok<AGROW>
                                indices(end+1) = size(points,1); %#ok<AGROW>
                            end
                        end
                    end
                end
            end
        end

        function coefficients = readCoefficients(obj, identifier, count)
            if any(obj.rtag_ == [45200,53300])
                raw = fread(identifier, 2*count, "single=>double");
            else
                raw = fread(identifier, 2*count, "double=>double");
            end
            if numel(raw) ~= 2*count
                error("KSSOLV:Matgenlab:Wavecar:Truncated", ...
                    "Coefficient record is truncated.");
            end
            coefficients = complex(raw(1:2:end), raw(2:2:end));
        end

        function value = coefficients(obj, point, band, spin, spinor)
            if startsWith(lower(string(obj.vasp_type)), "n")
                matrix = obj.coeffs{point, band};
                value = matrix(spinor, :).';
            elseif obj.spin == 2
                value = obj.coeffs{spin, point, band};
            else
                value = obj.coeffs{point, band};
            end
        end

        function value = index(~, value, count, name)
            if value < 0, value = count + value + 1; end
            validateattributes(value, {'numeric'}, ...
                {'scalar','integer','>=',1,'<=',count}, "", name);
        end

        function restoreGrid(obj, grid), obj.ng = grid; end

        function writeUnkHeader(obj, filename, point)
            identifier = fopen(filename, "w", "ieee-le");
            if identifier < 0
                error("KSSOLV:Matgenlab:Wavecar:UnkWrite", ...
                    "Cannot create '%s'.", filename);
            end
            cleanup = onCleanup(@() fclose(identifier));
            marker = int32(20);
            fwrite(identifier, marker, "int32");
            fwrite(identifier, int32([obj.ng, point, obj.nb]), "int32");
            fwrite(identifier, marker, "int32");
            clear cleanup
        end

        function writeComplexRecord(~, identifier, values)
            flat = values(:);
            raw = zeros(2*numel(flat), 1);
            raw(1:2:end) = real(flat); raw(2:2:end) = imag(flat);
            marker = int32(8*numel(raw));
            fwrite(identifier, marker, "int32");
            fwrite(identifier, raw, "double");
            fwrite(identifier, marker, "int32");
        end
    end
end
