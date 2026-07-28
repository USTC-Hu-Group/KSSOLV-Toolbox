classdef Xr
    %XR Read and write the GULP modified-CSSR core-shell format.
    properties
        structure
    end
    methods
        function obj=Xr(structure)
            if ~structure.is_ordered
                error("KSSOLV:Matgenlab:Xr:Disordered", ...
                    "Xr files can only represent ordered structures.");
            end
            obj.structure=structure;
        end
        function text=char(obj)
            lengths=obj.structure.lattice.abc;
            angles=obj.structure.lattice.angles;
            lines=[ ...
                string(sprintf("pymatgen   %.4f %.4f %.4f",lengths)), ...
                string(sprintf("%.3f %.3f %.3f",angles)), ...
                string(sprintf("%d 0",obj.structure.num_sites)), ...
                "0 "+obj.structure.formula];
            for index=1:obj.structure.num_sites
                site=obj.structure(index);
                lines(end+1)=string(sprintf("%d %s %.4f %.4f %.4f", ...
                    index,site.specie,site.coords)); %#ok<AGROW>
            end
            matrix=obj.structure.lattice.matrix;
            for copyIndex=1:2
                for row=1:3
                    lines(end+1)=string(sprintf("%.4f %.4f %.4f", ...
                        matrix(row,:))); %#ok<AGROW>
                end
            end
            text=char(join(lines,newline));
        end
        function text=string(obj),text=string(char(obj));end
        function write_file(obj,filename)
            writeText(filename,[char(obj),newline]);
        end
    end
    methods (Static)
        function obj=from_str(text,useCores,threshold)
            if nargin<2||isempty(useCores),useCores=true;end
            if nargin<3||isempty(threshold),threshold=1e-4;end
            lines=splitlines(string(text));
            header=split(strip(lines(1)));
            lengths=str2double(header(2:end)).';
            angles=sscanf(lines(2),"%f",3).';
            siteCount=sscanf(lines(3),"%d",1);
            if numel(lengths)~=3||numel(angles)~=3||isempty(siteCount)
                error("KSSOLV:Matgenlab:Xr:Header", ...
                    "Invalid XR header.");
            end
            firstMatrix=4+siteCount+1;
            matrix=zeros(3,3);
            for row=1:3
                first=strip(lines(firstMatrix+row-1));
                second=strip(lines(firstMatrix+row+2));
                if first~=second
                    error("KSSOLV:Matgenlab:Xr:MatrixCopies", ...
                        "Expected both lattice matrices to be identical.");
                end
                matrix(row,:)=sscanf(first,"%f",3).';
            end
            lattice=kssolv.analysis.matgenlab.core.Lattice(matrix);
            actualLengths=lattice.abc;actualAngles=lattice.angles;
            relative=[abs(actualLengths-lengths)./abs(actualLengths), ...
                abs(actualAngles-angles)./abs(actualAngles)];
            if any(relative>threshold)
                error("KSSOLV:Matgenlab:Xr:CellMismatch", ...
                    "Header cell parameters disagree with lattice vectors.");
            end
            species={};coordinates=zeros(0,3);
            expression=['^\s*\d+\s+(\w+)\s+' ...
                '([-+\d\.Ee]+)\s+([-+\d\.Ee]+)\s+' ...
                '([-+\d\.Ee]+)'];
            for index=1:siteCount
                tokens=regexp(lines(4+index),expression, ...
                    "tokens","once");
                if isempty(tokens),continue,end
                name=string(tokens{1});
                if useCores&&endsWith(name,"_s"),continue,end
                if ~useCores&&endsWith(name,"_c"),continue,end
                if endsWith(name,["_s","_c"]),name=extractBefore(name, ...
                        strlength(name)-1);end
                species{end+1}=char(name); %#ok<AGROW>
                coordinates(end+1,:)=str2double(tokens(2:4)); %#ok<AGROW>
            end
            structure=kssolv.analysis.matgenlab.core.Structure( ...
                lattice,species,coordinates,coords_are_cartesian=true);
            obj=kssolv.analysis.matgenlab.io.Xr(structure);
        end
        function obj=from_file(filename,useCores,threshold)
            if nargin<2,useCores=true;end
            if nargin<3,threshold=1e-4;end
            obj=kssolv.analysis.matgenlab.io.Xr.from_str( ...
                readText(filename),useCores,threshold);
        end
    end
end

function writeText(filename,text)
filename=string(filename);
if endsWith(lower(filename),".gz")
    folder=string(tempname);mkdir(folder);
    cleanup=onCleanup(@()removeFolder(folder));
    plain=fullfile(folder,"data.xr");
    writePlain(plain,text);gzip(plain,fileparts(filename));
    movefile(fullfile(fileparts(filename),"data.xr.gz"),filename,"f");
    clear cleanup
else
    writePlain(filename,text);
end
end
function writePlain(filename,text)
fid=fopen(filename,"wt","n","UTF-8");
if fid<0,error("KSSOLV:Matgenlab:Xr:Open","Cannot write '%s'.",filename);end
cleanup=onCleanup(@()fclose(fid));fprintf(fid,"%s",text);
end
function text=readText(filename)
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
