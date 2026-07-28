function value=parse_dos(file)
data=readmatrix(file,"FileType","text","CommentStyle","#");energies=data(:,1)*27.211386245988;dens=struct("up",data(:,2));if size(data,2)>=4,dens.down=data(:,4);end;last=find(data(:,2)~=0,1,"last");if isempty(last),ef=energies(1);else,ef=energies(last)+1e-6;end;value=kssolv.analysis.matgenlab.electronic_structure.Dos(ef,energies,dens);
end
