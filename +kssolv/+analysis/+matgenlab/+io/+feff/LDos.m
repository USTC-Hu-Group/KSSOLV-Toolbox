classdef LDos < handle
 %#ok<*AGROW>
 %LDOS Parser for FEFF ldosNN.dat files.
 properties,complete_dos=[];charge_transfer struct=struct();end
 methods
  function obj=LDos(completeDos,chargeTransfer),if nargin>0,obj.complete_dos=completeDos;obj.charge_transfer=chargeTransfer;end,end
  function value=charge_transfer_to_str(obj),lines=["";"Charge Transfer";"";"absorbing atom"];names=sort(fieldnames(obj.charge_transfer));for i=1:numel(names),entry=obj.charge_transfer.(names{i});atom=fieldnames(entry);v=entry.(atom{1});lines=[lines;"";string(atom{1});"";"s   "+v.s;"p   "+v.p;"d   "+v.d;"f   "+v.f;"tot "+v.tot];end;value=char(join(lines,newline)+newline);end
  function value=as_dict(obj),value=struct("x_module","pymatgen.io.feff.outputs","x_class","LDos","complete_dos",obj.complete_dos.as_dict(),"charge_transfer",obj.charge_transfer);end
 end
 methods(Static)
  function obj=from_file(feffInput,ldosBase)
   if nargin<1,feffInput="feff.inp";end;if nargin<2,ldosBase="ldos";end
   header=kssolv.analysis.matgenlab.io.feff.Header.from_file(feffInput);structure=header.struct;tags=kssolv.analysis.matgenlab.io.feff.Tags.from_file(feffInput);
   [forward,~]=ldosPotentials(feffInput,tags);zero=readlinesCompat(ldosName(ldosBase,0));t=regexp(zero(1),'Fermi level \(eV\):\s*([-+\d.]+)','tokens','once');ef=str2double(t{1});
   symbols=fieldnames(forward);files=struct();for i=1:numel(symbols),idx=forward.(symbols{i});files.(symbols{i})=readmatrix(ldosName(ldosBase,idx),"FileType","text","CommentStyle","#");end
   pdos=cell(1,structure.num_sites);total=[];energies=[];
   for i=1:structure.num_sites,symbol=matlab.lang.makeValidName(structure.sites{i}.specie.symbol);data=files.(symbol);if isempty(energies),energies=data(:,1);total=zeros(size(energies));end;entry=struct();labels=["s","py","dxy","f0"];for j=1:4,density=data(:,j+1);entry.(char(labels(j)))=struct("up",density);total=total+density;end;pdos{i}=entry;end
   dos=kssolv.analysis.matgenlab.electronic_structure.Dos(ef,energies,struct("up",total));complete=kssolv.analysis.matgenlab.electronic_structure.CompleteDos(structure,dos,pdos);
   obj=kssolv.analysis.matgenlab.io.feff.LDos(complete,kssolv.analysis.matgenlab.io.feff.LDos.charge_transfer_from_file(feffInput,ldosBase));
  end
  function value=charge_transfer_from_file(feffInput,ldosBase)
   tags=kssolv.analysis.matgenlab.io.feff.Tags.from_file(feffInput);[forward,reverse]=ldosPotentials(feffInput,tags); %#ok<ASGLU>
   value=struct();indices=sort(cell2mat(keys(reverse)));for idx=indices,file=ldosName(ldosBase,idx);if ~isfile(file),continue,end;lines=readlinesCompat(file);symbol=string(reverse(idx));entry=struct("s",thirdNumber(lines(4)),"p",thirdNumber(lines(5)),"d",thirdNumber(lines(6)),"f",thirdNumber(lines(7)),"tot",fifthNumber(lines(2)));holder=struct();holder.(matlab.lang.makeValidName(symbol))=entry;value.(char("x"+idx))=holder;end
  end
  function obj=from_dict(d),complete=kssolv.analysis.matgenlab.electronic_structure.CompleteDos.from_dict(d.complete_dos);obj=kssolv.analysis.matgenlab.io.feff.LDos(complete,d.charge_transfer);end
 end
end
function [forward,reverse]=ldosPotentials(feffInput,tags)
if tags.has("RECIPROCAL")
 potFile=replace(string(feffInput),"feff.inp","pot.inp");lines=splitlines(string(kssolv.analysis.matgenlab.io.feff.feff_read_text(potFile)));start=find(contains(lines,"iz, lmaxsc"),1);stop=find(contains(lines,"ExternalPot"),1);rows=lines(start+1:stop-1);forward=struct();reverse=containers.Map("KeyType","double","ValueType","char");for i=1:numel(rows),vals=sscanf(char(rows(i)),"%f");if isempty(vals),continue,end;symbol=string(kssolv.analysis.matgenlab.core.Element.from_Z(vals(1)).symbol);reverse(i-1)=char(symbol);name=matlab.lang.makeValidName(symbol);if ~isfield(forward,name),forward.(name)=i;end,end
else
 text=kssolv.analysis.matgenlab.io.feff.Potential.pot_string_from_file(feffInput);[forward,reverse]=kssolv.analysis.matgenlab.io.feff.Potential.pot_dict_from_str(text);
end
end
function name=ldosName(base,index),if index<10,name=sprintf("%s0%d.dat",base,index);else,name=sprintf("%s%d.dat",base,index);end;end
function lines=readlinesCompat(file),lines=splitlines(string(kssolv.analysis.matgenlab.io.feff.feff_read_text(file)));end
function value=thirdNumber(line),value=lastNumber(line);end
function value=fifthNumber(line),value=lastNumber(line);end
function value=lastNumber(line),m=regexp(char(line),'[-+]?\d*\.?\d+(?:[Ee][-+]?\d+)?','match');value=str2double(m{end});end
