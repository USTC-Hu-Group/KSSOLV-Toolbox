classdef PhonopyAtoms
    %PHONOPYATOMS Native data carrier compatible with phonopy.structure.atoms.
    properties (SetAccess=private)
        symbols (1,:) string
        cell double
        scaled_positions double
        masses (1,:) double
        magnetic_moments
    end
    methods
        function obj=PhonopyAtoms(symbols,cellMatrix,positions,masses,magmoms)
            if nargin<4||isempty(masses)
                masses=zeros(1,numel(symbols));
                for index=1:numel(symbols)
                    element=kssolv.analysis.matgenlab.core.Element( ...
                        string(symbols(index)));
                    masses(index)=element.atomic_mass;
                end
            end
            if nargin<5,magmoms=[];end
            obj.symbols=reshape(string(symbols),1,[]);
            obj.cell=double(cellMatrix);
            obj.scaled_positions=reshape(double(positions),[],3);
            obj.masses=reshape(double(masses),1,[]);
            obj.magnetic_moments=magmoms;
        end
    end
end
