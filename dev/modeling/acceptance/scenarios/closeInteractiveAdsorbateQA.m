function closeInteractiveAdsorbateQA()
%CLOSEINTERACTIVEADSORBATEQA Restore temporary interactive QA state.

if evalin("base", "exist('kssolvAdsorbateQaToolbox','var')")
    toolbox = evalin("base", "kssolvAdsorbateQaToolbox");
    if ~isempty(toolbox) && isvalid(toolbox), delete(toolbox); end
end
if evalin("base", "exist('kssolvAdsorbateQaFragmentStore','var')")
    path = string(evalin("base", "kssolvAdsorbateQaFragmentStore"));
    if isfile(path), delete(path); end
end
kssolv.ui.util.DataStorage.removeData("ModelingFragmentStorePath");
evalin("base", "clear kssolvAdsorbateQaApp kssolvAdsorbateQaDisplay " + ...
    "kssolvAdsorbateQaToolbox kssolvAdsorbateQaFragmentStore");
end
