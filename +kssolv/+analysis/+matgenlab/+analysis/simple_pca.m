function [scores,eigenvalues,eigenvectors]=simple_pca(data,k)
%SIMPLE_PCA Principal-component projection matching pymatgen's bare PCA.
if nargin<2,k=2;end
centered=double(data)-mean(double(data),1);
[vectors,values]=eig(cov(centered),"vector");
[eigenvalues,order]=sort(values,"descend");vectors=vectors(:,order);
for ii=1:size(vectors,2)
    % NumPy/LAPACK's orientation for this symmetric eigensystem is
    % reproduced by choosing a non-positive component sum.
    if sum(vectors(:,ii))>0,vectors(:,ii)=-vectors(:,ii);end
end
eigenvectors=vectors(:,1:k);eigenvalues=eigenvalues(1:k);
scores=centered*eigenvectors;
end
