function [value,score]=sort_and_score_element_wyckoffs(element_wyckoffs)
%SORT_AND_SCORE_ELEMENT_WYCKOFFS Canonically sort and score Wyckoff groups.
parts=split(string(element_wyckoffs),"_");sorted=strings(size(parts));
score=0;
for index=1:numel(parts)
    parsed=kssolv.analysis.matgenlab.analysis.prototypes. ...
        split_alpha_numeric(parts(index));
    count=min(numel(parsed.numeric),numel(parsed.alpha));
    letters=parsed.alpha(1:count);numbers=parsed.numeric(1:count);
    [letters,order]=sort(letters);numbers=numbers(order);
    tokens=strings(1,count);
    for token=1:count
        if numbers(token)=="1",tokens(token)=letters(token);
        else,tokens(token)=numbers(token)+letters(token);end
    end
    sorted(index)=join(tokens,"");
    lettersForScore=char(join(parsed.alpha,""));
    for letter=lettersForScore
        if letter~='A',score=score+double(letter)-96;end
    end
end
value=join(sorted,"_");
end
