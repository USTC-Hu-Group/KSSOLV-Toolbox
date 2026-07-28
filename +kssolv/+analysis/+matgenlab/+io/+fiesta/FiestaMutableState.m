classdef FiestaMutableState < handle
    %FIESTAMUTABLESTATE Reference storage for Python-style mutator methods.

    properties
        correlation_grid = struct()
        Exc_DFT_option = struct()
        cohsex_options = struct()
        GW_options = struct()
        bse_tddft_options = struct()
        executor = []
        mpi_procs (1,1) double = NaN
    end
end
