from pathlib import Path

from Console import Console
from JSONManager import getJson

# AutoSim 根目录
AutoSim_dir = Path.cwd()

# rtl 根目录
RTL_dir_parent = AutoSim_dir.parent


def main():
    while True:
        try:
            # 获取 settings.json 配置文件
            json_settings = getJson(
                json_path = Path('settings.json'), 
                check_exist = True
            )

            # 创建 Console 对象并运行主逻辑
            VC = Console(
                AutoSim_dir = AutoSim_dir,
                RTL_dir_parent = RTL_dir_parent,
                json_settings = json_settings, 
                project_choice = None, 
                memory_choice = None
            )
            
            VC.main()
        
        except SystemExit as e:
            print(f"{e}\n程序被终止")
            break
        except KeyboardInterrupt:
            print("\n\n仿真进程被Ctrl + C终止")


if __name__ == '__main__':
    main()
