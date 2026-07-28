classdef Doscar < kssolv.analysis.matgenlab.io.lobster.future.outputs.DOSCAR
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %DOSCAR Legacy DOSCAR interface.
    properties (Dependent, SetAccess = private)
        completedos
        pdos
        tdos
        tdensities
        itdensities
    end
    methods
        function obj = Doscar(doscar, is_lcfo, varargin)
            blank = nargin == 0;
            if blank, doscar = []; end
            if nargin < 1 || isempty(doscar), doscar = "DOSCAR.lobster"; end
            if nargin < 2 || isempty(is_lcfo), is_lcfo = false; end
            if blank, constructorArguments = {};
            else, constructorArguments = {doscar, false}; end
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs.DOSCAR( ...
                constructorArguments{:});
            if blank, return; end
            obj.is_lcfo = is_lcfo;
            if ~isempty(varargin), obj.structure = varargin{end}; end
            obj.parse_file();
        end
        function value = get.completedos(obj)
            value = struct("structure", obj.structure, "total_dos", obj.total_dos, ...
                "pdos", obj.projected_dos);
        end
        function value = get.pdos(obj), value = obj.projected_dos; end
        function value = get.tdos(obj), value = obj.total_dos; end
        function value = get.tdensities(obj), value = obj.total_dos.densities; end
        function value = get.itdensities(obj)
            value = obj.integrated_total_dos.densities;
        end
    end
end
