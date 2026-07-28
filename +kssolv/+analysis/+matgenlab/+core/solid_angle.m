function angle=solid_angle(center,coords)
%#ok<*ALIGN>
%SOLID_ANGLE Solid angle subtended by an ordered polygon.
center=reshape(double(center),1,3);vectors=double(coords)-center;
norms=sqrt(sum(vectors.^2,2));angle=0;
for ii=2:size(vectors,1)-1
    jj=ii+1;
    triple=abs(dot(vectors(1,:),cross(vectors(ii,:),vectors(jj,:))));
    denominator=norms(1)*norms(ii)*norms(jj)+ ...
        norms(jj)*dot(vectors(1,:),vectors(ii,:))+ ...
        norms(ii)*dot(vectors(1,:),vectors(jj,:))+ ...
        norms(1)*dot(vectors(ii,:),vectors(jj,:));
    if denominator==0
        if triple>0,partial=pi/2;else,partial=-pi/2;end
    else,partial=atan(triple/denominator);end
    if partial<=0,partial=partial+pi;end
    angle=angle+2*partial;
end
end
