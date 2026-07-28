classdef SitePotentials < kssolv.analysis.matgenlab.io.lobster.future.LobsterFile
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %SITEPOTENTIALS Electrostatic site-potential reader.
    methods
        function obj = SitePotentials(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.LobsterFile(varargin{:});
        end
        function parse_file(obj)
            obj.centers = {};
            obj.site_potentials_mulliken = [];
            obj.site_potentials_loewdin = [];
            linesValue = obj.iterate_lines();
            for index = 1:numel(linesValue)
                line = linesValue{index};
                token = regexp(line, "splitting parameter\s+(\S+)", ...
                    "tokens", "once");
                if ~isempty(token), obj.ewald_splitting = str2double(token{1}); end
                token = regexp(line, ...
                    "Madelung Energy \(eV\)\s*(\S+)\s+(\S+)", ...
                    "tokens", "once");
                if ~isempty(token)
                    obj.madelung_energies_mulliken = str2double(token{1});
                    obj.madelung_energies_loewdin = str2double(token{2});
                end
                token = regexp(line, ...
                    "^\s*(\d+)\s+([A-Za-z]{1,2})\s+(\S+)\s+(\S+)", ...
                    "tokens", "once");
                if ~isempty(token)
                    obj.centers{end + 1} = [token{2}, token{1}];
                    obj.site_potentials_mulliken(end + 1) = str2double(token{3});
                    obj.site_potentials_loewdin(end + 1) = str2double(token{4});
                end
            end
        end
        function name = get_default_filename(~), name = "SitePotentials.lobster"; end
    end
end
