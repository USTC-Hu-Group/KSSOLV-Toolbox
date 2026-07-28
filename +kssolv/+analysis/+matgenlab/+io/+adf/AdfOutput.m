classdef AdfOutput
    %ADFOUTPUT Parser for ADF logfile and standard-output frequency data.
    properties
        filename (1,1) string
        is_failed (1,1) logical = false
        is_internal_crash (1,1) logical = false
        error = []
        run_type = []
        final_energy = []
        final_structure = []
        energies (1,:) double = zeros(1,0)
        structures (1,:) cell = cell(1,0)
        frequencies (1,:) double = zeros(1,0)
        normal_modes (1,:) cell = cell(1,0)
        freq_type = []
    end
    methods
        function obj=AdfOutput(filename)
            obj.filename=string(filename);
            obj=obj.parse();
        end
    end
    methods (Access=private)
        function obj=parse(obj)
            directory=fileparts(char(obj.filename));
            logfile=fullfile(directory,"logfile");
            candidates=string(logfile)+["",".gz",".bz2"];
            found=find(arrayfun(@(path)isfile(path),candidates),1);
            if isempty(found)
                throw(MException("KSSOLV:Matgenlab:ADF:Logfile", ...
                    "The ADF logfile cannot be accessed."));
            end
            obj=obj.parse_logfile(candidates(found));
            if ~obj.is_failed&&string(obj.run_type)~="SinglePoint"
                obj=obj.parse_adf_output();
            end
        end
        function obj=parse_logfile(obj,filename)
            lines=readLines(filename);
            nonempty=find(strlength(strip(lines))>0);
            if isempty(nonempty)||isempty(regexp( ...
                    lines(nonempty(end)),'<.*>\s+<.*>\s+END','once'))
                obj.is_internal_crash=true;obj.is_failed=true;
                obj.error="Internal crash. TAPE13 is generated!";
                return
            end
            parseCycle=false;parseFinal=false;lastCycle=-1;
            siteSpecies={};siteCoordinates=zeros(0,3);
            for index=1:numel(lines)
                line=char(lines(index));
                token=regexp(line, ...
                    '<.*>\s+<.*>\s+ERROR\s+DETECTED:\s+(.*)', ...
                    'tokens','once');
                if ~isempty(token)
                    obj.is_failed=true;obj.error=string(token{1});break
                end
                if isempty(obj.run_type)
                    token=regexp(line, ...
                        '<.*>\s+<.*>\s+RunType\s+:\s+(.*)', ...
                        'tokens','once');
                    if ~isempty(token)
                        kind=strtrim(token{1});
                        switch kind
                            case "FREQUENCIES"
                                obj.freq_type="Numerical";
                                obj.run_type="NumericalFreq";
                            case "GEOMETRY OPTIMIZATION"
                                obj.run_type="GeometryOptimization";
                            case "CREATE"
                                obj.run_type=[];
                            case "SINGLE POINT"
                                obj.run_type="SinglePoint";
                            otherwise
                                throw(kssolv.analysis.matgenlab.io.adf. ...
                                    AdfOutputError("Undefined Runtype."));
                        end
                    end
                    continue
                end
                if string(obj.run_type)=="SinglePoint"
                    [species,coordinates,matched]=parseLogCoordinate(line);
                    if matched
                        siteSpecies{end+1}=species; %#ok<AGROW>
                        siteCoordinates(end+1,:)=coordinates; %#ok<AGROW>
                    else
                        energy=parseNumber(line, ...
                            "<.*>\s+<.*>\s+Bond\s+Energy\s+" + ...
                            "([-\.0-9]+)\s+a\.u\.");
                        if ~isempty(energy)
                            obj.final_energy=energy;
                            obj.final_structure=makeMolecule( ...
                                siteSpecies,siteCoordinates);
                        end
                    end
                elseif string(obj.run_type)=="GeometryOptimization"
                    token=regexp(line, ...
                        'Coordinates\s+in\s+Geometry\s+Cycle\s+(\d+)', ...
                        'tokens','once');
                    if ~isempty(token)
                        cycle=str2double(token{1});
                        if cycle<=0
                            throw(kssolv.analysis.matgenlab.io.adf. ...
                                AdfOutputError( ...
                                sprintf("Wrong cycle=%d",cycle)));
                        elseif cycle>lastCycle
                            parseCycle=true;lastCycle=cycle;
                        else
                            parseFinal=true;
                        end
                    elseif parseCycle
                        [species,coordinates,matched]= ...
                            parseLogCoordinate(line);
                        if matched
                            siteSpecies{end+1}=species; %#ok<AGROW>
                            siteCoordinates(end+1,:)=coordinates; %#ok<AGROW>
                        else
                            energy=parseNumber(line, ...
                                "<.*>\s+<.*>\s+current\s+energy\s+" + ...
                                "([-\.0-9]+)\s+Hartree");
                            if ~isempty(energy)
                                obj.energies(end+1)=energy;
                                obj.structures{end+1}=makeMolecule( ...
                                    siteSpecies,siteCoordinates);
                                parseCycle=false;siteSpecies={};
                                siteCoordinates=zeros(0,3);
                            end
                        end
                    elseif parseFinal
                        energy=parseNumber(line, ...
                            "<.*>\s+<.*>\s+Bond\s+Energy\s+" + ...
                            "([-\.0-9]+)\s+a\.u\.");
                        if ~isempty(energy),obj.final_energy=energy;end
                    end
                elseif string(obj.run_type)=="NumericalFreq"
                    break
                end
            end
            if obj.is_failed,return,end
            if string(obj.run_type)=="GeometryOptimization"
                if ~isempty(obj.structures)
                    obj.final_structure=obj.structures{end};
                end
                if isempty(obj.final_energy)
                    throw(kssolv.analysis.matgenlab.io.adf. ...
                        AdfOutputError( ...
                        "The final energy cannot be read."));
                end
            elseif string(obj.run_type)=="SinglePoint"
                if isempty(obj.final_structure)
                    throw(kssolv.analysis.matgenlab.io.adf. ...
                        AdfOutputError("The final structure is missing."));
                elseif isempty(obj.final_energy)
                    throw(kssolv.analysis.matgenlab.io.adf. ...
                        AdfOutputError( ...
                        "The final energy cannot be read."));
                end
            end
        end
        function obj=parse_adf_output(obj)
            lines=readLines(obj.filename);
            parseFrequency=false;parseMode=false;
            findStructure=isempty(obj.final_structure);
            parseCoordinates=false;coordinateStrike=0;
            species={};coordinates=zeros(0,3);nNext=0;
            if findStructure,nAtoms=0;
            else,nAtoms=obj.final_structure.num_sites;end
            for index=1:numel(lines)
                line=char(lines(index));
                if string(obj.run_type)=="NumericalFreq"&&findStructure
                    if ~parseCoordinates
                        if ~isempty(regexp(line, ...
                                "\*\s+R\s+U\s+N\s+T\s+Y\s+P\s+E\s*:" + ...
                                "\s*FREQUENCIES\s+\*",'once'))
                            parseCoordinates=true;
                        end
                    else
                        token=regexp(line, ...
                            "^\s*(\d+)\s+([A-Za-z]+)" + ...
                            "\s+([0-9\.-]+)\s+([0-9\.-]+)" + ...
                            "\s+([0-9\.-]+)\s+([0-9\.-]+)" + ...
                            "\s+([0-9\.-]+)\s+([0-9\.-]+)", ...
                            'tokens','once');
                        if ~isempty(token)
                            species{end+1}=token{2}; %#ok<AGROW>
                            coordinates(end+1,:)=str2double(token(3:5)); %#ok<AGROW>
                            coordinateStrike=coordinateStrike+1;
                        elseif coordinateStrike>0
                            findStructure=false;
                            obj.final_structure=makeMolecule( ...
                                species,coordinates);
                            nAtoms=obj.final_structure.num_sites;
                        end
                    end
                elseif isempty(obj.freq_type)
                    if ~isempty(regexp(line, ...
                            '\*\s+F\s+R\s+E\s+Q\s+U\s+E\s+N\s+C\s+I\s+E\s+S\s+\*', ...
                            'once'))
                        obj.freq_type="Numerical";
                    elseif ~isempty(regexp(line, ...
                            "\*\s+F\s+R\s+E\s+Q\s+U\s+E\s+N\s+C\s+Y" + ...
                            "\s+A\s+N\s+A\s+L\s+Y\s+S\s+I\s+S\s+\*", ...
                            'once'))
                        obj.freq_type="Analytical";
                        obj.run_type="AnalyticalFreq";
                    end
                elseif ~isempty(regexp(line, ...
                        'Vibrations\s+and\s+Normal\s+Modes\s+\*+.*\*+', ...
                        'once'))
                    parseFrequency=true;
                elseif parseFrequency
                    if contains(line,"List of All Frequencies:"),break,end
                    values=str2double(split(strip(string(line))));
                    values=values(~isnan(values));
                    if numel(values)>=1&&numel(values)<=3&&contains(line,".")
                        nNext=numel(values);parseMode=true;
                        parseFrequency=false;
                        obj.frequencies=[obj.frequencies, ...
                            reshape(values,1,[])];
                        for mode=1:nNext
                            obj.normal_modes{end+1}=zeros(1,0);
                        end
                    end
                elseif parseMode
                    token=regexp(line, ...
                        '^\s*(\d+)\.([A-Za-z]+)\s+(.*)', ...
                        'tokens','once');
                    if ~isempty(token)
                        values=str2double(split(strip(string(token{3}))));
                        values=values(~isnan(values));
                        if numel(values)~=3*nNext
                            throw(kssolv.analysis.matgenlab.io.adf. ...
                                AdfOutputError("Odd Error."));
                        end
                        vectors=reshape(values,3,nNext).';
                        first=numel(obj.normal_modes)-nNext+1;
                        for mode=1:nNext
                            obj.normal_modes{first+mode-1}= ...
                                [obj.normal_modes{first+mode-1}, ...
                                vectors(mode,:)];
                        end
                        if str2double(token{1})==nAtoms
                            parseFrequency=true;parseMode=false;
                        end
                    end
                end
            end
            if ~isempty(obj.freq_type)
                if numel(obj.frequencies)~=numel(obj.normal_modes)
                    throw(kssolv.analysis.matgenlab.io.adf. ...
                        AdfOutputError( ...
                        "The number of normal modes is wrong."));
                elseif isempty(obj.normal_modes)|| ...
                        numel(obj.normal_modes{1})~=nAtoms*3
                    throw(kssolv.analysis.matgenlab.io.adf. ...
                        AdfOutputError( ...
                        "The dimensions of the modes are wrong."));
                end
            end
        end
    end
end

function lines=readLines(filename)
filename=string(filename);
if endsWith(filename,".gz")
    directory=string(tempname);mkdir(directory);
    cleanup=onCleanup(@()rmdir(directory,"s"));
    paths=gunzip(filename,directory);temporary=string(paths{1});
    text=fileread(temporary);clear cleanup
elseif endsWith(filename,".bz2")
    error("KSSOLV:Matgenlab:ADF:Compression", ...
        "BZip2-compressed ADF files are not supported by this MATLAB runtime.");
else
    text=fileread(filename);
end
lines=splitlines(string(text));
end

function [species,coordinates,matched]=parseLogCoordinate(line)
token=regexp(line, ...
    "\s+([0-9]+)\.([A-Za-z]+)\s+([-\.0-9]+)" + ...
    "\s+([-\.0-9]+)\s+([-\.0-9]+)", ...
    'tokens','once');
matched=~isempty(token);
if matched
    species=token{2};coordinates=str2double(token(3:5));
else
    species="";coordinates=zeros(1,3);
end
end

function value=parseNumber(line,pattern)
token=regexp(line,char(pattern),'tokens','once');
if isempty(token),value=[];else,value=str2double(token{1});end
end

function molecule=makeMolecule(species,coordinates)
molecule=kssolv.analysis.matgenlab.core.Molecule( ...
    species,coordinates,charge_spin_check=false);
end
