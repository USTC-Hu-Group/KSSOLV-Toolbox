function value=normal_cdf_step(input,meanValue,scale)
%NORMAL_CDF_STEP Normal cumulative-distribution step.
value=.5*(1+erf((input-meanValue)/(sqrt(2)*scale)));
end
