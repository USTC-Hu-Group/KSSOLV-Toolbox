classdef LammpsForceField
    %LAMMPSFORCEFIELD Lightweight validated style/coeff bundle.
    properties
        pair_style=[]; pair_coeff=[]; bond_style=[]; bond_coeff=[]
        angle_style=[]; angle_coeff=[]; dihedral_style=[]; dihedral_coeff=[]
        improper_style=[]; improper_coeff=[]; species=[]
    end
    methods
        function obj=LammpsForceField(options)
            arguments, options.?kssolv.analysis.matgenlab.io.lammps.LammpsForceField, end
            names=fieldnames(options);
            for k=1:numel(names), obj.(names{k})=options.(names{k}); end
            if ischar(obj.species)||isstring(obj.species)
                obj.species=cellstr(split(string(obj.species)));
            end
            kinds=["pair","bond","angle","dihedral","improper"]; found=false;
            for kind=kinds
                coeff=kind+"_coeff"; style=kind+"_style";
                if ~isempty(obj.(coeff))
                    found=true;
                    if isempty(obj.(style))
                        error("KSSOLV:Matgenlab:LammpsForceField:Style", ...
                            "%s must be specified when %s is specified",style,coeff);
                    end
                end
            end
            if ~found
                error("KSSOLV:Matgenlab:LammpsForceField:Coefficients", ...
                    "At least one coefficient set must be specified.");
            end
        end
        function d=as_dict(obj)
            names=properties(obj); d=struct();
            for k=1:numel(names), d.(names{k})=obj.(names{k}); end
        end
    end
    methods (Static)
        function obj=from_dict(d)
            args=namedargs2cell(d);
            obj=kssolv.analysis.matgenlab.io.lammps.LammpsForceField(args{:});
        end
    end
end
