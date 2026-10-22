"""Configurable workspace sizes. Values stay server-controlled, never client quantities."""
import re
DEFAULT_PROFILES = {
    'small': {'cpu': '2', 'memory': '8Gi'},
    'medium': {'cpu': '4', 'memory': '24Gi'},
    'large': {'cpu': '8', 'memory': '52Gi'},
}
def workspace_resources(value):
    if not isinstance(value,dict) or set(value)!={'cpu','memory'}: raise ValueError('Each workspace requires CPU and memory')
    cpu,memory=str(value['cpu']),str(value['memory'])
    if not re.fullmatch(r'[1-9][0-9]{0,2}',cpu) or not re.fullmatch(r'[1-9][0-9]{0,3}Gi',memory):
        raise ValueError('Workspace resources require positive whole CPU cores and Gi memory')
    return {'cpu':cpu,'memory':memory}
def profiles(config=None):
    configured=(config or {}).get('workspace_profiles', DEFAULT_PROFILES)
    if not isinstance(configured,dict): raise ValueError('Exactly small, medium and large profiles are required')
    if set(configured)!=set(DEFAULT_PROFILES): raise ValueError('Exactly small, medium and large profiles are required')
    result={}
    for key,value in configured.items():
        if not isinstance(value,dict) or set(value)!={'cpu','memory'}: raise ValueError('Each profile requires CPU and memory')
        cpu,memory=str(value['cpu']),str(value['memory'])
        if not re.fullmatch(r'[1-9][0-9]{0,2}',cpu) or not re.fullmatch(r'[1-9][0-9]{0,3}Gi',memory):
            raise ValueError('Profiles require positive whole CPU cores and Gi memory')
        result[key]={'cpu':cpu,'memory':memory}
    return result
