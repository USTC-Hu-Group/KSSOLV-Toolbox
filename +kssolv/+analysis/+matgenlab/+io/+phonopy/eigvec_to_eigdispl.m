function value=eigvec_to_eigdispl(eigenvector,qpoint,fracCoords,mass)
%EIGVEC_TO_EIGDISPL Convert a phonopy eigenvector to eigendisplacement.
factor=exp(2i*pi*dot(fracCoords,qpoint))/sqrt(mass);
value=factor*eigenvector;
end
