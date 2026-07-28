function group=symm_group_cubic(matrix)
%SYMM_GROUP_CUBIC Cubic signed-permutation symmetry rotations.
matrix=reshape(double(matrix),[],3);
permutations=perms(1:3);group=zeros(0,3);
for index=1:size(permutations,1)
    for sx=[-1,1]
        for sy=[-1,1]
            for sz=[-1,1]
                rotation=zeros(3);
                rotation(1,permutations(index,1))=sx;
                rotation(2,permutations(index,2))=sy;
                rotation(3,permutations(index,3))=sz;
                if round(det(rotation))==1
                    group=[group;(rotation*matrix.').']; %#ok<AGROW>
                end
            end
        end
    end
end
group=unique(group,"rows");
end
