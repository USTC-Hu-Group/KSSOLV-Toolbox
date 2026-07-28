classdef Cssr
    %CSSR Read and write the Cambridge structure-search file format.
    properties
        structure
    end
    methods
        function obj=Cssr(structure)
            if nargin<1,return,end
            if ~structure.is_ordered
                error("KSSOLV:Matgenlab:Cssr:Disordered", ...
                    "Cssr files can only represent ordered structures.");
            end
            obj.structure=structure;
        end
        function text=char(obj)
            lengths=obj.structure.lattice.abc;
            angles=obj.structure.lattice.angles;
            lines=[ ...
                string(sprintf("%.4f %.4f %.4f",lengths)), ...
                string(sprintf("%.2f %.2f %.2f SPGR =  1 P 1    OPT = 1", ...
                angles)), ...
                string(sprintf("%d 0",obj.structure.num_sites)), ...
                "0 "+obj.structure.formula];
            for index=1:obj.structure.num_sites
                site=obj.structure(index);
                lines(end+1)=string(sprintf("%d %s %.4f %.4f %.4f", ...
                    index,site.specie,site.frac_coords)); %#ok<AGROW>
            end
            text=char(join(lines,newline));
        end
        function text=string(obj),text=string(char(obj));end
        function write_file(obj,filename)
            writeTextMaybeGzip(filename,[char(obj),newline]);
        end
    end
    methods (Static)
        function obj=from_str(text)
            lines=splitlines(string(text));
            if numel(lines)<4
                error("KSSOLV:Matgenlab:Cssr:Invalid", ...
                    "A CSSR document requires at least four header lines.");
            end
            lengths=sscanf(lines(1),"%f",3).';
            angles=sscanf(lines(2),"%f",3).';
            if numel(lengths)~=3||numel(angles)~=3
                error("KSSOLV:Matgenlab:Cssr:Lattice", ...
                    "Invalid CSSR lattice parameters.");
            end
            lattice=kssolv.analysis.matgenlab.core.Lattice. ...
                from_parameters(lengths(1),lengths(2),lengths(3), ...
                angles(1),angles(2),angles(3));
            species={};coordinates=zeros(0,3);
            expression=['^\s*\d+\s+(\w+)\s+' ...
                '([-+\d\.Ee]+)\s+([-+\d\.Ee]+)\s+' ...
                '([-+\d\.Ee]+)'];
            for index=5:numel(lines)
                tokens=regexp(lines(index),expression,"tokens","once");
                if isempty(tokens),continue,end
                species{end+1}=tokens{1}; %#ok<AGROW>
                coordinates(end+1,:)=str2double(tokens(2:4)); %#ok<AGROW>
            end
            structure=kssolv.analysis.matgenlab.core.Structure( ...
                lattice,species,coordinates);
            obj=kssolv.analysis.matgenlab.io.Cssr(structure);
        end
        function obj=from_file(filename)
            obj=kssolv.analysis.matgenlab.io.Cssr. ...
                from_str(readTextMaybeGzip(filename));
        end
    end
end

function writeTextMaybeGzip(filename,text)
filename=string(filename);
if endsWith(lower(filename),".gz")
    folder=string(tempname);mkdir(folder);
    cleanup=onCleanup(@()removeFolder(folder));
    plain=fullfile(folder,"data.cssr");
    writePlain(plain,text);gzip(plain,fileparts(filename));
    generated=fullfile(fileparts(filename),"data.cssr.gz");
    movefile(generated,filename,"f");
    clear cleanup
else
    writePlain(filename,text);
end
end
function writePlain(filename,text)
fid=fopen(filename,"wt","n","UTF-8");
if fid<0,error("KSSOLV:Matgenlab:Cssr:Open","Cannot write '%s'.",filename);end
cleanup=onCleanup(@()fclose(fid));fprintf(fid,"%s",text);
end
function text=readTextMaybeGzip(filename)
filename=string(filename);
if endsWith(lower(filename),".gz")
    folder=string(tempname);mkdir(folder);
    cleanup=onCleanup(@()removeFolder(folder));
    values=gunzip(filename,folder);text=fileread(values{1});
    clear cleanup
else
    text=fileread(filename);
end
end
function removeFolder(folder)
if isfolder(folder),rmdir(folder,"s");end
end
