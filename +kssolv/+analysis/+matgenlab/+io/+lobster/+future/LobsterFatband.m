classdef LobsterFatband
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %LOBSTERFATBAND Typed value container for a FATBAND projection.
    properties
        center (1,1) string = ""
        orbital (1,1) string = ""
        energies (1,1) struct = struct()
        projections (1,1) struct = struct()
    end
end
