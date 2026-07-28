function value=parse_energy_file(file)
data=readmatrix(file,"FileType","text","CommentStyle","#");
if size(data,2)<6,error("KSSOLV:Matgenlab:Cp2k:EnergyFile","CP2K energy files require six numeric columns.");end
factor=27.211386245988;
value=struct("step",data(:,1),"kinetic_energy",data(:,2)*factor, ...
 "temp",data(:,3),"potential_energy",data(:,4)*factor, ...
 "conserved_quantity",data(:,5)*factor,"used_time",data(:,6));
end
