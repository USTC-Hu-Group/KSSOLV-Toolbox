function [average,eigenvalues]=get_avg_mom_inertia(molecule)
%GET_AVG_MOM_INERTIA Average and principal molecular moments in kg m^2.
centered=molecule.get_centered_molecule();
tensor=zeros(3);
for index=1:centered.num_sites
    coordinate=centered.sites{index}.coords;
    weight=double(centered.sites{index}.specie.atomic_mass);
    for dimension=1:3
        other=mod([dimension,dimension+1],3)+1;
        tensor(dimension,dimension)=tensor(dimension,dimension)+ ...
            weight*sum(coordinate(other).^2);
    end
    for pair=[1,2;2,3;1,3].'
        first=pair(1);second=pair(2);
        value=-weight*coordinate(first)*coordinate(second);
        tensor(first,second)=tensor(first,second)+value;
        tensor(second,first)=tensor(second,first)+value;
    end
end
eigenvalues=eig(tensor).'*1.66053906892e-27*1e-20;
average=mean(eigenvalues);
end
