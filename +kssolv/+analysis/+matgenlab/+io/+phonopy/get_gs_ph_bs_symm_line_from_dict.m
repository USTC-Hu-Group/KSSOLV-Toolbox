function result=get_gs_ph_bs_symm_line_from_dict( ...
        data,structure,structurePath,labelsDict,fit)
%GET_GS_PH_BS_SYMM_LINE_FROM_DICT Decode phonopy Gruneisen path YAML.
if nargin<2,structure=[];end
if nargin<3,structurePath=[];end
if nargin<4,labelsDict=[];end
if nargin<5||isempty(fit),fit=false;end
if ~isempty(structurePath)&&isempty(structure)
    structure=kssolv.analysis.matgenlab.core.Structure. ...
        from_file(structurePath,"poscar");
elseif isempty(structure)
    try
        structure=kssolv.analysis.matgenlab.io.phonopy. ...
            get_structure_from_dict(data);
    catch
        error("KSSOLV:Matgenlab:Phonopy:Structure", ...
            "Please provide a structure or structure path");
    end
end
paths=kssolv.analysis.matgenlab.io.phonopy.phonopy_records( ...
    kssolv.analysis.matgenlab.io.phonopy.phonopy_field(data,"path"));
qpoints=zeros(0,3);frequencies=zeros(0,0);gruneisen=zeros(0,0);
yamlLabels=containers.Map("KeyType","char","ValueType","any");
for pathIndex=1:numel(paths)
    phonons=kssolv.analysis.matgenlab.io.phonopy.phonopy_records( ...
        kssolv.analysis.matgenlab.io.phonopy. ...
        phonopy_field(paths{pathIndex},"phonon"));
    pathQ=zeros(numel(phonons),3);
    firstBands=kssolv.analysis.matgenlab.io.phonopy.phonopy_records( ...
        kssolv.analysis.matgenlab.io.phonopy. ...
        phonopy_field(phonons{1},"band"));
    pathFrequency=zeros(numel(firstBands),numel(phonons));
    pathGruneisen=zeros(size(pathFrequency));
    for pointIndex=1:numel(phonons)
        point=phonons{pointIndex};
        pathQ(pointIndex,:)=reshape(double( ...
            kssolv.analysis.matgenlab.io.phonopy. ...
            phonopy_field(point,"q-position")),1,3);
        bands=kssolv.analysis.matgenlab.io.phonopy.phonopy_records( ...
            kssolv.analysis.matgenlab.io.phonopy. ...
            phonopy_field(point,"band"));
        for bandIndex=1:numel(bands)
            pathFrequency(bandIndex,pointIndex)=double( ...
                kssolv.analysis.matgenlab.io.phonopy. ...
                phonopy_field(bands{bandIndex},"frequency"));
            pathGruneisen(bandIndex,pointIndex)=double( ...
                kssolv.analysis.matgenlab.io.phonopy. ...
                phonopy_field(bands{bandIndex},"gruneisen"));
        end
        if isfield(point,"label")
            yamlLabels(char(string(point.label)))=pathQ(pointIndex,:);
        end
    end
    if fit
        pathGruneisen=fitGammaDivergence(pathQ,pathGruneisen);
    end
    qpoints=[qpoints;pathQ]; %#ok<AGROW>
    frequencies=[frequencies,pathFrequency]; %#ok<AGROW>
    gruneisen=[gruneisen,pathGruneisen]; %#ok<AGROW>
end
if isempty(labelsDict),labelsDict=yamlLabels;end
result=kssolv.analysis.matgenlab.phonon. ...
    GruneisenPhononBandStructureSymmLine( ...
    qpoints,frequencies,gruneisen, ...
    structure.lattice.reciprocal_lattice,[],labelsDict,false,structure);
end

function values=fitGammaDivergence(qpoints,values)
% Reproduce the upstream intent: only replace strong terminal divergences.
if norm(qpoints(1,:))<1e-12
    values=fliplr(values);
    qpoints=flipud(qpoints);
    reverse=true;
else
    reverse=false;
end
if norm(qpoints(end,:))<1e-12 && size(values,2)>=7
    count=size(values,2);
    start=max(3,floor(0.9*count)+1);
    for pointIndex=start:count
        for bandIndex=1:size(values,1)
            denominator=abs(values(bandIndex,pointIndex-2)- ...
                values(bandIndex,pointIndex-1));
            if denominator>0 && abs(values(bandIndex,pointIndex)- ...
                    values(bandIndex,pointIndex-1))/denominator>2
                known=1:pointIndex-1;
                degree=min(5,numel(known)-1);
                local=known(max(1,end-degree):end);
                localCoordinates=0:numel(local)-1;
                coefficients=polyfit(localCoordinates, ...
                    values(bandIndex,local),degree);
                values(bandIndex,pointIndex)= ...
                    polyval(coefficients,numel(local));
            end
        end
    end
end
if reverse,values=fliplr(values);end
end
