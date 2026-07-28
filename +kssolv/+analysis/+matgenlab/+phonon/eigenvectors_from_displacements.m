function value=eigenvectors_from_displacements(displacements,masses)
%EIGENVECTORS_FROM_DISPLACEMENTS Apply sqrt(mass) along the atom axis.
masses=sqrt(reshape(double(masses),1,[],1));
value=double(displacements).*masses;
end
