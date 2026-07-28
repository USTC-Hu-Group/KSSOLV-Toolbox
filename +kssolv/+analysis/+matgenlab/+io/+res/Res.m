classdef Res
    %RES Parsed representation of a ShelX/AIRSS RES file.

    properties (SetAccess = private)
        TITL = []
        REMS (1,:) string = strings(1,0)
        CELL (1,1) kssolv.analysis.matgenlab.io.res.ResCELL = ...
            kssolv.analysis.matgenlab.io.res.ResCELL()
        SFAC (1,1) kssolv.analysis.matgenlab.io.res.ResSFAC = ...
            kssolv.analysis.matgenlab.io.res.ResSFAC()
    end

    methods
        function obj = Res(title, rems, cellRecord, sfac)
            if nargin == 0, return; end
            if ~isempty(title) && ~isa(title, ...
                    "kssolv.analysis.matgenlab.io.res.AirssTITL")
                error("KSSOLV:Matgenlab:Res:TITL", ...
                    "TITL must be empty or an AirssTITL object.");
            end
            obj.TITL = title;
            obj.REMS = reshape(string(rems), 1, []);
            obj.CELL = cellRecord;
            obj.SFAC = sfac;
        end

        function value = string(obj)
            if isempty(obj.TITL), lines = "TITL";
            else, lines = string(obj.TITL);
            end
            if ~isempty(obj.REMS)
                lines = [lines, "REM " + obj.REMS];
            end
            lines = [lines, string(obj.CELL), "LATT -1"];
            value = strjoin(lines, newline) + newline + string(obj.SFAC);
        end

        function value = char(obj), value = char(string(obj)); end

        function value = as_dict(obj)
            title = [];
            if ~isempty(obj.TITL), title = obj.TITL.as_dict(); end
            value = struct("TITL", title, "REMS", obj.REMS, ...
                "CELL", obj.CELL.as_dict(), ...
                "SFAC", obj.SFAC.as_dict());
        end
    end

    methods (Static)
        function obj = from_dict(value)
            title = [];
            if isfield(value, "TITL") && ~isempty(value.TITL)
                title = ...
                    kssolv.analysis.matgenlab.io.res.AirssTITL. ...
                    from_dict(value.TITL);
            end
            obj = kssolv.analysis.matgenlab.io.res.Res(title, ...
                value.REMS, ...
                kssolv.analysis.matgenlab.io.res.ResCELL. ...
                from_dict(value.CELL), ...
                kssolv.analysis.matgenlab.io.res.ResSFAC. ...
                from_dict(value.SFAC));
        end
    end
end
