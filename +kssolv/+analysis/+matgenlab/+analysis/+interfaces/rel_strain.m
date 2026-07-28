function value=rel_strain(vector1,vector2)
%REL_STRAIN Relative change in vector length.
value=kssolv.analysis.matgenlab.analysis.interfaces.fast_norm(vector2)/ ...
    kssolv.analysis.matgenlab.analysis.interfaces.fast_norm(vector1)-1;
end
