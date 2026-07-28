classdef ThermalDisplacementMatrices
    %THERMALDISPLACEMENTMATRICES Anisotropic displacement parameters.

    properties (SetAccess=private)
        thermal_displacement_matrix_cart double
        thermal_displacement_matrix_cif = []
        thermal_displacement_matrix_cart_matrixform double
        thermal_displacement_matrix_cif_matrixform = []
        structure
        temperature = []
    end

    properties (Dependent,SetAccess=private)
        Ustar
        Ucif
        B
        beta
        U1U2U3
        ratio_prolate
    end

    methods
        function obj=ThermalDisplacementMatrices( ...
                cartesian,structure,temperature,cif)
            if nargin<3,temperature=[];end
            if nargin<4,cif=[];end
            obj.thermal_displacement_matrix_cart=double(cartesian);
            obj.structure=structure;
            obj.temperature=temperature;
            obj.thermal_displacement_matrix_cart_matrixform= ...
                obj.get_full_matrix(cartesian);
            if ~isempty(cif)
                obj.thermal_displacement_matrix_cif=double(cif);
                obj.thermal_displacement_matrix_cif_matrixform= ...
                    obj.get_full_matrix(cif);
            end
            if size(obj.thermal_displacement_matrix_cart,1)~= ...
                    structure.num_sites
                error("KSSOLV:Matgenlab:ThermalDisplacement:SiteCount", ...
                    "One displacement matrix is required per structure site.");
            end
        end

        function value=get.Ustar(obj)
            matrix=obj.structure.lattice.matrix.';
            value=zeros(size(obj.thermal_displacement_matrix_cart_matrixform));
            for index=1:size(value,1)
                current=squeeze( ...
                    obj.thermal_displacement_matrix_cart_matrixform(index,:,:));
                value(index,:,:)=matrix\current/matrix.';
            end
        end

        function value=get.Ucif(obj)
            if ~isempty(obj.thermal_displacement_matrix_cif)
                value=obj.thermal_displacement_matrix_cif_matrixform;
                return
            end
            matrix=obj.structure.lattice.matrix.';
            inverse=inv(matrix);
            normalization=diag(vecnorm(inverse,2,2));
            star=obj.Ustar;
            value=zeros(size(star));
            for index=1:size(value,1)
                current=squeeze(star(index,:,:));
                value(index,:,:)= ...
                    normalization\current/normalization.';
            end
        end

        function value=get.B(obj),value=obj.Ucif*8*pi^2;end
        function value=get.beta(obj)
            matrices=obj.Ustar*2*pi^2;
            value=cell(size(matrices,1),1);
            for index=1:numel(value)
                value{index}=squeeze(matrices(index,:,:));
            end
        end
        function value=get.U1U2U3(obj)
            value=cell(size(obj.thermal_displacement_matrix_cart_matrixform,1),1);
            for index=1:numel(value)
                value{index}=eig(squeeze( ...
                    obj.thermal_displacement_matrix_cart_matrixform(index,:,:)));
            end
        end
        function value=get.ratio_prolate(obj)
            eigenvalues=obj.U1U2U3;
            value=cellfun(@(current)max(current)/min(current),eigenvalues);
        end

        function results=compute_directionality_quality_criterion(obj,other)
            if obj.structure.num_sites~=other.structure.num_sites || ...
                    any(~cellfun(@(first,second) ...
                    first==second,obj.structure.species_and_occu, ...
                    other.structure.species_and_occu))
                error("KSSOLV:Matgenlab:ThermalDisplacement:Species", ...
                    "Species in both structures are not the same.");
            end
            matcher=kssolv.analysis.matgenlab.core.StructureMatcher();
            if ~matcher.fit(obj.structure,other.structure)
                error("KSSOLV:Matgenlab:ThermalDisplacement:Structures", ...
                    "Structures have to be similar.");
            end
            count=obj.structure.num_sites;
            results=repmat(struct("angle",0,"vector0",[],"vector1",[]), ...
                count,1);
            for index=1:count
                first=squeeze( ...
                    obj.thermal_displacement_matrix_cart_matrixform(index,:,:));
                second=squeeze( ...
                    other.thermal_displacement_matrix_cart_matrixform(index,:,:));
                [vectors,values]=eig(inv(first),"vector");
                [~,minimum]=min(values);firstVector=vectors(:,minimum).';
                [vectors,values]=eig(inv(second),"vector");
                [~,minimum]=min(values);secondVector=vectors(:,minimum).';
                angle=min(angleDot(firstVector,secondVector), ...
                    angleDot(firstVector,-secondVector));
                results(index)=struct("angle",angle, ...
                    "vector0",firstVector,"vector1",secondVector);
            end
        end

        function write_cif(obj,filename)
            writer=kssolv.analysis.matgenlab.io.cif.CifWriter(obj.structure);
            writer.write_file(filename);
            fid=fopen(filename,"a","n","UTF-8");
            if fid<0,error("KSSOLV:Matgenlab:ThermalDisplacement:Write", ...
                    "Cannot append '%s'.",filename);end
            cleanup=onCleanup(@()fclose(fid));
            fprintf(fid,"%s",strjoin([ ...
                "loop_"
                "_atom_site_aniso_label"
                "_atom_site_aniso_U_11"
                "_atom_site_aniso_U_22"
                "_atom_site_aniso_U_33"
                "_atom_site_aniso_U_23"
                "_atom_site_aniso_U_13"
                "_atom_site_aniso_U_12"
                "# Additional Data for U_Aniso: "+string(obj.temperature)], ...
                newline)+newline);
            matrices=obj.Ucif;
            for index=1:obj.structure.num_sites
                matrix=squeeze(matrices(index,:,:));
                fprintf(fid,"%s%d %.16g %.16g %.16g %.16g %.16g %.16g\n", ...
                    obj.structure(index).specie.symbol,index-1, ...
                    matrix(1,1),matrix(2,2),matrix(3,3), ...
                    matrix(2,3),matrix(1,3),matrix(1,2));
            end
            clear cleanup
        end

        function visualize_directionality_quality_criterion( ...
                obj,other,filename,whichStructure)
            if nargin<3||isempty(filename),filename="visualization.vesta";end
            if nargin<4||isempty(whichStructure),whichStructure=0;end
            if whichStructure==0,structure=obj.structure;
            elseif whichStructure==1,structure=other.structure;
            else,error("KSSOLV:Matgenlab:ThermalDisplacement:StructureChoice", ...
                    "which_structure must be 0 or 1.");
            end
            results=obj.compute_directionality_quality_criterion(other);
            if isempty(obj.thermal_displacement_matrix_cif)
                cif=obj.get_reduced_matrix(obj.Ucif);
            else,cif=obj.thermal_displacement_matrix_cif;
            end
            lines=["#VESTA_FORMAT_VERSION 3.5.4","","","CRYSTAL","", ...
                "TITLE","Directionality Criterion","","GROUP","1 1 P 1","", ...
                "CELLP",sprintf("%.16g %.16g %.16g %.16g %.16g %.16g", ...
                structure.lattice.parameters), ...
                "  0.000000   0.000000   0.000000   0.000000   0.000000   0.000000", ...
                "STRUC"];
            for index=1:structure.num_sites
                site=structure(index);
                lines(end+1)=sprintf( ...
                    "%d %s %s%d 1.0000 %.16g %.16g %.16g 1a 1", ...
                    index,site.species_string,site.species_string,index, ...
                    site.frac_coords); %#ok<AGROW>
                lines(end+1)=" 0.000000 0.000000 0.000000 0.00"; %#ok<AGROW>
            end
            lines=[lines,"  0 0 0 0 0 0 0","THERT 0","THERM"];
            for index=1:size(cif,1)
                lines(end+1)=sprintf( ...
                    "%d %s%d %.16g %.16g %.16g %.16g %.16g %.16g", ...
                    index,structure(index).species_string,index,cif(index, ...
                    [1,2,3,6,5,4])); %#ok<AGROW>
            end
            lines=[lines,"  0 0 0 0 0 0 0 0","VECTR"];
            vectorIndex=1;
            for index=1:numel(results)
                for name=["vector0","vector1"]
                    vector=results(index).(name);
                    lines(end+1)=sprintf("%d %.16g %.16g %.16g 0", ...
                        vectorIndex,vector); %#ok<AGROW>
                    lines(end+1)=sprintf("%d 0 0 0 0",index); %#ok<AGROW>
                    lines(end+1)="0 0 0 0 0"; %#ok<AGROW>
                    vectorIndex=vectorIndex+1;
                end
            end
            lines=[lines,"0 0 0 0 0","VECTT"];
            for index=1:numel(results)
                lines(end+1)=sprintf("%d 0.2 255 0 0 1",2*index-1); %#ok<AGROW>
                lines(end+1)=sprintf("%d 0.2 0 0 255 1",2*index); %#ok<AGROW>
            end
            lines(end+1)="0 0 0 0 0";
            fid=fopen(filename,"w","n","UTF-8");
            if fid<0,error("KSSOLV:Matgenlab:ThermalDisplacement:Write", ...
                    "Cannot write '%s'.",filename);end
            cleanup=onCleanup(@()fclose(fid));
            fwrite(fid,strjoin(lines,newline),"char");
            clear cleanup
        end

        function structure=to_structure_with_site_properties_Ucif(obj)
            if isempty(obj.thermal_displacement_matrix_cif)
                matrix=obj.get_reduced_matrix(obj.Ucif);
            else,matrix=obj.thermal_displacement_matrix_cif;
            end
            names=["U11_cif","U22_cif","U33_cif", ...
                "U23_cif","U13_cif","U12_cif"];
            properties=struct();
            for index=1:6
                properties.(names(index))=matrix(:,index);
            end
            structure=obj.structure.copy(properties);
        end

        function value=as_dict(obj)
            value=struct( ...
                "x_module","pymatgen.phonon.thermal_displacements", ...
                "x_class","ThermalDisplacementMatrices", ...
                "thermal_displacement_matrix_cart", ...
                obj.thermal_displacement_matrix_cart, ...
                "structure",obj.structure.as_dict(), ...
                "temperature",obj.temperature, ...
                "thermal_displacement_matrix_cif", ...
                obj.thermal_displacement_matrix_cif);
        end
        function value=asDict(obj),value=obj.as_dict();end
    end

    methods (Static)
        function value=get_full_matrix(reduced)
            reduced=double(reduced);
            if size(reduced,2)~=6
                error("KSSOLV:Matgenlab:ThermalDisplacement:ReducedShape", ...
                    "Reduced matrices must have six columns.");
            end
            value=zeros(size(reduced,1),3,3);
            value(:,1,1)=reduced(:,1);value(:,2,2)=reduced(:,2);
            value(:,3,3)=reduced(:,3);value(:,2,3)=reduced(:,4);
            value(:,3,2)=reduced(:,4);value(:,1,3)=reduced(:,5);
            value(:,3,1)=reduced(:,5);value(:,1,2)=reduced(:,6);
            value(:,2,1)=reduced(:,6);
        end

        function value=get_reduced_matrix(full)
            value=zeros(size(full,1),6);
            value(:,1)=full(:,1,1);value(:,2)=full(:,2,2);
            value(:,3)=full(:,3,3);value(:,4)=full(:,2,3);
            value(:,5)=full(:,1,3);value(:,6)=full(:,1,2);
        end

        function obj=from_Ucif(cif,structure,temperature)
            if nargin<3,temperature=[];end
            full=kssolv.analysis.matgenlab.phonon. ...
                ThermalDisplacementMatrices.get_full_matrix(cif);
            matrix=structure.lattice.matrix.';
            inverse=inv(matrix);
            normalization=diag(vecnorm(inverse,2,2));
            cartesian=zeros(size(full));
            for index=1:size(full,1)
                current=squeeze(full(index,:,:));
                star=normalization*current*normalization.';
                cartesian(index,:,:)=matrix*star*matrix.';
            end
            reduced=kssolv.analysis.matgenlab.phonon. ...
                ThermalDisplacementMatrices.get_reduced_matrix(cartesian);
            obj=kssolv.analysis.matgenlab.phonon. ...
                ThermalDisplacementMatrices( ...
                reduced,structure,temperature,cif);
        end

        function obj=from_structure_with_site_properties_Ucif( ...
                structure,temperature)
            if nargin<2,temperature=[];end
            names=["U11_cif","U22_cif","U33_cif", ...
                "U23_cif","U13_cif","U12_cif"];
            matrix=zeros(structure.num_sites,6);
            for siteIndex=1:structure.num_sites
                properties=structure(siteIndex).site_properties;
                for index=1:6
                    matrix(siteIndex,index)=properties.(names(index));
                end
            end
            obj=kssolv.analysis.matgenlab.phonon. ...
                ThermalDisplacementMatrices.from_Ucif( ...
                matrix,structure,temperature);
        end

        function values=from_cif_P1(filename)
            parser=kssolv.analysis.matgenlab.io.cif.CifParser(filename);
            structures=parser.parse_structures( ...
                primitive=false,on_error="raise");
            file=kssolv.analysis.matgenlab.io.cif.CifFile.from_file(filename);
            headers=file.headers;
            values=cell(1,numel(structures));
            for blockIndex=1:numel(structures)
                block=file.data(char(headers(blockIndex)));
                tags=["_atom_site_aniso_U_11","_atom_site_aniso_U_22", ...
                    "_atom_site_aniso_U_33","_atom_site_aniso_U_23", ...
                    "_atom_site_aniso_U_13","_atom_site_aniso_U_12"];
                raw=block.data(char(tags(1)));
                count=numel(raw);matrix=zeros(count,6);
                for column=1:6
                    raw=block.data(char(tags(column)));
                    if ~iscell(raw),raw=cellstr(string(raw));end
                    for row=1:count
                        matrix(row,column)=cifNumber(raw{row});
                    end
                end
                values{blockIndex}=kssolv.analysis.matgenlab.phonon. ...
                    ThermalDisplacementMatrices.from_Ucif( ...
                    matrix,structures{blockIndex},[]);
            end
        end

        function obj=from_dict(value)
            structure=kssolv.analysis.matgenlab.core.Structure. ...
                from_dict(value.structure);
            obj=kssolv.analysis.matgenlab.phonon. ...
                ThermalDisplacementMatrices( ...
                value.thermal_displacement_matrix_cart, ...
                structure,value.temperature, ...
                value.thermal_displacement_matrix_cif);
        end
    end
end

function value=angleDot(first,second)
ratio=real(dot(first,second))/(norm(first)*norm(second));
ratio=max(-1,min(1,ratio));
value=acosd(round(ratio,10));
end

function value=cifNumber(input)
text=regexprep(char(string(input)),'\\([0-9]+\\)$','');
value=str2double(text);
end
