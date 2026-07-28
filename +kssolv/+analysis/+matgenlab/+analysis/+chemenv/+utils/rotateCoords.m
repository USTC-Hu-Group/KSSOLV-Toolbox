function value=rotateCoords(coordinates,rotation)
%ROTATECOORDS Rotate row-vector coordinates.
value=(rotation*coordinates.').';
end
