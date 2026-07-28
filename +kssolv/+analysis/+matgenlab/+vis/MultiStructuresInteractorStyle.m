classdef MultiStructuresInteractorStyle < ...
        kssolv.analysis.matgenlab.vis.StructureInteractorStyle
    %MULTISTRUCTURESINTERACTORSTYLE Sequence-navigation callbacks.

    methods
        function obj=MultiStructuresInteractorStyle(parent)
            obj@kssolv.analysis.matgenlab.vis. ...
                StructureInteractorStyle(parent);
        end

        function keyPressEvent(obj,source,event)
            key=obj.key(event);
            parent=obj.parent;
            switch key
                case "n"
                    if parent.istruct==numel(parent.structures)
                        parent.display_warning("LAST STRUCTURE");
                    else
                        parent.istruct=parent.istruct+1;
                        parent.current_structure= ...
                            parent.structures{parent.istruct};
                        parent.set_structure( ...
                            parent.current_structure,false,false);
                        parent.erase_warning();
                    end
                case "p"
                    if parent.istruct==1
                        parent.display_warning("FIRST STRUCTURE");
                    else
                        parent.istruct=parent.istruct-1;
                        parent.current_structure= ...
                            parent.structures{parent.istruct};
                        parent.set_structure( ...
                            parent.current_structure,false,false);
                        parent.erase_warning();
                    end
                case "m"
                    obj.animate();
                otherwise
                    keyPressEvent@kssolv.analysis.matgenlab.vis. ...
                        StructureInteractorStyle(obj,source,event);
            end
        end
    end

    methods (Access=private)
        function animate(obj)
            parent=obj.parent;
            if isempty(parent.structures),return,end
            options=parent.animated_movie_options;
            if string(options.looping_type)=="restart"
                order=1:numel(parent.structures);
            elseif string(options.looping_type)=="palindrome"
                order=[1:numel(parent.structures), ...
                    numel(parent.structures)-1:-1:1];
            else
                error("KSSOLV:Matgenlab:MultiStructuresVis:LoopingType", ...
                    'looping_type should be "restart" or "palindrome".');
            end
            for loopIndex=1:options.number_of_loops
                for structureIndex=order
                    pause(options.time_between_frames);
                    parent.istruct=structureIndex;
                    parent.current_structure= ...
                        parent.structures{structureIndex};
                    parent.set_structure( ...
                        parent.current_structure,false,false);
                    parent.display_info(sprintf( ...
                        "Animated movie : structure %d/%d (loop %d/%d)", ...
                        structureIndex,numel(parent.structures), ...
                        loopIndex,options.number_of_loops));
                    drawnow;
                end
                pause(options.time_between_loops);
            end
            parent.erase_info();
            parent.display_info("Ended animated movie ...");
        end
    end
end
