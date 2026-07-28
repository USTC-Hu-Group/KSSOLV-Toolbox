classdef WSWQ < kssolv.analysis.matgenlab.util.MSONable
    %WSWQ Wavefunction-overlap matrix reader.
    properties
        nspin (1,1) double = 0
        nkpoints (1,1) double = 0
        nbands (1,1) double = 0
        me_real double = []
        me_imag double = []
    end
    properties (Dependent, SetAccess = private)
        data
    end
    methods
        function obj = WSWQ(nspin,nkpoints,nbands,me_real,me_imag)
            if nargin == 0, return; end
            obj.nspin = nspin;
            obj.nkpoints = nkpoints;
            obj.nbands = nbands;
            obj.me_real = me_real;
            obj.me_imag = me_imag;
        end
        function value = get.data(obj)
            value = complex(obj.me_real,obj.me_imag);
        end
        function value = as_dict(obj)
            value = struct("x_module","pymatgen.io.vasp.outputs", ...
                "x_class","WSWQ","nspin",obj.nspin, ...
                "nkpoints",obj.nkpoints,"nbands",obj.nbands, ...
                "me_real",obj.me_real,"me_imag",obj.me_imag);
        end
        function value = asDict(obj), value = obj.as_dict(); end
    end
    methods (Static)
        function obj = from_file(filename)
            lines = splitlines(string( ...
                kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                readText(filename)));
            spin = 0; point = 0;
            records = zeros(0,6);
            for line = lines.'
                state = regexp(line, ...
                    'spin\s*=\s*(\d+)\s*,\s*kpoint\s*=\s*(\d+)', ...
                    "tokens","once");
                if ~isempty(state)
                    spin = str2double(state{1});
                    point = str2double(state{2});
                    continue
                end
                entry = regexp(line, ...
                    ['i\s*=\s*(\d+)\s*,\s*j\s*=\s*(\d+)\s*:\s*' ...
                    '([-+]?\d*\.\d+)\s+([-+]?\d*\.\d+)'], ...
                    "tokens","once");
                if ~isempty(entry)
                    records(end + 1,:) = [spin,point, ...
                        cellfun(@str2double,entry)]; %#ok<AGROW>
                end
            end
            if isempty(records)
                error("KSSOLV:Matgenlab:WSWQ:Data", ...
                    "No overlap records were found.");
            end
            ns = max(records(:,1));
            nk = max(records(:,2));
            nb = max(records(:,3:4),[],"all");
            if size(records,1) ~= ns*nk*nb*nb
                error("KSSOLV:Matgenlab:WSWQ:Length", ...
                    "WSWQ overlap record count is inconsistent.");
            end
            realData = zeros(ns,nk,nb,nb);
            imagData = zeros(ns,nk,nb,nb);
            for index = 1:size(records,1)
                s = records(index,1); k = records(index,2);
                i = records(index,3); j = records(index,4);
                realData(s,k,i,j) = records(index,5);
                imagData(s,k,i,j) = records(index,6);
            end
            obj = kssolv.analysis.matgenlab.io.vasp.WSWQ( ...
                ns,nk,nb,realData,imagData);
        end
    end
end
