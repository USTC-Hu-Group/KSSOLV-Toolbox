function factors=get_factors(number)
%GET_FACTORS Positive integer factors in ascending order.
validateattributes(number,{'numeric'}, ...
    {"scalar","integer","positive"});
factors=find(mod(number,1:number)==0);
end
