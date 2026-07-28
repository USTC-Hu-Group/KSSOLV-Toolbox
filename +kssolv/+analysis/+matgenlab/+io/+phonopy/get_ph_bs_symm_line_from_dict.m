function bands=get_ph_bs_symm_line_from_dict(data,hasNac,labelsDict)
%GET_PH_BS_SYMM_LINE_FROM_DICT Decode phonopy band.yaml data.
if nargin<2||isempty(hasNac),hasNac=false;end
if nargin<3,labelsDict=[];end
import kssolv.analysis.matgenlab.io.phonopy.phonopy_field
import kssolv.analysis.matgenlab.io.phonopy.phonopy_records
structure=kssolv.analysis.matgenlab.io.phonopy. ...
    get_structure_from_dict(data);
phonons=phonopy_records(phonopy_field(data,"phonon"));
qpoints=zeros(numel(phonons),3);
firstBands=phonopy_records(phonopy_field(phonons{1},"band"));
frequencies=zeros(numel(firstBands),numel(phonons));
if isfield(firstBands{1},"eigenvector")
    eigen=complex(zeros(numel(firstBands), ...
        numel(phonons),structure.num_sites,3));
else
    eigen=[];
end
yamlLabels=containers.Map("KeyType","char","ValueType","any");
masses=structure.site_properties.phonopy_masses;
if iscell(masses),masses=cell2mat(masses);end
for pointIndex=1:numel(phonons)
    point=phonons{pointIndex};
    qpoint=reshape(double(phonopy_field(point,"q-position")),1,3);
    qpoints(pointIndex,:)=qpoint;
    pointBands=phonopy_records(phonopy_field(point,"band"));
    for bandIndex=1:numel(pointBands)
        record=pointBands{bandIndex};
        frequencies(bandIndex,pointIndex)= ...
            double(phonopy_field(record,"frequency"));
        if isfield(record,"eigenvector")
            raw=double(record.eigenvector);
            for atomIndex=1:structure.num_sites
                vector=complex( ...
                    reshape(raw(atomIndex,:,1),1,3), ...
                    reshape(raw(atomIndex,:,2),1,3));
                eigen(bandIndex,pointIndex,atomIndex,:)= ...
                    kssolv.analysis.matgenlab.io.phonopy. ...
                    eigvec_to_eigdispl(vector,qpoint, ...
                    structure(atomIndex).frac_coords,double(masses(atomIndex)));
            end
        end
    end
    if isfield(point,"label")
        yamlLabels(char(string(point.label)))=qpoint;
    end
end
reciprocal=kssolv.analysis.matgenlab.core.Lattice( ...
    double(phonopy_field(data,"reciprocal_lattice")));
if isempty(labelsDict),labelsDict=yamlLabels;end
bands=kssolv.analysis.matgenlab.phonon. ...
    PhononBandStructureSymmLine( ...
    qpoints,frequencies,reciprocal,logical(hasNac),eigen, ...
    labelsDict,false,structure);
end
