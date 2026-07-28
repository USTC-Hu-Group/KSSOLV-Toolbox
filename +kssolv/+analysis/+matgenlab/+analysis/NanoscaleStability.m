classdef NanoscaleStability
    %NANOSCALESTABILITY Size-dependent competition between polymorphs.
    properties
        se_analyzers cell = cell(1,0)
        symprec (1,1) double = 1e-5
    end
    methods
        function obj=NanoscaleStability(analyzers,symprec)
            if nargin<2,symprec=1e-5;end
            if iscell(analyzers),obj.se_analyzers=analyzers;
            else,obj.se_analyzers=num2cell(analyzers);end
            obj.symprec=symprec;
        end
        function radius=solve_equilibrium_point(obj,analyzer1,analyzer2,varargin)
            options=struct(delu_dict=struct(),delu_default=0,units="nanometers");
            options=parseOptions(options,varargin{:});
            first=analyzer1.wulff_from_chempot("delu_dict",options.delu_dict, ...
                "delu_default",options.delu_default,"symprec",obj.symprec);
            second=analyzer2.wulff_from_chempot("delu_dict",options.delu_dict, ...
                "delu_default",options.delu_default,"symprec",obj.symprec);
            deltaGamma=first.weighted_surface_energy- ...
                second.weighted_surface_energy;
            deltaEnergy=obj.bulk_gform(analyzer1.ucell_entry)- ...
                obj.bulk_gform(analyzer2.ucell_entry);
            radius=-3*deltaGamma/deltaEnergy;
            if string(options.units)=="nanometers",radius=radius/10;end
        end
        function [energy,newRadius]=wulff_gform_and_r(obj,shape,bulkEntry,r,varargin)
            options=struct(from_sphere_area=false,r_units="nanometers", ...
                e_units="keV",normalize=false,scale_per_atom=false);
            options=parseOptions(options,varargin{:});
            if options.from_sphere_area
                volume=4*pi*r^3/3;surface=4*pi*r^2;
                surfaceEnergy=shape.weighted_surface_energy*surface;
                newRadius=r;
            else
                scaled=obj.scaled_wulff(shape,r);
                volume=scaled.volume;surfaceEnergy=0;
                for index=1:numel(scaled.miller_area_dict)
                    surfaceEnergy=surfaceEnergy+ ...
                        shape.e_surf_list(index)* ...
                        scaled.miller_area_dict(index).value;
                end
                newRadius=scaled.effective_radius;
            end
            energy=obj.bulk_gform(bulkEntry)*volume+surfaceEnergy;
            if string(options.r_units)=="nanometers",newRadius=newRadius/10;end
            if string(options.e_units)=="keV",energy=energy/1000;end
            if options.normalize,energy=energy/(4*pi*newRadius^3/3);end
            if options.scale_per_atom
                density=bulkEntry.structure.num_sites/bulkEntry.structure.volume;
                energy=energy/(density*volume);
            end
        end
        function shape=scaled_wulff(obj,input,r)
            shape=kssolv.analysis.matgenlab.analysis.WulffShape( ...
                input.lattice,input.miller_list, ...
                input.e_surf_list*(r/input.effective_radius),obj.symprec);
        end
        function ax=plot_one_stability_map(obj,analyzer,maxR,varargin)
            options=struct(delu_dict=struct(),label="",increments=50, ...
                delu_default=0,ax=[],from_sphere_area=false,e_units="keV", ...
                r_units="nanometers",normalize=false,scale_per_atom=false);
            options=parseOptions(options,varargin{:});
            if isempty(options.ax),ax=axes("Parent",figure("Visible","off"));
            else,ax=options.ax;end
            shape=analyzer.wulff_from_chempot("delu_dict",options.delu_dict, ...
                "delu_default",options.delu_default,"symprec",obj.symprec);
            radii=linspace(1e-6,maxR,options.increments);energies=zeros(size(radii));
            x=zeros(size(radii));
            for index=1:numel(radii)
                [energies(index),x(index)]=obj.wulff_gform_and_r( ...
                    shape,analyzer.ucell_entry,radii(index), ...
                    "from_sphere_area",options.from_sphere_area, ...
                    "r_units",options.r_units,"e_units",options.e_units, ...
                    "normalize",options.normalize, ...
                    "scale_per_atom",options.scale_per_atom);
            end
            plot(ax,x,energies,"DisplayName",options.label);
            xlabel(ax,"Particle radius");ylabel(ax,"Formation energy");
        end
        function ax=plot_all_stability_map(obj,maxR,varargin)
            options=struct(increments=50,delu_dict=struct(),delu_default=0, ...
                ax=[],labels={{}},from_sphere_area=false,e_units="keV", ...
                r_units="nanometers",normalize=false,scale_per_atom=false);
            options=parseOptions(options,varargin{:});
            if isempty(options.ax),ax=axes("Parent",figure("Visible","off"));
            else,ax=options.ax;end
            hold(ax,"on");
            for index=1:numel(obj.se_analyzers)
                label="";if numel(options.labels)>=index,label=options.labels{index};end
                obj.plot_one_stability_map(obj.se_analyzers{index},maxR, ...
                    "increments",options.increments,"delu_dict",options.delu_dict, ...
                    "delu_default",options.delu_default,"ax",ax,"label",label, ...
                    "from_sphere_area",options.from_sphere_area, ...
                    "e_units",options.e_units,"r_units",options.r_units, ...
                    "normalize",options.normalize, ...
                    "scale_per_atom",options.scale_per_atom);
            end
            legend(ax,"show");
        end
    end
    methods (Static)
        function value=bulk_gform(bulkEntry)
            value=bulkEntry.energy/bulkEntry.structure.volume;
        end
    end
end
function options=parseOptions(options,varargin)
names=fieldnames(options);
for index=1:2:numel(varargin)
    if index==numel(varargin),break,end
    match=find(strcmpi(string(varargin{index}),string(names)),1);
    if ~isempty(match),options.(names{match})=varargin{index+1};end
end
end
