# Browser namespace compatibility fixtures

`pre-migration.ks` and `pre-migration.wf` are MATLAB v7.3 data files generated
with MATLAB R2026b in `-nojvm` mode on 2026-10-22, **before** the browser
implementations moved from `kssolv.ui.util` to `kssolv.ui.browser`.
They contain no credentials or external project data.

Both files contain one workflow named `Before browser namespace`, with the
`saved-node` SCF task configured for `maxscfiter = 87`. The workflow's hidden
`data` also contains an instance of the original
`kssolv.ui.util.BrowserSession` class and these original function handles:

- `@kssolv.ui.util.OnlineFileTransfer.validateName`
- `@kssolv.ui.util.htmlSource`

The `.ks` file contains the workflow under its normal Project/Workflow parent;
the `.wf` file contains the same workflow exported without its parent.
`BrowserNamespaceCompatibilityTest` loads these fixed historical files and
checks the original persisted task classes, custom setting, legacy object,
and callable legacy function handles. Keep the binary fixtures unchanged;
regenerating them with compatibility wrappers would no longer exercise the
original class serialization metadata.

Generation used the original `Project.saveToKsFile` and
`Workflow.saveToWfFile` methods after constructing this state:

```matlab
project = kssolv.services.filemanager.Project();
workflow = kssolv.services.filemanager.Workflow('Before browser namespace');
node = struct('id', 'saved-node', 'shape', 'dag-node', ...
    'data', struct('label', 'Saved SCF', 'status', 'default'));
workflow.graphJSON = jsonencode(struct('cells', node));
project.findChildrenItem('Workflow').addChildrenItem(workflow);
task = workflow.graph.Nodes('saved-node').task;
task.optionsUI.widgets.maxSCFIterationValueSpinner.Value = 87;
task.optionsUI.widgets.maxSCFIterationValueSpinner.ValueChangedFcn([], []);
workflow.data = struct('Session', kssolv.ui.util.BrowserSession(), ...
    'ValidateName', @kssolv.ui.util.OnlineFileTransfer.validateName, ...
    'HTMLSource', @kssolv.ui.util.htmlSource);
```
