import sys
import json
import os
from pathlib import Path
from typing import Optional

def getJson(json_path: Path, check_exist: Optional[bool] = None):
    '''读取JSON文件'''

    # 参数默认值
    check_exist = True if check_exist is None else check_exist
    json_file = {}

    if json_path.exists():
        with open(json_path, 'r', encoding='utf-8') as f:
            try:
                json_file = json.load(f)
            except json.decoder.JSONDecodeError:
                pass
    elif check_exist:
        sys.exit(f"无法找到{json_path.name}")

    return json_file


def getPrevRunTime(prj_name: str, sim_type: str, mem_name: str) -> float:
    json_file = getJson(Path('verilatorRunData.json'))
    return json_file.get(prj_name, {}).get(sim_type, {}).get(mem_name, {}).get('RUN TIME', 0.0)


def updateRunData(
        prj_name: str, 
        mem_name: str, 
        inst_pass: Optional[bool] = None, 
    ):
    '''更新JSON文件'''
    # 参数默认值
    json_path = Path('verilatorRunData.json')
    inst_pass = False if inst_pass is None else inst_pass
    json_file = getJson(json_path)
    json_file.setdefault(prj_name, {})

    # 读取软件测试结果
    with open('software_results.txt', 'r', encoding='utf-8') as f:
        results = dict(line.strip().split('=') for line in f if '=' in line)
    os.remove('software_results.txt')

    json_file[prj_name].setdefault('SOFTWARE TEST', {})
    json_file[prj_name]['SOFTWARE TEST'].setdefault(mem_name, {})
    json_file[prj_name]['SOFTWARE TEST'][mem_name].update(results)

    # 写回JSON文件
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(json_file, f, indent=2, ensure_ascii=False)