function values=default_magmoms()
%DEFAULT_MAGMOMS Frozen pymatgen a75a4c4 defaults.
pairs={
    "Co",5;"Co3+",.6;"Co4+",1;"Cr",5;"Fe",5;"Mn",5;"Mn3+",4;"Mn4+",3;
    "Mo",5;"Ni",5;"V",5;"W",5;"Ce",5;"Eu",10;"Ti3+",1.73;"V3+",2.83;
    "Cr3+",3.88;"Cr2+",4.90;"Mn2+",5.92;"Fe3+",5.92;"Co2+",3.88;
    "Ni2+",2.83;"Cu",1.73;"Cu2+",1.73;"Pr",3.58;"Nd",3.62;"Pm",2.68;
    "Sm",.85;"Gd",7.94;"Tb",9.72;"Dy",10.65;"Ho",10.6;"Er",9.58;
    "Tm",7.56;"Yb",4.54;"Ru",2.2;"Os",2.2};
values=containers.Map(cellstr(string(pairs(:,1))),cell2mat(pairs(:,2)));
end
