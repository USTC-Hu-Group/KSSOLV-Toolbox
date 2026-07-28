function values=chunk(text)
%#ok<*ALIGN,*FXSETA,*AGROW,*MSNU>
lines=splitlines(string(text));values={};current=strings(0,1);
for line=reshape(lines,1,[]),line=strtrim(line);if strlength(line)==0||startsWith(line,"#"),continue,end
if ~isempty(regexp(line,'^[A-Za-z]+\s','once'))&&~isempty(current),values{end+1}=char(join(current,newline));current=strings(0,1);end %#ok<AGROW>
current(end+1)=line;end
if ~isempty(current),values{end+1}=char(join(current,newline));end
end
