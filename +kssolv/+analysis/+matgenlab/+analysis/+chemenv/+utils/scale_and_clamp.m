function value=scale_and_clamp(input,edge0,edge1,clamp0,clamp1)
%SCALE_AND_CLAMP Affinely scale then clamp values.
value=min(max((input-edge0)/(edge1-edge0),clamp0),clamp1);
end
