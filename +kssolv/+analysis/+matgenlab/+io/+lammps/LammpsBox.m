classdef LammpsBox < kssolv.analysis.matgenlab.util.MSONable
    %LAMMPSBOX LAMMPS restricted-triclinic simulation box.
    properties
        bounds (3,2) double
        tilt
    end
    properties (SetAccess=private)
        matrix (3,3) double
    end
    properties (Dependent)
        volume
    end
    methods
        function obj = LammpsBox(bounds, tilt)
            if nargin < 2, tilt = []; end
            if ~isequal(size(bounds), [3,2])
                error("KSSOLV:Matgenlab:LammpsBox:Bounds", ...
                    "Expecting a (3, 2) array for bounds.");
            end
            if ~isempty(tilt) && numel(tilt) ~= 3
                error("KSSOLV:Matgenlab:LammpsBox:Tilt", ...
                    "Expecting a (3,) array for box_tilt.");
            end
            obj.bounds = double(bounds);
            obj.tilt = reshape(double(tilt),1,[]);
            obj.matrix = diag(obj.bounds(:,2)-obj.bounds(:,1));
            if ~isempty(tilt)
                obj.matrix(2,1)=tilt(1); obj.matrix(3,1)=tilt(2);
                obj.matrix(3,2)=tilt(3);
            end
        end
        function value = get.volume(obj), value = det(obj.matrix); end
        function text = get_str(obj, significant_figures)
            if nargin < 2, significant_figures = 6; end
            f = "%."+string(significant_figures)+"f %."+ ...
                string(significant_figures)+"f  %slo %shi";
            axes = ["x","y","z"]; lines = strings(3+(~isempty(obj.tilt)),1);
            for k=1:3
                lines(k)=sprintf(f,obj.bounds(k,1),obj.bounds(k,2),axes(k),axes(k));
            end
            if ~isempty(obj.tilt)
                ft = "%."+string(significant_figures)+"f %."+ ...
                    string(significant_figures)+"f %."+ ...
                    string(significant_figures)+"f  xy xz yz";
                lines(4)=sprintf(ft,obj.tilt);
            end
            text = char(join(lines,newline));
        end
        function shift = get_box_shift(obj, i)
            shift = double(i)*obj.matrix;
        end
        function lattice = to_lattice(obj)
            lattice = kssolv.analysis.matgenlab.core.Lattice(obj.matrix);
        end
        function d = as_dict(obj)
            d=kssolv.analysis.matgenlab.util.msonDict( ...
                "pymatgen.io.lammps.data","LammpsBox", ...
                struct("bounds",obj.bounds,"tilt",obj.tilt));
        end
        function d = asDict(obj), d=obj.as_dict(); end
    end
    methods (Static)
        function obj = from_dict(d)
            obj=kssolv.analysis.matgenlab.io.lammps.LammpsBox(d.bounds,d.tilt);
        end
    end
end
