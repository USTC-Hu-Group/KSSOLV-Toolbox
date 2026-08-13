classdef PackingDiagnostics
    %PACKINGDIAGNOSTICS Geometric checks that precede packing commit.
    methods (Static)
        function rings=componentRings(molecule)
            bonds=kssolv.modeling.chemistry.MoleculeDiagnostics.topology(molecule);
            if isempty(bonds), rings=cell(1,0); return, end
            pairs=unique(sort(bonds(:,1:2),2),"rows");
            base=graph(pairs(:,1),pairs(:,2),[],molecule.num_sites);
            rings=cell(1,0); keys=strings(1,0);
            for index=1:size(pairs,1)
                reduced=rmedge(base,pairs(index,1),pairs(index,2));
                path=shortestpath(reduced,pairs(index,1),pairs(index,2));
                if numel(path)<3 || numel(path)>8, continue, end
                key=join(string(sort(path)),"-");
                if ~any(keys==key)
                    rings{end+1}=path; %#ok<AGROW>
                    keys(end+1)=key; %#ok<AGROW>
                end
            end
        end

        function hits=ringPiercings(coordinates,moleculeIds,bonds,rings)
            hits=repmat(struct("ring",[],"bond",[],"point",[]),1,0);
            for ringIndex=1:numel(rings)
                ring=reshape(rings{ringIndex},1,[]);
                points=coordinates(ring,:); center=mean(points,1);
                [~,~,vectors]=svd(points-center,0);
                normal=vectors(:,3); basis=vectors(:,1:2);
                polygon=(points-center)*basis;
                owner=moleculeIds(ring(1));
                for bondIndex=1:size(bonds,1)
                    pair=bonds(bondIndex,1:2);
                    if moleculeIds(pair(1))==owner || ...
                            moleculeIds(pair(2))==owner || ...
                            moleculeIds(pair(1))~=moleculeIds(pair(2))
                        continue
                    end
                    first=coordinates(pair(1),:); second=coordinates(pair(2),:);
                    d1=(first-center)*normal; d2=(second-center)*normal;
                    if d1*d2>=0 || abs(d1-d2)<1e-12, continue, end
                    fraction=d1/(d1-d2);
                    if fraction<=1e-8 || fraction>=1-1e-8, continue, end
                    point=first+fraction*(second-first);
                    projected=(point-center)*basis;
                    if inpolygon(projected(1),projected(2), ...
                            polygon(:,1),polygon(:,2))
                        hits(end+1)=struct("ring",ring,"bond",pair, ...
                            "point",point); %#ok<AGROW>
                    end
                end
            end
        end

        function hits=chainInterlocks(coordinates,moleculeIds,bonds,rings)
            %CHAININTERLOCKS Identify closed rings piercing another ring disk.
            piercings=kssolv.modeling.packing.PackingDiagnostics. ...
                ringPiercings(coordinates,moleculeIds,bonds,rings);
            hits=repmat(struct("ring",[],"otherRing",[], ...
                "molecules",[]),1,0);
            keys=strings(1,0);
            for index=1:numel(piercings)
                firstRing=reshape(piercings(index).ring,1,[]);
                pair=reshape(piercings(index).bond,1,[]);
                firstOwner=moleculeIds(firstRing(1));
                secondOwner=moleculeIds(pair(1));
                for otherIndex=1:numel(rings)
                    secondRing=reshape(rings{otherIndex},1,[]);
                    if moleculeIds(secondRing(1))~=secondOwner || ...
                            ~all(ismember(pair,secondRing))
                        continue
                    end
                    owners=sort([firstOwner,secondOwner]);
                    key=join(string(owners),"-");
                    if ~any(keys==key)
                        hits(end+1)=struct("ring",firstRing, ...
                            "otherRing",secondRing,"molecules",owners); %#ok<AGROW>
                        keys(end+1)=key; %#ok<AGROW>
                    end
                    break
                end
            end
        end
    end
end
