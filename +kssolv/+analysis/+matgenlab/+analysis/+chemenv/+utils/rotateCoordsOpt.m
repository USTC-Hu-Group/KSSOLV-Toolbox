function value=rotateCoordsOpt(coordinates,rotation)
%ROTATECOORDSOPT Vectorized coordinate rotation.
value=(rotation*coordinates.').';
end
