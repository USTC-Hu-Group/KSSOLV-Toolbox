function report = verifySCFParity(projectFile, reportFile)
%VERIFYSCFPARITY Re-run a downloaded Runtime workflow in JVM-free MATLAB.
arguments
    projectFile (1, 1) string
    reportFile (1, 1) string
end
assert(~usejava('jvm'), 'Parity verification requires -nojvm.');
project = kssolv.services.filemanager.Project.loadKsFile(projectFile);
kssolv.ui.util.DataStorage.setData('Project', project);
workflows = project.findChildrenItem('Workflow');
workflow = workflows.children{1};
results = project.findChildrenItem('Results');
reference = results.datasetsItem.children{1}.data('info');
context = containers.Map('KeyType', 'char', 'ValueType', 'any');
order = kssolv.services.workflow.codegeneration.CodeGenerator.topologicalSort(workflow.graph);
for index = 1:numel(order)
    node = workflow.graph.Nodes(order{index});
    % Execute the saved option snapshot, without recreating desktop widgets.
    node.task.optionsUI = [];
    context = node.task.executeTask(context, containers.Map());
end
actual = context('info');
report = struct('Architecture', computer('arch'), 'JVM', usejava('jvm'), ...
    'RuntimeEnergyRy', 2 * reference.Etot, ...
    'MATLABEnergyRy', 2 * actual.Etot, ...
    'EnergyDifferenceRy', 2 * abs(reference.Etot - actual.Etot), ...
    'AbsoluteEnergyToleranceRy', 1e-6, ...
    'RuntimeConverged', logical(reference.converge), ...
    'MATLABConverged', logical(actual.converge), ...
    'RuntimeFinalRhoError', reference.SCFerrvec(end), ...
    'MATLABFinalRhoError', actual.SCFerrvec(end));
writelines(jsonencode(report, PrettyPrint=true), reportFile);
assert(report.EnergyDifferenceRy < report.AbsoluteEnergyToleranceRy, ...
    'SCF energy differs beyond the declared tolerance.');
assert(report.RuntimeConverged && report.MATLABConverged, ...
    'Both calculations must converge.');
disp(report);
end
