function valid=is_valid_bibtex(reference)
%IS_VALID_BIBTEX Lightweight structural validation of BibTeX entries.
reference=char(string(reference));position=1;entries=0;valid=true;
while position<=numel(reference)
    while position<=numel(reference)&&isspace(reference(position))
        position=position+1;
    end
    if position>numel(reference),break,end
    token=regexp(reference(position:end), ...
        '^@\w+\s*([\{\(])',"tokens","once");
    if isempty(token),valid=false;return,end
    match=regexp(reference(position:end), ...
        '^@\w+\s*[\{\(]',"end","once");
    opening=token{1};if opening=='{',closing='}';else,closing=')';end
    depth=1;cursor=position+match;quoted=false;
    while cursor<=numel(reference)&&depth>0
        character=reference(cursor);
        if character=='"'&& ...
                (cursor==1||reference(cursor-1)~='\')
            quoted=~quoted;
        elseif ~quoted&&character==opening,depth=depth+1;
        elseif ~quoted&&character==closing,depth=depth-1;
        end
        cursor=cursor+1;
    end
    if depth~=0,valid=false;return,end
    entries=entries+1;position=cursor;
end
valid=valid&&entries>0;
end
