function values=u_values(kind,anion)
%U_VALUES Expected Hubbard U values from frozen MP and MIT input sets.
values=struct();
if upper(string(kind))=="MP"
    if any(string(anion)==["O","F"])
        values=struct(V=3.25,Cr=3.7,Mn=3.9,Fe=5.3,Co=3.32, ...
            Ni=6.2,W=6.2,Mo=4.38);
    end
else
    if any(string(anion)==["O","F"])
        values=struct(Ag=1.5,Co=3.4,Cr=3.5,Cu=4,Fe=4,Mn=3.9, ...
            Mo=4.38,Nb=1.5,Ni=6,Re=2,Ta=2,V=3.1,W=4);
    elseif string(anion)=="S"
        values=struct(Fe=1.9,Mn=2.5);
    end
end
end
