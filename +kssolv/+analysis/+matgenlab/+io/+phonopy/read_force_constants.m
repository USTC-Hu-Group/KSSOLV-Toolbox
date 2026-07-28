function forceConstants=read_force_constants(filename)
%READ_FORCE_CONSTANTS Read phonopy FORCE_CONSTANTS text format.
fid=fopen(filename,"r");
if fid<0
    error("KSSOLV:Matgenlab:Phonopy:ForceConstants", ...
        "Cannot open '%s'.",filename);
end
cleanup=onCleanup(@()fclose(fid));
count=str2double(strtrim(fgetl(fid)));
forceConstants=zeros(count,count,3,3);
for first=1:count
    for second=1:count
        indices=sscanf(fgetl(fid),"%d %d");
        if numel(indices)~=2
            error("KSSOLV:Matgenlab:Phonopy:ForceConstants", ...
                "Malformed atom pair in FORCE_CONSTANTS.");
        end
        block=zeros(3);
        for row=1:3
            values=sscanf(fgetl(fid),"%f").';
            block(row,:)=values(1:3);
        end
        forceConstants(indices(1),indices(2),:,:)=block;
    end
end
clear cleanup
end
