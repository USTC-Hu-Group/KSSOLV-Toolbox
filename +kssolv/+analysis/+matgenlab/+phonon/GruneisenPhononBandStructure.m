classdef GruneisenPhononBandStructure < ...
        kssolv.analysis.matgenlab.phonon.PhononBandStructure
    %GRUNEISENPHONONBANDSTRUCTURE Phonon bands with mode Gruneisen values.

    properties (SetAccess=protected)
        gruneisen double
    end

    methods
        function obj=GruneisenPhononBandStructure( ...
                qpoints,frequencies,gruneisenParameters,lattice, ...
                eigendisplacements,labelsDict,coordsAreCartesian,structure)
            if nargin<5,eigendisplacements=[];end
            if nargin<6,labelsDict=[];end
            if nargin<7,coordsAreCartesian=false;end
            if nargin<8,structure=[];end
            obj@kssolv.analysis.matgenlab.phonon.PhononBandStructure( ...
                qpoints,frequencies,lattice,[],eigendisplacements,[], ...
                labelsDict,coordsAreCartesian,structure);
            obj.gruneisen=double(gruneisenParameters);
            if ~isequal(size(obj.gruneisen),size(obj.bands))
                error("KSSOLV:Matgenlab:GruneisenBandStructure:Shape", ...
                    "gruneisenparameters and frequencies must match.");
            end
        end

        function value=as_dict(obj)
            value=as_dict@kssolv.analysis.matgenlab.phonon. ...
                PhononBandStructure(obj);
            value.x_module="pymatgen.phonon.gruneisen";
            value.x_class=gruneisenClassName(obj);
            value=rmfield(value, ...
                {'nac_frequencies','nac_eigendisplacements'});
            value.gruneisen=obj.gruneisen;
        end
        function value=asDict(obj),value=obj.as_dict();end
    end

    methods (Static)
        function obj=from_dict(value)
            [lattice,eigen,structure]=decodeGruneisenBand(value);
            obj=kssolv.analysis.matgenlab.phonon. ...
                GruneisenPhononBandStructure( ...
                value.qpoints,value.bands,value.gruneisen,lattice, ...
                eigen,value.labels_dict,false,structure);
        end
    end
end

function value=gruneisenClassName(obj)
if isa(obj,"kssolv.analysis.matgenlab.phonon." + ...
        "GruneisenPhononBandStructureSymmLine")
    value="GruneisenPhononBandStructureSymmLine";
else
    value="GruneisenPhononBandStructure";
end
end

function [lattice,eigen,structure]=decodeGruneisenBand(value)
lattice=kssolv.analysis.matgenlab.core.Lattice.from_dict(value.lattice_rec);
eigen=value.eigendisplacements.real+1i*value.eigendisplacements.imag;
structure=[];
if isfield(value,"structure")
    structure=kssolv.analysis.matgenlab.core.Structure. ...
        from_dict(value.structure);
end
end
