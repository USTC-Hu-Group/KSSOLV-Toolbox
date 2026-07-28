function value=get_environment_node(central_site,i_central_site,ce_symbol)
%GET_ENVIRONMENT_NODE Construct an environment connectivity node.
value=kssolv.analysis.matgenlab.analysis.chemenv.connectivity. ...
    EnvironmentNode(central_site,i_central_site,ce_symbol);
end
