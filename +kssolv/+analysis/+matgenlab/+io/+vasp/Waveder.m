classdef Waveder < kssolv.analysis.matgenlab.util.MSONable
    %WAVEDER Orbital derivatives from binary WAVEDER or formatted WAVEDERF.
    properties
        cder_real double = []
        cder_imag double = []
    end
    properties (Dependent, SetAccess = private)
        cder
        nspin
        nkpoints
        nbands
    end
    methods
        function obj = Waveder(cder_real, cder_imag)
            if nargin == 0, return; end
            if ~isequal(size(cder_real),size(cder_imag))
                error("KSSOLV:Matgenlab:Waveder:Shape", ...
                    "Real and imaginary arrays must have identical sizes.");
            end
            obj.cder_real = double(cder_real);
            obj.cder_imag = double(cder_imag);
        end
        function value = get.cder(obj)
            value = complex(obj.cder_real,obj.cder_imag);
        end
        function value = get.nspin(obj), value = size(obj.cder_real,4); end
        function value = get.nkpoints(obj), value = size(obj.cder_real,3); end
        function value = get.nbands(obj), value = size(obj.cder_real,1); end
        function value = get_orbital_derivative_between_states( ...
                obj, band_i, band_j, kpoint, spin, cart_dir)
            indices = [band_i,band_j,kpoint,spin,cart_dir];
            limits = [size(obj.cder_real,1),size(obj.cder_real,2), ...
                obj.nkpoints,obj.nspin,3];
            if any(indices < 1) || any(indices > limits) || ...
                    any(indices ~= fix(indices))
                error("KSSOLV:Matgenlab:Waveder:Index", ...
                    "WAVEDER indices use MATLAB one-based indexing.");
            end
            value = complex(obj.cder_real(band_i,band_j,kpoint, ...
                spin,cart_dir), obj.cder_imag(band_i,band_j,kpoint, ...
                spin,cart_dir));
        end
        function value = as_dict(obj)
            value = struct("x_module","pymatgen.io.vasp.outputs", ...
                "x_class","Waveder","cder_real",obj.cder_real, ...
                "cder_imag",obj.cder_imag);
        end
        function value = asDict(obj), value = obj.as_dict(); end
    end
    methods (Static)
        function obj = from_formatted(filename)
            text = string(kssolv.analysis.matgenlab.io.vasp. ...
                VaspIOUtils.readText(filename));
            lines = splitlines(text);
            header = sscanf(lines(1),"%d").';
            if numel(header) ~= 3
                error("KSSOLV:Matgenlab:Waveder:FormattedHeader", ...
                    "WAVEDERF header must contain nspin, nkpoints, nbands.");
            end
            ns = header(1); nk = header(2); nb = header(3);
            values = sscanf(strjoin(lines(2:end),newline),"%f");
            if mod(numel(values),12) ~= 0
                error("KSSOLV:Matgenlab:Waveder:FormattedData", ...
                    "WAVEDERF rows must contain twelve numeric columns.");
            end
            matrix = reshape(values,12,[]).';
            selected = matrix(:,[2,5,7:12]);
            realRows = selected(:,[3,5,7]);
            imagRows = selected(:,[4,6,8]);
            expected = ns * nk * nb * nb;
            if size(realRows,1) ~= expected
                error("KSSOLV:Matgenlab:Waveder:FormattedSize", ...
                    "WAVEDERF contains an unexpected number of records.");
            end
            realData = permute(reshape(realRows.', ...
                [3,nb,nb,nk,ns]),[3,2,4,5,1]);
            imagData = permute(reshape(imagRows.', ...
                [3,nb,nb,nk,ns]),[3,2,4,5,1]);
            obj = kssolv.analysis.matgenlab.io.vasp.Waveder( ...
                realData,imagData);
        end

        function obj = from_binary(filename, data_type)
            if nargin < 2, data_type = "complex64"; end
            fid = fopen(filename,"rb","ieee-le");
            if fid < 0
                error("KSSOLV:Matgenlab:Waveder:Open", ...
                    "Could not open WAVEDER file '%s'.",filename);
            end
            cleanup = onCleanup(@()fclose(fid));
            header = kssolv.analysis.matgenlab.io.vasp.Waveder. ...
                readRecord(fid,"int32");
            if numel(header) ~= 4
                error("KSSOLV:Matgenlab:Waveder:BinaryHeader", ...
                    "Invalid WAVEDER binary header.");
            end
            nb = double(header(1));
            nelect = double(header(2));
            nk = double(header(3));
            ns = double(header(4));
            kssolv.analysis.matgenlab.io.vasp.Waveder. ...
                readRecord(fid,"double");
            kssolv.analysis.matgenlab.io.vasp.Waveder. ...
                readRecord(fid,"double");
            switch string(data_type)
                case "complex128"
                    raw = kssolv.analysis.matgenlab.io.vasp.Waveder. ...
                        readRecord(fid,"double");
                    if mod(numel(raw),2) ~= 0
                        error("KSSOLV:Matgenlab:Waveder:ComplexRecord", ...
                            "Complex WAVEDER record has an odd scalar count.");
                    end
                    payload = complex(raw(1:2:end),raw(2:2:end));
                case "complex64"
                    raw = kssolv.analysis.matgenlab.io.vasp.Waveder. ...
                        readRecord(fid,"single");
                    if mod(numel(raw),2) ~= 0
                        error("KSSOLV:Matgenlab:Waveder:ComplexRecord", ...
                            "Complex WAVEDER record has an odd scalar count.");
                    end
                    payload = complex(raw(1:2:end),raw(2:2:end));
                case "float64"
                    payload = kssolv.analysis.matgenlab.io.vasp.Waveder. ...
                        readRecord(fid,"double");
                case "float32"
                    payload = kssolv.analysis.matgenlab.io.vasp.Waveder. ...
                        readRecord(fid,"single");
                otherwise
                    error("KSSOLV:Matgenlab:Waveder:DataType", ...
                        "data_type must be complex128, complex64, " + ...
                        "float64, or float32.");
            end
            expected = 3 * ns * nk * nelect * nb;
            if numel(payload) ~= expected
                error("KSSOLV:Matgenlab:Waveder:BinarySize", ...
                    "Expected %d derivative values, got %d.", ...
                    expected,numel(payload));
            end
            % NumPy's C-order reshape(..., [3,spin,k,elect,band]).T
            % is exactly this MATLAB column-major shape.
            cder = reshape(payload,[nb,nelect,nk,ns,3]);
            obj = kssolv.analysis.matgenlab.io.vasp.Waveder( ...
                real(cder),imag(cder));
            clear cleanup
        end
    end
    methods (Static, Access = private)
        function values = readRecord(fid, precision)
            bytes = uint8([]);
            while true
                prefix = fread(fid,1,"int32=>int32");
                if isempty(prefix)
                    error("KSSOLV:Matgenlab:Waveder:UnexpectedEof", ...
                        "Unexpected end of Fortran record.");
                end
                count = abs(double(prefix));
                chunk = fread(fid,count,"uint8=>uint8");
                suffix = fread(fid,1,"int32=>int32");
                if numel(chunk) ~= count || isempty(suffix) || ...
                        abs(double(suffix)) ~= count
                    error("KSSOLV:Matgenlab:Waveder:Record", ...
                        "Fortran record prefix and suffix do not match.");
                end
                bytes = [bytes;chunk]; %#ok<AGROW>
                if prefix > 0, break; end
            end
            bytesPer = struct("int32",4,"single",4,"double",8);
            width = bytesPer.(precision);
            if mod(numel(bytes),width) ~= 0
                error("KSSOLV:Matgenlab:Waveder:RecordWidth", ...
                    "Fortran record size is incompatible with %s.",precision);
            end
            values = typecast(bytes,precision).';
        end
    end
end
