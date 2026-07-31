function value = v_in_box(value, pbcMinimum, pbcLength)
%V_IN_BOX Wrap coordinates into a periodic Packmol box.
value = pbcMinimum + mod(value - pbcMinimum, pbcLength);
end
