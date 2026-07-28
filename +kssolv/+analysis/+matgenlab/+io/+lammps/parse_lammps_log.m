function runs=parse_lammps_log(filename)
%PARSE_LAMMPS_LOG Parse completed one-line and multi-line thermo runs.
if nargin<1, filename="log.lammps"; end
lines=splitlines(string(kssolv.analysis.matgenlab.io.lammps.read_text(filename)));
begin=find(startsWith(lines,"Memory usage per processor =") | ...
    startsWith(lines,"Per MPI rank memory allocation (min/avg/max) ="));
finish=find(startsWith(lines,"Loop time of"));
n=min(numel(begin),numel(finish)); runs=cell(1,n);
for r=1:n
    block=lines(begin(r)+1:finish(r)-1); block(block=="")=[];
    if ~isempty(block)&&~isempty(regexp(block(1),'^-+\s+Step\s+','once'))
        marks=find(~cellfun(@isempty,regexp(cellstr(block),'^-+\s+Step\s+')));
        rows=cell(numel(marks),1); firstNames={};
        for j=1:numel(marks)
            e=numel(block); if j<numel(marks), e=marks(j+1)-1; end
            step=regexp(block(marks(j)),'Step\s+([0-9]+)','tokens','once');
            toks=regexp(join(block(marks(j)+1:e)," "), ...
                '([0-9A-Za-z_\[\]]+)\s+=\s+([0-9eE.+-]+)','tokens');
            names=["Step",string(cellfun(@(x)x{1},toks,'UniformOutput',false))];
            vals=[str2double(step{1}),cellfun(@(x)str2double(x{2}),toks)];
            if j==1, firstNames=cellstr(names); end
            rows{j}=vals;
        end
        runs{r}=array2table(vertcat(rows{:}),"VariableNames",firstNames);
    else
        names=cellstr(split(strtrim(block(1))));
        vals=sscanf(join(block(2:end),newline),"%f");
        vals=reshape(vals,numel(names),[])';
        runs{r}=array2table(vals,"VariableNames",names);
    end
end
end
