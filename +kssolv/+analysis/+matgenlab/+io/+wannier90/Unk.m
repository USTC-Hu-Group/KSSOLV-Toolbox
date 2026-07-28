classdef Unk
    %UNK Wannier90 UNK wavefunction data and Fortran-record I/O.

    properties
        ik (1, 1) double
    end

    properties (SetAccess = private)
        is_noncollinear (1, 1) logical = false
        nbnd (1, 1) double = 0
        ng (1, 3) double = [0, 0, 0]
    end

    properties (Dependent)
        data
    end

    properties (Access = private)
        data_ double = complex([])
    end

    methods
        function obj = Unk(ik, data)
            arguments
                ik (1, 1) double {mustBeInteger}
                data {mustBeNumeric}
            end
            obj.ik = ik;
            obj.data = data;
        end

        function value = get.data(obj)
            value = obj.data_;
        end

        function obj = set.data(obj, value)
            dimensions = size(value);
            rank = ndims(value);
            if ~any(rank == [4, 5])
                error("KSSOLV:Matgenlab:Wannier90:InvalidDataShape", ...
                    "Invalid data shape; expected (nbnd,ngx,ngy,ngz) " + ...
                    "or (nbnd,2,ngx,ngy,ngz).");
            end
            if rank == 5 && dimensions(2) ~= 2
                error("KSSOLV:Matgenlab:Wannier90:InvalidSpinorShape", ...
                    "Invalid noncollinear data; the second dimension must be 2.");
            end
            obj.data_ = complex(double(value));
            obj.is_noncollinear = rank == 5;
            obj.nbnd = dimensions(1);
            obj.ng = dimensions(end - 2:end);
        end

        function write_file(obj, filename)
            [fid, message] = fopen(filename, "w", "ieee-le");
            if fid < 0
                error("KSSOLV:Matgenlab:Wannier90:Open", ...
                    "Unable to open '%s': %s", string(filename), message);
            end
            cleanup = onCleanup(@() fclose(fid));
            writeIntegerRecord(fid, [obj.ng, obj.ik, obj.nbnd]);
            for band = 1:obj.nbnd
                if obj.is_noncollinear
                    writeComplexRecord(fid, reshape( ...
                        obj.data_(band, 1, :, :, :), obj.ng));
                    writeComplexRecord(fid, reshape( ...
                        obj.data_(band, 2, :, :, :), obj.ng));
                else
                    writeComplexRecord(fid, reshape( ...
                        obj.data_(band, :, :, :), obj.ng));
                end
            end
            clear cleanup
        end

        function text = char(obj)
            text = sprintf("Unk(ik=%d, nbnd=%d, ncl=%s, " + ...
                "ngx=%d, ngy=%d, ngz=%d)", obj.ik, obj.nbnd, ...
                string(obj.is_noncollinear), obj.ng);
        end

        function text = string(obj)
            text = string(char(obj));
        end

        function tf = eq(obj, other)
            if ~isa(other, class(obj))
                tf = false;
                return
            end
            tf = isequal(obj.ng, other.ng) && obj.ik == other.ik && ...
                obj.is_noncollinear == other.is_noncollinear && ...
                obj.nbnd == other.nbnd && ...
                all(abs(obj.data_ - other.data_) <= ...
                1e-4 + 1e-5 .* abs(other.data_), "all");
        end

        function tf = ne(obj, other)
            tf = ~(obj == other);
        end
    end

    methods (Static)
        function obj = from_file(filename)
            [fid, byteOrder] = openFortranFile(filename);
            cleanup = onCleanup(@() fclose(fid));
            marker = fread(fid, 1, "uint32=>double");
            if isempty(marker) || marker ~= 20
                error("KSSOLV:Matgenlab:Wannier90:Header", ...
                    "UNK header must contain five int32 values.");
            end
            header = fread(fid, 5, "int32=>double").';
            finish = fread(fid, 1, "uint32=>double");
            if numel(header) ~= 5 || finish ~= marker
                error("KSSOLV:Matgenlab:Wannier90:FortranRecord", ...
                    "Malformed UNK header record.");
            end
            ng = header(1:3);
            ik = header(4);
            nbnd = header(5);
            expectedBytes = 16 * prod(ng);
            records = {};
            while true
                marker = fread(fid, 1, "uint32=>double");
                if isempty(marker), break; end
                if marker ~= expectedBytes
                    error("KSSOLV:Matgenlab:Wannier90:RecordSize", ...
                        "Unexpected UNK wavefunction record size.");
                end
                values = fread(fid, marker / 8, "double=>double");
                finish = fread(fid, 1, "uint32=>double");
                if numel(values) ~= marker / 8 || finish ~= marker
                    error("KSSOLV:Matgenlab:Wannier90:FortranRecord", ...
                        "Malformed UNK wavefunction record.");
                end
                records{end + 1} = complex(values(1:2:end), ...
                    values(2:2:end)); %#ok<AGROW>
            end
            clear cleanup
            if numel(records) == nbnd
                data = complex(zeros([nbnd, ng]));
                for band = 1:nbnd
                    data(band, :, :, :) = reshape(records{band}, ...
                        [1, ng]);
                end
            elseif numel(records) == 2 * nbnd
                data = complex(zeros([nbnd, 2, ng]));
                for band = 1:nbnd
                    data(band, 1, :, :, :) = reshape( ...
                        records{2 * band - 1}, [1, 1, ng]);
                    data(band, 2, :, :, :) = reshape( ...
                        records{2 * band}, [1, 1, ng]);
                end
            else
                error("KSSOLV:Matgenlab:Wannier90:BandCount", ...
                    "UNK contains %d records for %d bands.", ...
                    numel(records), nbnd);
            end
            obj = kssolv.analysis.matgenlab.io.wannier90.Unk(ik, data);
            if byteOrder == "big"
                % Retain the branch as an explicit compatibility assertion.
                obj.ik = ik;
            end
        end
    end
end

function [fid, byteOrder] = openFortranFile(filename)
[fid, message] = fopen(filename, "r", "ieee-le");
if fid < 0
    error("KSSOLV:Matgenlab:Wannier90:Open", ...
        "Unable to open '%s': %s", string(filename), message);
end
marker = fread(fid, 1, "uint32=>double");
frewind(fid);
if marker == 20
    byteOrder = "little";
    return
end
fclose(fid);
[fid, message] = fopen(filename, "r", "ieee-be");
if fid < 0
    error("KSSOLV:Matgenlab:Wannier90:Open", ...
        "Unable to open '%s': %s", string(filename), message);
end
marker = fread(fid, 1, "uint32=>double");
frewind(fid);
if marker ~= 20
    fclose(fid);
    error("KSSOLV:Matgenlab:Wannier90:Header", ...
        "File is not a supported Fortran sequential UNK file.");
end
byteOrder = "big";
end

function writeIntegerRecord(fid, values)
values = int32(values);
marker = uint32(4 * numel(values));
fwrite(fid, marker, "uint32");
fwrite(fid, values, "int32");
fwrite(fid, marker, "uint32");
end

function writeComplexRecord(fid, values)
values = values(:);
interleaved = zeros(2 * numel(values), 1);
interleaved(1:2:end) = real(values);
interleaved(2:2:end) = imag(values);
marker = uint32(8 * numel(interleaved));
fwrite(fid, marker, "uint32");
fwrite(fid, interleaved, "double");
fwrite(fid, marker, "uint32");
end
