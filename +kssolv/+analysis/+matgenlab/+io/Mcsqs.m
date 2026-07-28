classdef Mcsqs
    %MCSQS ATAT rndstr.in, lat.in and bestsqs structure converter.
    properties
        structure
    end
    methods
        function obj=Mcsqs(structure),obj.structure=structure;end
        function text=to_str(obj)
            matrix=obj.structure.lattice.matrix;
            lines=strings(0,1);
            for row=1:3
                lines(end+1,1)=string(sprintf( ...
                    "%.6f %.6f %.6f",matrix(row,:))); %#ok<AGROW>
            end
            lines=[lines;"1.0 0.0 0.0";"0.0 1.0 0.0";"0.0 0.0 1.0"];
            for index=1:obj.structure.num_sites
                site=obj.structure(index);
                [species,occupancies]=site.species.items();
                labels=strings(1,numel(species));
                for speciesIndex=1:numel(species)
                    name=replace(replace(string(species{speciesIndex}), ...
                        "=","___"),",","__");
                    labels(speciesIndex)=name+"="+ ...
                        string(occupancies(speciesIndex));
                end
                lines(end+1,1)=string(sprintf("%.6f %.6f %.6f %s", ...
                    site.frac_coords,join(labels,","))); %#ok<AGROW>
            end
            text=join(lines,newline);
        end
        function text=char(obj),text=char(obj.to_str());end
        function text=string(obj),text=obj.to_str();end
    end
    methods (Static)
        function structure=structure_from_str(data)
            raw=splitlines(string(data));
            raw=strip(raw);raw(raw=="")=[];
            tokens=cellfun(@split,cellstr(raw),"UniformOutput",false);
            if numel(tokens{1})==6
                values=str2double(tokens{1});
                coordinateSystem=kssolv.analysis.matgenlab.core.Lattice. ...
                    from_parameters(values(1),values(2),values(3), ...
                    values(4),values(5),values(6)).matrix;
                latticeVectors=rowsToNumeric(tokens,2:4);
                firstSpecies=5;
            else
                coordinateSystem=rowsToNumeric(tokens,1:3);
                latticeVectors=rowsToNumeric(tokens,4:6);
                firstSpecies=7;
            end
            lattice=kssolv.analysis.matgenlab.core.Lattice( ...
                latticeVectors*coordinateSystem);
            count=numel(tokens)-firstSpecies+1;
            coordinates=zeros(count,3);species=cell(1,count);
            for index=1:count
                row=tokens{firstSpecies+index-1};
                cartesianCoordinate=reshape(str2double(row(1:3)),1,3);
                coordinates(index,:)=cartesianCoordinate/latticeVectors;
                specification=join(row(4:end),"");
                pieces=split(specification,",");
                mapping=containers.Map("KeyType","char","ValueType","double");
                for pieceIndex=1:numel(pieces)
                    pair=split(pieces(pieceIndex),"=");
                    if isscalar(pair)
                        name=pair(1);occupancy=1;
                    else
                        name=join(pair(1:end-1),"=");
                        occupancy=str2double(pair(end));
                    end
                    name=replace(replace(name,"___","="),"__",",");
                    mapping(char(name))=occupancy;
                end
                species{index}=mapping;
            end
            structure=kssolv.analysis.matgenlab.core.Structure( ...
                lattice,species,coordinates);
        end
    end
end

function values=rowsToNumeric(tokens,rows)
values=zeros(3,3);
for index=1:3,values(index,:)=str2double(tokens{rows(index)}(1:3));end
end
