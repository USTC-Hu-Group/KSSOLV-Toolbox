function [allWyckoffs,elementAmounts]=element_wyckoffs_from_orbits( ...
        multiplicities,elements,letters,spgNum)
%ELEMENT_WYCKOFFS_FROM_ORBITS Build canonical per-element Wyckoff strings.
multiplicities=reshape(double(multiplicities),[],1);
elements=reshape(string(elements),[],1);
letters=reshape(string(letters),[],1);
if numel(multiplicities)~=numel(elements)||numel(elements)~=numel(letters)
    error("KSSOLV:Matgenlab:Prototypes:OrbitLength", ...
        "Orbit multiplicities, elements, and Wyckoff letters must align.");
end
if isempty(elements)
    allWyckoffs="";elementAmounts=struct();return
end
ordered=sortrows(table(elements,letters,multiplicities),[1,2]);
elementNames=unique(ordered.elements,"stable");
multiplicityData=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    load_data("multiplicities");
spaceGroupData=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    map_get(multiplicityData,string(spgNum),[]);
if isempty(spaceGroupData)
    error("KSSOLV:Matgenlab:Prototypes:SpaceGroup", ...
        "No Wyckoff multiplicity data for space group %s.",string(spgNum));
end
elementAmounts=struct();sections=strings(1,numel(elementNames));
for elementIndex=1:numel(elementNames)
    element=elementNames(elementIndex);
    mask=ordered.elements==element;
    elementLetters=ordered.letters(mask);
    distinctLetters=unique(elementLetters,"stable");
    pieces=strings(1,numel(distinctLetters));amount=0;
    for letterIndex=1:numel(distinctLetters)
        letter=distinctLetters(letterIndex);
        occurrences=sum(elementLetters==letter);
        pieces(letterIndex)=string(occurrences)+letter;
        positionMultiplicity=kssolv.analysis.matgenlab.analysis.prototypes. ...
            internal.map_get(spaceGroupData,letter,[]);
        if isempty(positionMultiplicity)
            error("KSSOLV:Matgenlab:Prototypes:WyckoffLetter", ...
                "No Wyckoff multiplicity for space group %s letter %s.", ...
                string(spgNum),letter);
        end
        amount=amount+occurrences*double(positionMultiplicity);
    end
    sections(elementIndex)=join(pieces,"");
    elementAmounts.(char(element))=amount;
end
joined=join(sections,"_");
allWyckoffs=kssolv.analysis.matgenlab.analysis.prototypes. ...
    canonicalize_element_wyckoffs(joined,spgNum);
end
