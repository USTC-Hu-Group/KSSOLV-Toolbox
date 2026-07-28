classdef MadelungEnergies < kssolv.analysis.matgenlab.io.lobster.future.LobsterFile
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %MADELUNGENERGIES Madelung-energy output reader.
    methods
        function obj = MadelungEnergies(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.LobsterFile(varargin{:});
        end
        function parse_file(obj)
            linesValue = obj.iterate_lines();
            found = [];
            for index = 1:numel(linesValue)
                values = sscanf(linesValue{index}, "%f").';
                if numel(values) >= 3, found = values; end
            end
            if isempty(found)
                error("KSSOLV:Matgenlab:Lobster:Madelung", ...
                    "Madelung energies were not found.");
            end
            obj.ewald_splitting = found(1);
            obj.madelung_energies_mulliken = found(2);
            obj.madelung_energies_loewdin = found(3);
        end
        function name = get_default_filename(~), name = "MadelungEnergies.lobster"; end
    end
end
