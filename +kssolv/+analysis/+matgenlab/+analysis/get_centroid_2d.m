function centroid=get_centroid_2d(vertices)
%GET_CENTROID_2D Polygon centroid for circumferentially ordered vertices.
vertices=double(vertices);cx=0;cy=0;areaTerm=0;
for ii=1:size(vertices,1)-1
    common=vertices(ii,1)*vertices(ii+1,2)-vertices(ii+1,1)*vertices(ii,2);
    cx=cx+(vertices(ii,1)+vertices(ii+1,1))*common;
    cy=cy+(vertices(ii,2)+vertices(ii+1,2))*common;
    areaTerm=areaTerm+common;
end
prefactor=.5/(6*areaTerm);centroid=prefactor*[cx,cy];
end
