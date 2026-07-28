function [value,totalDos]=parse_pdos(file,varargin)
text=fileread(file);h=regexp(text,'atomic kind\s+(\S+).*E\(Fermi\)\s*=\s*([-+\d.]+)','tokens','once');
if isempty(h),h=regexp(text,'list\s+(\d+)\s+.*E\(Fermi\)\s*=\s*([-+\d.]+)','tokens','once');end
lines=splitlines(string(text));data=[];for i=3:numel(lines),r=str2double(split(strtrim(lines(i))));if numel(r)>3&&all(~isnan(r)),data(end+1,:)=r;end,end %#ok<AGROW>
value=struct();if isempty(h),name="TOTAL";else,name=string(h{1});end
energies=data(:,2)*27.211386245988;last=find(data(:,3)~=0,1,"last");if isempty(last),ef=energies(1);else,ef=energies(last)+1e-6;end
spin="up";if contains(upper(string(file)),"BETA"),spin="down";end;if ~isempty(varargin)&&~isempty(varargin{1}),if varargin{1}<0,spin="down";else,spin="up";end,end
header=regexp(char(lines(2)),'Occupation\s+(.+)$','tokens','once');if isempty(header),labels="s";else,labels=split(strtrim(string(header{1})));end
entry=struct("energies",energies,"efermi",ef);
total=zeros(size(energies));
for i=1:min(numel(labels),size(data,2)-3)
 label=orbitalLabel(labels(i));density=data(:,i+3);densities=struct();densities.(char(spin))=density;
 entry.(char(label))=struct("efermi",ef,"energies",energies,"densities",densities,"density",density);
 total=total+density;
end
value.(matlab.lang.makeValidName(name))=entry;densities=struct();densities.(char(spin))=total;
totalDos=kssolv.analysis.matgenlab.electronic_structure.Dos(ef,energies,densities);
end
function label=orbitalLabel(label),switch string(label),case "p",label="px";case {"d","d-2"},label="dxy";case "d-1",label="dyz";case "d0",label="dz2";case "d+1",label="dxz";case "d+2",label="dx2";case "f-3",label="f_3";case "f-2",label="f_2";case "f-1",label="f_1";case "f+1",label="f1";case "f+2",label="f2";case "f+3",label="f3";end;label=string(matlab.lang.makeValidName(label));end
