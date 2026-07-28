function [frequencies,eigenvectors]=phonon_modes_from_fc( ...
        structure,supercellMatrix,forceConstants,qpoints)
%PHONON_MODES_FROM_FC Solve mass-weighted dynamical matrices natively.
[~,translations]=kssolv.analysis.matgenlab.io.phonopy. ...
    phonopy_supercell(structure,supercellMatrix);
translationCount=size(translations,1);
atomCount=structure.num_sites;
expected=atomCount*translationCount;
if size(forceConstants,1)~=expected || ...
        size(forceConstants,2)~=expected
    error("KSSOLV:Matgenlab:Phonopy:ForceConstantsShape", ...
        "Force constants size does not match the requested supercell.");
end
masses=zeros(1,atomCount);
for index=1:atomCount
    masses(index)=structure(index).specie.atomic_mass;
end
modeCount=3*atomCount;
frequencies=zeros(size(qpoints,1),modeCount);
eigenvectors=complex(zeros(size(qpoints,1),modeCount,modeCount));
% Phonopy 4.4.0's VASP force-constant conversion constant.
conversion=15.633302300230191;
for pointIndex=1:size(qpoints,1)
    qpoint=qpoints(pointIndex,:);
    dynamical=complex(zeros(modeCount));
    for firstAtom=1:atomCount
        firstIndex=(firstAtom-1)*translationCount+1;
        firstRows=(firstAtom-1)*3+(1:3);
        for secondAtom=1:atomCount
            secondRows=(secondAtom-1)*3+(1:3);
            block=complex(zeros(3));
            deltaBasis=structure(secondAtom).frac_coords- ...
                structure(firstAtom).frac_coords;
            for translationIndex=1:translationCount
                secondIndex=(secondAtom-1)*translationCount+ ...
                    translationIndex;
                phase=shortestVectorPhase( ...
                    deltaBasis+translations(translationIndex,:), ...
                    supercellMatrix,structure.lattice.matrix,qpoint);
                forceBlock=reshape(forceConstants( ...
                    firstIndex,secondIndex,:,:),3,3);
                block=block+forceBlock*phase;
            end
            dynamical(firstRows,secondRows)= ...
                block/sqrt(masses(firstAtom)*masses(secondAtom));
        end
    end
    dynamical=(dynamical+dynamical')/2;
    [vectors,values]=eig(dynamical,"vector");
    values=real(values);
    modeFrequencies=sign(values).*sqrt(abs(values))*conversion;
    [modeFrequencies,order]=sort(modeFrequencies);
    frequencies(pointIndex,:)=modeFrequencies;
    eigenvectors(pointIndex,:,:)=vectors(:,order);
end
end

function phase=shortestVectorPhase(delta,supercellMatrix,lattice,qpoint)
% Average phase over all translationally equivalent shortest vectors.
shifts=-1:1;
vectors=zeros(numel(shifts)^3,3);
output=0;
for first=shifts
    for second=shifts
        for third=shifts
            output=output+1;
            vectors(output,:)=delta+ ...
                [first,second,third]*supercellMatrix;
        end
    end
end
lengths=vecnorm(vectors*lattice,2,2);
minimum=min(lengths);
selected=abs(lengths-minimum)<1e-8;
phase=mean(exp(2i*pi*(vectors(selected,:)*qpoint.')));
end
