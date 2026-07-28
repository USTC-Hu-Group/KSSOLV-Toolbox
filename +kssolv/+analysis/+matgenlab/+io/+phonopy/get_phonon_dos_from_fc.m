function result=get_phonon_dos_from_fc( ...
        structure,supercellMatrix,forceConstants, ...
        meshDensity,numDosSteps,varargin)
%GET_PHONON_DOS_FROM_FC Site-projected phonon DOS from force constants.
if nargin<4||isempty(meshDensity),meshDensity=100;end
if nargin<5||isempty(numDosSteps),numDosSteps=200;end
qpoints=kssolv.analysis.matgenlab.io.phonopy. ...
    phonopy_mesh_qpoints(structure,meshDensity);
[frequencies,eigenvectors]= ...
    kssolv.analysis.matgenlab.io.phonopy.phonon_modes_from_fc( ...
    structure,supercellMatrix,forceConstants,qpoints);
minimum=min(frequencies,[],"all");
maximum=max(frequencies,[],"all");
pitch=(maximum-minimum)/numDosSteps;
grid=minimum:pitch:(maximum+pitch*0.1);
sigma=(maximum-minimum)/100;
if sigma<=0,sigma=eps;end
siteDos=zeros(structure.num_sites,numel(grid));
for pointIndex=1:size(qpoints,1)
    vectors=squeeze(eigenvectors(pointIndex,:,:));
    for modeIndex=1:size(frequencies,2)
        gaussian=exp(-0.5*((grid- ...
            frequencies(pointIndex,modeIndex))/sigma).^2)/ ...
            (sqrt(2*pi)*sigma);
        vector=vectors(:,modeIndex);
        for siteIndex=1:structure.num_sites
            rows=(siteIndex-1)*3+(1:3);
            siteDos(siteIndex,:)=siteDos(siteIndex,:)+ ...
                sum(abs(vector(rows)).^2)*gaussian;
        end
    end
end
siteDos=siteDos/size(qpoints,1);
total=kssolv.analysis.matgenlab.phonon.PhononDos( ...
    grid,sum(siteDos,1));
result=kssolv.analysis.matgenlab.phonon.CompletePhononDos( ...
    structure,total,siteDos);
end
