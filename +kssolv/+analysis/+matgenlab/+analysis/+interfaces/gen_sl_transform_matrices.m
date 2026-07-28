function matrices=gen_sl_transform_matrices(areaMultiple)
%GEN_SL_TRANSFORM_MATRICES Integer 2-D superlattice transformations.
factors=kssolv.analysis.matgenlab.analysis.interfaces. ...
    get_factors(areaMultiple);
matrices=cell(1,sum(areaMultiple./factors));
next=1;
for factor=factors
    for offset=0:areaMultiple/factor-1
        matrices{next}=[factor,offset;0,areaMultiple/factor];
        next=next+1;
    end
end
end
