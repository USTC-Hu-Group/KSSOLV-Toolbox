classdef LobsterBandStructureSymmLine < ...
        kssolv.analysis.matgenlab.electronic_structure.BandStructureSymmLine
    %LOBSTERBANDSTRUCTURESYMMLINE LOBSTER projection-label variant.

    methods
        function obj = LobsterBandStructureSymmLine(varargin)
            obj@kssolv.analysis.matgenlab.electronic_structure. ...
                BandStructureSymmLine(varargin{:});
        end
    end

    methods (Static)
        function obj = from_dict(value)
            if isfield(value,"projections") && ...
                    ~isempty(value.projections) && ...
                    ~lobsterProjectionMappingIsNumeric(value.projections)
                obj = kssolv.analysis.matgenlab.electronic_structure. ...
                    LobsterBandStructureSymmLine.from_old_dict(value);
                return
            end
            value.x_class = "LobsterBandStructureSymmLine";
            base = kssolv.analysis.matgenlab.electronic_structure. ...
                BandStructure.from_dict(value);
            obj = base;
        end

        function obj = from_old_dict(value)
            lattice=kssolv.analysis.matgenlab.core.Lattice. ...
                from_dict(value.lattice_rec);
            labels=kssolv.analysis.matgenlab.electronic_structure. ...
                BandStructure.decodeLabels(value.labels_dict);
            bands=kssolv.analysis.matgenlab.electronic_structure. ...
                BandStructure.decodeSpinMap(value.bands);
            projections=struct();
            structure=[];
            if isfield(value,"projections") && ~isempty(value.projections)
                structure=kssolv.analysis.matgenlab.core.Structure. ...
                    from_dict(value.structure);
                projections=kssolv.analysis.matgenlab. ...
                    electronic_structure.BandStructure. ...
                    decodeLegacyProjectionMap(value.projections,bands,true);
            elseif isfield(value,"structure")
                structure=kssolv.analysis.matgenlab.core.Structure. ...
                    from_dict(value.structure);
            end
            if isnumeric(value.kpoints)
                coordinates=double(value.kpoints);
            else
                coordinates=cell2mat(reshape(value.kpoints,[],1));
            end
            obj=kssolv.analysis.matgenlab.electronic_structure. ...
                LobsterBandStructureSymmLine( ...
                reshape(coordinates,[],3),bands,lattice,value.efermi, ...
                labels,false,structure,projections);
        end
    end
end

function value=lobsterProjectionMappingIsNumeric(input)
if isa(input,"containers.Map")
    keys=input.keys;
    value=isempty(keys) || isnumeric(input(keys{1}));
elseif isstruct(input)
    names=fieldnames(input);
    value=isempty(names) || isnumeric(input.(names{1}));
else
    value=false;
end
end
