function value=get_okeeffe_distance_prediction(first,second)
%GET_OKEEFFE_DISTANCE_PREDICTION Estimate an O'Keeffe-Brese bond length.
a=kssolv.analysis.matgenlab.core.get_okeeffe_params(first);
b=kssolv.analysis.matgenlab.core.get_okeeffe_params(second);
value=a.r+b.r-a.r*b.r*(sqrt(a.c)-sqrt(b.c))^2/(a.c*a.r+b.c*b.r);
end
