function value=solid_angle(center,coordinates)
%SOLID_ANGLE Solid angle subtended by an ordered polygon.
vectors=coordinates-center;vectors(end+1,:)=vectors(1,:);
crosses=zeros(size(vectors,1),3);
for index=1:size(vectors,1)-1
    crosses(index,:)=cross(vectors(index+1,:),vectors(index,:));
end
crosses(end,:)=cross(vectors(2,:),vectors(1,:));
phi=0;
for index=1:size(crosses,1)-1
    cosine=-dot(crosses(index,:),crosses(index+1,:))/ ...
        (norm(crosses(index,:))*norm(crosses(index+1,:)));
    if cosine>1+1e-12||cosine<-1-1e-12
        error("KSSOLV:Matgenlab:ChemEnv:SolidAngle", ...
            "Solid-angle cosine %g is outside [-1,1].",cosine);
    end
    phi=phi+acos(min(max(cosine,-1),1));
end
value=phi+(3-size(vectors,1))*pi;
end
