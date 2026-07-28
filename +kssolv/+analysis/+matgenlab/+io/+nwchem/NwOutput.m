classdef NwOutput
    %NWOUTPUT Native parser for NWChem jobs, forces, modes and TDDFT roots.
    properties
        filename (1,1) string
        raw (1,1) string
        job_info (1,1) struct
        data (1,:) cell
    end
    methods
        function obj=NwOutput(filename)
            obj.filename=string(filename);
            obj.raw=string(fileread(filename));
            chunks=regexp(char(obj.raw), ...
                'NWChem Input Module','split');
            if ~isempty(regexp(chunks{end},'CITATION','once'))
                chunks(end)=[];
            end
            obj.job_info=parsePreamble(chunks{1});
            chunks(1)=[];
            obj.data=cellfun(@parseJob,chunks,"UniformOutput",false);
        end
        function value=length(obj),value=numel(obj.data);end
        function value=end(obj,~,~),value=numel(obj.data);end
        function value=numel(obj,varargin)
            if nargin==1,value=builtin("numel",obj.data);
            else,value=builtin("numel",obj.data,varargin{:});end
        end
        function value=subsref(obj,index)
            if index(1).type=="()"
                if numel(index(1).subs)~=1
                    error("KSSOLV:Matgenlab:NWChem:Index", ...
                        "NwOutput accepts one job index.");
                end
                requested=index(1).subs{1};
                if ischar(requested)&&strcmp(requested,':')
                    value=obj.data;
                else
                    value=obj.data{requested};
                end
                if numel(index)>1,value=builtin("subsref",value,index(2:end));end
            else
                if isprop(obj,index(1).subs)
                    value=builtin("subsref",obj,index(1));
                    if numel(index)>1
                        value=builtin("subsref",value,index(2:end));
                    end
                else
                    value=builtin("subsref",obj,index);
                end
            end
        end
        function roots=parse_tddft(obj)
            roots=struct("singlet",{{}},"triplet",{{}});
            state="singlet";inside=false;
            lines=splitlines(obj.raw);
            for index=1:numel(lines)
                line=strip(lines(index));
                if contains(line,"Convergence criterion met")
                    inside=true;
                elseif contains(line,"Excited state energy")
                    inside=false;
                elseif contains(line,"singlet excited")
                    state="singlet";
                elseif contains(line,"triplet excited")
                    state="triplet";
                elseif inside&&contains(line,"Root")&&contains(line,"eV")
                    tokens=split(line);tokens=tokens(strlength(tokens)>0);
                    item=struct("energy",str2double(tokens(end-1)), ...
                        "osc_strength",[]);
                    roots.(state){end+1}=item;
                elseif inside&&contains(line,"Dipole Oscillator Strength")
                    tokens=split(line);tokens=tokens(strlength(tokens)>0);
                    item=roots.(state){end};
                    item.osc_strength=str2double(tokens(end));
                    roots.(state){end}=item;
                end
            end
        end
        function spectrum=get_excitation_spectrum(obj,width,npoints)
            if nargin<2||isempty(width),width=.1;end
            if nargin<3||isempty(npoints),npoints=2000;end
            roots=obj.parse_tddft();rootData=roots.singlet;
            energies=cellfun(@(item)item.energy,rootData);
            oscillator=cellfun(@(item)item.osc_strength,rootData);
            padding=20*width;minimum=energies(1)-padding;
            maximum=energies(end)+padding;
            step=(maximum-minimum)/npoints;
            width=max(width,2*step);
            x=minimum+(0:npoints-1)*step;
            cutoff=20*width;gamma=.5*width;
            actualStep=(x(end)-x(1))/(numel(x)-1);
            prefactor=gamma/pi*actualStep;y=zeros(size(x));
            for index=1:numel(x)
                difference=x(index)-energies;
                terms=oscillator./(difference.^2+gamma^2);
                y(index)=sum(terms(abs(difference)<=cutoff))*prefactor;
            end
            spectrum=kssolv.analysis.matgenlab.analysis. ...
                ExcitationSpectrum(x,y);
        end
    end
end

function info=parsePreamble(text)
info=struct();lines=splitlines(string(text));
for index=1:numel(lines)
    pieces=split(lines(index),"=");
    if numel(pieces)>1
        name=matlab.lang.makeValidName(char(strip(pieces(1))));
        info.(name)=strip(pieces(end));
    end
end
end

function data=parseJob(output)
hartreeToEv=27.211386245988;
kjMolToEv=1/96.48533212331002;
lines=splitlines(string(output));
errors={};energies={};corrections=struct();
molecules={};structures={};allForces={};
basisSet=struct();basisHeader=strings(1,0);
frequencies={};normalFrequencies={};
hessianRows={};projectedRows={};
species={};coordinates=zeros(0,3);lattice=zeros(0,3);
forces=zeros(1,0);jobType="";taskTime=0;
parseGeometry=false;parseForce=false;parseFrequency=false;
parseProjectedFrequency=false;parseBasis=false;
parseHessian=false;parseProjectedHessian=false;parseTime=false;
data=struct();
errorDefinitions={ ...
    "calculations not reaching convergence","Bad convergence"; ...
    "Calculation failed to converge","Bad convergence"; ...
    "geom_binvr: #indep variables incorrect","autoz error"; ...
    "dft optimize failed","Geometry optimization failed"};
for lineIndex=1:numel(lines)
    line=char(lines(lineIndex));trimmed=strtrim(line);
    for definition=1:size(errorDefinitions,1)
        if contains(line,errorDefinitions{definition,1})
            errors{end+1}=errorDefinitions{definition,2}; %#ok<AGROW>
        end
    end
    if parseTime
        token=regexp(line, ...
            '\s+Task\s+times\s+cpu:\s+([.\d]+)s.+', ...
            'tokens','once');
        if ~isempty(token)
            taskTime=string(token{1});parseTime=false;
        end
    end
    if parseGeometry
        if strcmp(trimmed,"Atomic Mass")
            if isempty(lattice)
                molecules{end+1}=makeMolecule(species,coordinates); %#ok<AGROW>
            else
                structures{end+1}= ...
                    kssolv.analysis.matgenlab.core.Structure( ...
                    lattice,species,coordinates, ...
                    coords_are_cartesian=true); %#ok<AGROW>
            end
            species={};coordinates=zeros(0,3);lattice=zeros(0,3);
            parseGeometry=false;
        else
            token=regexp(line, ...
                "\d+\s+(\w+)\s+[.\-\d]+\s+([.\-\d]+)" + ...
                "\s+([.\-\d]+)\s+([.\-\d]+)", ...
                'tokens','once');
            if ~isempty(token)
                species{end+1}=capitalize(token{1}); %#ok<AGROW>
                coordinates(end+1,:)=str2double(token(2:4)); %#ok<AGROW>
            end
            token=regexp(line, ...
                'a[123]=<\s+([.\-\d]+)\s+([.\-\d]+)\s+([.\-\d]+)\s+>', ...
                'tokens','once');
            if ~isempty(token)
                lattice(end+1,:)=str2double(token); %#ok<AGROW>
            end
        end
        continue
    end
    if parseForce
        token=regexp(line, ...
            "\s+(\d+)\s+(\w+)" + ...
            "\s+([0-9.\-]+)\s+([0-9.\-]+)\s+([0-9.\-]+)" + ...
            "\s+([0-9.\-]+)\s+([0-9.\-]+)\s+([0-9.\-]+)", ...
            'tokens','once');
        if ~isempty(token)
            forces=[forces,str2double(token(6:8))]; %#ok<AGROW>
        elseif ~isempty(forces)
            allForces{end+1}=forces;forces=zeros(1,0); %#ok<AGROW>
            parseForce=false;
        end
        continue
    elseif parseFrequency
        if isempty(trimmed)
            if isempty(normalFrequencies{end,2}),continue,end
            parseFrequency=false;
        else
            values=parseDisplacements(trimmed);
            count=numel(values);
            first=size(normalFrequencies,1)-count+1;
            for mode=1:count
                normalFrequencies{first+mode-1,2}= ...
                    [normalFrequencies{first+mode-1,2}, ...
                    values(mode)]; %#ok<AGROW>
            end
        end
        continue
    elseif parseProjectedFrequency
        if isempty(trimmed)
            if isempty(frequencies{end,2}),continue,end
            parseProjectedFrequency=false;
        else
            values=parseDisplacements(trimmed);
            count=numel(values);first=size(frequencies,1)-count+1;
            for mode=1:count
                frequencies{first+mode-1,2}= ...
                    [frequencies{first+mode-1,2}, ...
                    values(mode)]; %#ok<AGROW>
            end
        end
        continue
    elseif parseBasis
        if isempty(trimmed)
            parseBasis=false;
        else
            tokens=split(string(trimmed));
            tokens=tokens(strlength(tokens)>0);
            if tokens(1)=="Tag"
                basisHeader=lower(tokens);
                if numel(basisHeader)>=4,basisHeader(4)=[];end
            elseif isempty(regexp(tokens(1),'^-+$','once'))
                entry=struct();
                for header=2:min(numel(basisHeader),numel(tokens))
                    field=matlab.lang.makeValidName( ...
                        char(basisHeader(header)));
                    entry.(field)=tokens(header);
                end
                basisSet.(matlab.lang.makeValidName( ...
                    char(tokens(1))))=entry;
            end
        end
        continue
    elseif parseHessian
        if isempty(trimmed),continue,end
        if ~isempty(hessianRows)&&contains(line,"----------")
            parseHessian=false;continue
        end
        [row,values,valid]=parseHessianRow(trimmed);
        if valid
            if numel(hessianRows)<row
                hessianRows{row}=values; %#ok<AGROW>
            else
                hessianRows{row}=[hessianRows{row},values]; %#ok<AGROW>
            end
        end
        continue
    elseif parseProjectedHessian
        if isempty(trimmed),continue,end
        [row,values,valid]=parseHessianRow(trimmed);
        if valid
            if numel(projectedRows)<row
                projectedRows{row}=values; %#ok<AGROW>
            else
                projectedRows{row}= ...
                    [projectedRows{row},values]; %#ok<AGROW>
            end
            if ~isempty(hessianRows)&& ...
                    numel(projectedRows{end})==numel(hessianRows)
                parseProjectedHessian=false;
            end
        end
        continue
    end

    token=regexp(line,'Total \w+ energy\s+=\s+([.\-\d]+)', ...
        'tokens','once');
    if ~isempty(token)
        energies{end+1}=str2double(token{1})*hartreeToEv; %#ok<AGROW>
        parseTime=true;continue
    end
    token=regexp(line,'gas phase energy\s+=\s+([.\-\d]+)', ...
        'tokens','once');
    if ~isempty(token)
        current=struct("cosmo_scf",energies{end}, ...
            "gas_phase",str2double(token{1})*hartreeToEv);
        energies{end}=current;
    end
    token=regexp(line,'sol phase energy\s+=\s+([.\-\d]+)', ...
        'tokens','once');
    if ~isempty(token)
        current=energies{end};
        current.sol_phase=str2double(token{1})*hartreeToEv;
        energies{end}=current;
    end
    token=regexp(line, ...
        '(No. of atoms|No. of electrons|SCF calculation type|Charge|Spin multiplicity)\s*:\s*(\S+)', ...
        'tokens','once');
    if ~isempty(token)
        name=lower(replace(replace(string(token{1}), ...
            "No. of ","n")," ","_"));
        number=str2double(token{2});
        if isnan(number),data.(name)=string(token{2});
        else,data.(name)=number;end
    elseif contains(line,'Geometry "geometry"')
        parseGeometry=true;
    elseif contains(line,'Summary of "ao basis"')
        parseBasis=true;
    elseif contains(line,"P.Frequency")
        parseProjectedFrequency=true;
        tokens=split(strip(string(line)));tokens=tokens(2:end);
        for tokenIndex=1:numel(tokens)
            frequencies(end+1,:)={str2double(tokens(tokenIndex)), ...
                zeros(1,0)}; %#ok<AGROW>
        end
    elseif contains(line,"Frequency")
        tokens=split(strip(string(line)));
        if numel(tokens)>1&&tokens(1)=="Frequency"
            parseFrequency=true;
            for tokenIndex=2:numel(tokens)
                normalFrequencies(end+1,:)= ...
                    {str2double(tokens(tokenIndex)),zeros(1,0)}; %#ok<AGROW>
            end
        end
    elseif contains(line,"MASS-WEIGHTED NUCLEAR HESSIAN")
        parseHessian=true;
    elseif contains(line,"MASS-WEIGHTED PROJECTED HESSIAN")
        parseProjectedHessian=true;
    elseif contains(line, ...
            "atom               coordinates                        gradient")
        parseForce=true;
    elseif strlength(jobType)==0&&startsWith(strip(string(line)),"NWChem")
        jobType=strip(string(line));
        if jobType=="NWChem DFT Module"&& ...
                contains(output,"COSMO solvation results")
            jobType=jobType+" COSMO";
        end
    else
        token=regexp(line, ...
            '([\w\-]+ correction to \w+)\s+=\s+([.\-\d]+)', ...
            'tokens','once');
        if ~isempty(token)
            field=matlab.lang.makeValidName(token{1});
            corrections.(field)=str2double(token{2})*kjMolToEv;
        end
    end
end
if parseForce&&~isempty(forces),allForces{end+1}=forces;end
frequencies=reshapeModes(frequencies);
normalFrequencies=reshapeModes(normalFrequencies);
hessian=completeSymmetric(hessianRows);
projectedHessian=completeSymmetric(projectedRows);
if all(cellfun(@(item)isnumeric(item)&&isscalar(item),energies))
    energies=cell2mat(energies);
end
data.job_type=jobType;data.energies=energies;
data.corrections=corrections;data.molecules=molecules;
data.structures=structures;data.basis_set=basisSet;
data.errors=errors;data.has_error=~isempty(errors);
data.frequencies=emptyToNone(frequencies);
data.normal_frequencies=emptyToNone(normalFrequencies);
data.hessian=emptyToNone(hessian);
data.projected_hessian=emptyToNone(projectedHessian);
data.forces=allForces;data.task_time=taskTime;
end

function molecule=makeMolecule(species,coordinates)
molecule=kssolv.analysis.matgenlab.core.Molecule( ...
    species,coordinates,charge_spin_check=false);
end

function value=capitalize(text)
text=lower(string(text));value=char(upper(extractBefore(text,2))+ ...
    extractAfter(text,1));
end

function values=parseDisplacements(line)
tokens=split(string(line));tokens=tokens(strlength(tokens)>0);
values=reshape(str2double(tokens(2:end)),1,[]);
end

function [row,values,valid]=parseHessianRow(line)
tokens=split(string(line));tokens=tokens(strlength(tokens)>0);
row=str2double(tokens(1));valid=~isnan(row)&&numel(tokens)>1&& ...
    any(contains(tokens(2),[".","D","E"]));
if valid
    values=reshape(str2double(replace(tokens(2:end),"D","e")),1,[]);
else
    values=zeros(1,0);
end
end

function modes=reshapeModes(modes)
for index=1:size(modes,1)
    values=modes{index,2};
    if mod(numel(values),3)==0
        modes{index,2}=reshape(values,3,[]).';
    end
end
end

function matrix=completeSymmetric(rows)
if isempty(rows),matrix=[];return,end
count=numel(rows);matrix=zeros(count);
for row=1:count
    values=rows{row};
    matrix(row,1:min(numel(values),count))= ...
        values(1:min(numel(values),count));
end
for row=1:count
    for column=row+1:count
        matrix(row,column)=matrix(column,row);
    end
end
end

function value=emptyToNone(value)
if isempty(value),value=[];end
end
