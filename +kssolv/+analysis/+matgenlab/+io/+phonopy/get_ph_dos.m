function dos=get_ph_dos(path)
%GET_PH_DOS Read phonopy total_dos.dat.
values=readmatrix(path,FileType="text",CommentStyle="#");
values=values(all(isfinite(values(:,1:2)),2),1:2);
dos=kssolv.analysis.matgenlab.phonon.PhononDos( ...
    values(:,1),values(:,2));
end
