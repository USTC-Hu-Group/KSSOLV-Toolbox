function values=zval_dict_from_potcar(potcar)
%ZVAL_DICT_FROM_POTCAR Map POTCAR element symbols to valence charges.
values=struct();
for index=1:potcar.count
    item=potcar(index);
    values.(char(item.element))=item.nelectrons;
end
end
