function structure = get_structure_from_prev_run(vasprun, ~)
%GET_STRUCTURE_FROM_PREV_RUN Final structure decorated with available moments.
if isprop(vasprun, "final_structure")
    structure = vasprun.final_structure;
elseif isprop(vasprun, "finalStructure")
    structure = vasprun.finalStructure;
else
    error("KSSOLV:Matgenlab:VaspInputSet:PreviousStructure", ...
        "The Vasprun object has no final structure.");
end
end
