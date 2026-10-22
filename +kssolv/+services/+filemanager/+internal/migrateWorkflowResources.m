function migrateWorkflowResources(item)
%MIGRATEWORKFLOWRESOURCES Normalize legacy resource choices in imported files.
% Older files allowed Threads in the UI even though task execution did not
% use it. Preserve their prior serial behavior before any node UI is opened.
if isa(item, 'kssolv.services.filemanager.Workflow') && ~isempty(item.graph)
    nodes = values(item.graph.Nodes);
    for index = 1:numel(nodes)
        task = nodes{index}.task;
        if strcmp(task.usedParallelType, 'Threads')
            task.usedParallelType = 'None';
        end
    end
end
for index = 1:numel(item.children)
    kssolv.services.filemanager.internal. ...
        migrateWorkflowResources(item.children{index});
end
end
