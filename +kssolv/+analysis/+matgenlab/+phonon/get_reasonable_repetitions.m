function value=get_reasonable_repetitions(nAtoms)
%GET_REASONABLE_REPETITIONS Choose phononwebsite supercell repetitions.
if nAtoms<4,value=[3,3,3];
elseif nAtoms<15,value=[2,2,2];
elseif nAtoms<50,value=[2,2,1];
else,value=[1,1,1];
end
end
