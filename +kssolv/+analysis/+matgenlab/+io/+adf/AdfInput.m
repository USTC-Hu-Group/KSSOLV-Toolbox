classdef AdfInput
    %ADFINPUT Writer for complete molecular ADF input files.
    properties
        task
    end
    methods
        function obj=AdfInput(task),obj.task=task;end
        function write_file(obj,molecule,filename)
            makeKey=@(varargin) ...
                kssolv.analysis.matgenlab.io.adf.AdfKey(varargin{:});
            atoms=makeKey("Atoms",{"cartesian"});
            for index=1:molecule.num_sites
                site=molecule.sites{index};
                atoms=atoms.add_subkey(makeKey( ...
                    string(site.specie),num2cell(site.coords)));
            end
            blocks={atoms};
            if molecule.charge~=0
                netCharge=molecule.charge;
                alphaBeta=molecule.spin_multiplicity-1;
                blocks{end+1}=makeKey("Charge",{netCharge,alphaBeta});
                if alphaBeta~=0,blocks{end+1}=makeKey("Unrestricted");end
            end
            [file,message]=fopen(filename,"w");
            if file<0
                error("KSSOLV:Matgenlab:ADF:Write", ...
                    "Cannot open ADF input '%s': %s",filename,message);
            end
            cleanup=onCleanup(@()fclose(file));
            for index=1:numel(blocks)
                fprintf(file,"%s\n",char(blocks{index}));
            end
            fprintf(file,"%s\nEND INPUT",char(obj.task));
            clear cleanup
        end
        function writeFile(obj,molecule,filename)
            obj.write_file(molecule,filename);
        end
    end
end
