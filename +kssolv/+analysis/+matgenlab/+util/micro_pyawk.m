function results=micro_pyawk(filename,search,results)
%MICRO_PYAWK Apply regex-test-action rules to every line in a text file.
if nargin<3||isempty(results),results=struct();end
if ~iscell(search)||size(search,2)~=3
    error("KSSOLV:Matgenlab:IOUtils:SearchProgram", ...
        "search must be an N-by-3 cell array of regex, test and run.");
end
[path,cleanup]=readablePath(filename); %#ok<ASGLU>
fid=fopen(path,"r","n","UTF-8");
if fid<0
    error("KSSOLV:Matgenlab:IOUtils:Open", ...
        "Cannot open '%s' for reading.",filename);
end
closeFile=onCleanup(@()fclose(fid));
while true
    line=fgetl(fid);
    if ~ischar(line),break,end
    for ruleIndex=1:size(search,1)
        expression=char(string(search{ruleIndex,1}));
        [startIndex,endIndex,tokens,matched]=regexp(line,expression, ...
            "start","end","tokens","match","once");
        if isempty(startIndex),continue,end
        test=search{ruleIndex,2};
        if ~isempty(test)&&~logical(test(results,line)),continue,end
        match=struct("start",startIndex,"end",endIndex, ...
            "tokens",{tokens},"match",matched,"line",line);
        action=search{ruleIndex,3};
        if isempty(action),continue,end
        if nargout(action)>0
            results=action(results,match);
        else
            action(results,match);
        end
    end
end
clear closeFile cleanup
end

function [path,cleanup]=readablePath(filename)
path=string(filename);cleanup=onCleanup(@()[]);
if endsWith(lower(path),".gz")
    folder=string(tempname);mkdir(folder);
    values=gunzip(path,folder);
    path=string(values{1});
    cleanup=onCleanup(@()removeTemp(folder));
end
end

function removeTemp(folder)
if isfolder(folder),rmdir(folder,"s");end
end
