function eigenvalues=parse_dielectric_data(data)
%PARSE_DIELECTRIC_DATA Principal dielectric values for VASP tensor rows.
data=double(data);
eigenvalues=zeros(size(data,1),3);
for index=1:size(data,1)
    matrix=kssolv.analysis.matgenlab.analysis.solar. ...
        to_matrix(data(index,1),data(index,2),data(index,3), ...
        data(index,4),data(index,5),data(index,6));
    eigenvalues(index,:)=eig(matrix).';
end
end
