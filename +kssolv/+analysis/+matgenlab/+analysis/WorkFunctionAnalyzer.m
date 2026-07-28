classdef WorkFunctionAnalyzer
    %WORKFUNCTIONANALYZER Work function from a planar-averaged LOCPOT.
    properties
        shift (1,1) double = 0
        slab
        sorted_sites cell = cell(1,0)
        along_c double
        locpot_along_c double
        slab_regions double
        ave_bulk_p (1,1) double = NaN
        efermi (1,1) double
        vacuum_locpot (1,1) double
        work_function (1,1) double
        ave_locpot (1,1) double
    end
    methods
        function obj=WorkFunctionAnalyzer(structure,locpotAlongC,efermi,shift,blength)
            if nargin<4,shift=0;end
            if nargin<5,blength=3.5;end
            obj.shift=mod(double(shift),1);obj.slab=structure.copy();
            obj.slab=obj.slab.translate_sites(1:obj.slab.num_sites, ...
                [0,0,obj.shift]);
            sites=obj.slab.sites;z=cellfun(@(x)x.frac_coords(3),sites);
            [~,order]=sort(z);obj.sorted_sites=sites(order);
            values=reshape(double(locpotAlongC),1,[]);
            obj.along_c=linspace(0,1,numel(values));
            start=[];middle=[];finish=[];
            for index=1:numel(values)
                shifted=obj.along_c(index)+obj.shift;
                if shifted>1
                    start(end+1)=values(index); %#ok<AGROW>
                elseif shifted<0
                    finish(end+1)=values(index); %#ok<AGROW>
                else
                    middle(end+1)=values(index); %#ok<AGROW>
                end
            end
            obj.locpot_along_c=[start,middle,finish];
            obj.slab_regions=kssolv.analysis.matgenlab.core. ...
                get_slab_regions(obj.slab,blength);
            bulkPotential=zeros(1,0);
            for region=1:size(obj.slab_regions,1)
                mask=obj.along_c>obj.slab_regions(region,1)& ...
                    obj.along_c<=obj.slab_regions(region,2);
                bulkPotential=[bulkPotential,obj.locpot_along_c(mask)]; %#ok<AGROW>
            end
            if size(obj.slab_regions,1)>1
                mask=obj.along_c>=obj.slab_regions(2,2);
                bulkPotential=[bulkPotential,obj.locpot_along_c(mask)];
                mask=obj.along_c<=obj.slab_regions(1,1);
                bulkPotential=[bulkPotential,obj.locpot_along_c(mask)];
            end
            if ~isempty(bulkPotential),obj.ave_bulk_p=mean(bulkPotential);end
            obj.efermi=double(efermi);obj.vacuum_locpot=max(obj.locpot_along_c);
            obj.work_function=obj.vacuum_locpot-obj.efermi;
            obj.ave_locpot=(obj.vacuum_locpot-min(obj.locpot_along_c))/2;
        end
        function ax=get_locpot_along_slab_plot(obj,labelEnergies,ax,labelFontsize)
            if nargin<2,labelEnergies=true;end
            if nargin<3||isempty(ax),ax=axes("Parent",figure("Visible","off"));end
            if nargin<4,labelFontsize=10;end
            plot(ax,obj.along_c,obj.locpot_along_c,"b--");hold(ax,"on");
            averaged=obj.locpot_along_c;
            inSlab=false(size(obj.along_c));
            for region=1:size(obj.slab_regions,1)
                inSlab=inSlab|(obj.along_c>=obj.slab_regions(region,1)& ...
                    obj.along_c<=obj.slab_regions(region,2));
            end
            if size(obj.slab_regions,1)>1
                inSlab=inSlab|obj.along_c>=obj.slab_regions(2,2)| ...
                    obj.along_c<=obj.slab_regions(1,1);
            end
            averaged(inSlab|averaged<obj.ave_bulk_p)=obj.ave_bulk_p;
            plot(ax,obj.along_c,averaged,"r","LineWidth",2.5);
            if labelEnergies,obj.get_labels(ax,labelFontsize);end
            xlim(ax,[0,1]);ylim(ax,[min(obj.locpot_along_c), ...
                obj.vacuum_locpot+obj.ave_locpot*0.2]);
            xlabel(ax,"Fractional coordinates (c)");ylabel(ax,"Potential (eV)");
        end
        function ax=get_labels(obj,ax,labelFontsize)
            if nargin<3,labelFontsize=10;end
            hold(ax,"on");
            if size(obj.slab_regions,1)>1
                vacuumX=mean([obj.slab_regions(1,2), ...
                    obj.slab_regions(2,1)]);
                widths=diff(obj.slab_regions,1,2);
                if widths(1)>widths(2)
                    bulkX=obj.slab_regions(1,2)/2;
                else
                    bulkX=mean(obj.slab_regions(2,:));
                end
            else
                bulkX=mean(obj.slab_regions(1,:));
                if obj.slab_regions(1,1)>1-obj.slab_regions(1,2)
                    vacuumX=obj.slab_regions(1,1)/2;
                else
                    vacuumX=(1+obj.slab_regions(1,2))/2;
                end
            end
            yline(ax,obj.vacuum_locpot,"b--",sprintf("V_vac=%.2f", ...
                obj.vacuum_locpot),"FontSize",labelFontsize);
            yline(ax,obj.efermi,"g--",sprintf("E_F=%.2f",obj.efermi), ...
                "FontSize",labelFontsize);
            yline(ax,obj.ave_bulk_p,"r--",sprintf("V_slab=%.2f", ...
                obj.ave_bulk_p),"FontSize",labelFontsize);
            plot(ax,[vacuumX,vacuumX],[obj.efermi,obj.vacuum_locpot], ...
                "k--","LineWidth",2);
            text(ax,vacuumX,obj.efermi+.05*obj.ave_locpot, ...
                sprintf("\\Phi=%.2f",obj.work_function), ...
                "FontSize",labelFontsize);
            text(ax,bulkX,obj.vacuum_locpot+.05*obj.ave_locpot, ...
                sprintf("V_{vac}=%.2f",obj.vacuum_locpot), ...
                "FontSize",labelFontsize,"Color","b");
        end
        function tf=is_converged(obj,minPointsFrac,tolerance)
            if nargin<2,minPointsFrac=0.015;end
            if nargin<3,tolerance=0.0025;end
            within=tolerance*range(obj.locpot_along_c);
            points=floor(minPointsFrac*numel(obj.locpot_along_c));
            if points==0,tf=true;return,end
            [~,peak]=max(obj.locpot_along_c);
            indices=max(1,peak-points+1):min(numel(obj.along_c),peak+points-1);
            tf=all(abs(obj.vacuum_locpot-obj.locpot_along_c(indices))<=within);
        end
    end
    methods (Static)
        function obj=from_files(poscarFilename,locpotFilename,outcarFilename,shift,blength)
            if nargin<4,shift=0;end
            if nargin<5,blength=3.5;end
            structure=kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                from_file(poscarFilename).structure;
            locpot=kssolv.analysis.matgenlab.io.vasp.Locpot. ...
                from_file(locpotFilename);
            outcar=kssolv.analysis.matgenlab.io.vasp.Outcar(outcarFilename);
            obj=kssolv.analysis.matgenlab.analysis.WorkFunctionAnalyzer( ...
                structure,locpot.get_average_along_axis(3),outcar.efermi, ...
                shift,blength);
        end
    end
end
