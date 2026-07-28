classdef Dynmat
    %DYNMAT Reader for VASP finite-displacement dynamical matrices.
    properties (SetAccess = private)
        data cell = cell(0,0)
    end
    properties (Dependent, SetAccess = private)
        nspecs
        natoms
        ndisps
        masses
    end
    properties (Access = private)
        nspecs_ (1,1) double = 0
        natoms_ (1,1) double = 0
        ndisps_ (1,1) double = 0
        masses_ double = []
    end
    methods
        function obj = Dynmat(filename)
            if nargin == 0, return; end
            lines = splitlines(string( ...
                kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                readText(filename)));
            lines = lines(strlength(strtrim(lines)) > 0);
            header = sscanf(lines(1), "%d").';
            if numel(header) ~= 3
                error("KSSOLV:Matgenlab:Dynmat:Header", ...
                    "DYNMAT header must contain three integers.");
            end
            obj.nspecs_ = header(1);
            obj.natoms_ = header(2);
            obj.ndisps_ = header(3);
            obj.masses_ = sscanf(lines(2), "%f").';
            obj.data = cell(obj.natoms_, obj.ndisps_);
            blockSize = obj.natoms_ + 1;
            for lineIndex = 3:numel(lines)
                values = sscanf(lines(lineIndex), "%f").';
                offset = lineIndex - 3;
                if mod(offset, blockSize) == 0
                    atom = round(values(1));
                    displacement = round(values(2));
                    obj.data{atom,displacement} = struct( ...
                        "dispvec", values(3:end), ...
                        "dynmat", zeros(0,3));
                else
                    block = obj.data{atom,displacement};
                    block.dynmat(end + 1,:) = values;
                    obj.data{atom,displacement} = block;
                end
            end
        end
        function value = get.nspecs(obj), value = obj.nspecs_; end
        function value = get.natoms(obj), value = obj.natoms_; end
        function value = get.ndisps(obj), value = obj.ndisps_; end
        function value = get.masses(obj), value = obj.masses_; end
        function frequencies = get_phonon_frequencies(obj)
            frequencies = zeros(0,1);
            for atom = 1:size(obj.data,1)
                for displacement = 1:size(obj.data,2)
                    block = obj.data{atom,displacement};
                    if isempty(block), continue; end
                    row = abs(block.dynmat(atom,:));
                    frequencies(end + 1,1) = ...
                        sqrt(sum(row)) * 2 * pi * 15.633302; %#ok<AGROW>
                end
            end
        end
    end
end
