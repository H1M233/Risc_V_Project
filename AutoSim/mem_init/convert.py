    # convert.py
import re
import sys
from pathlib import Path

def main():
    dir = Path.cwd()
    coe_file = dir.rglob('*.coe')
    for coePath in coe_file:
        with open(coePath, 'r') as f:
            content = f.read()

        # 提取 memory_initialization_vector= 之后到分号之前的内容
        match = re.search(r'memory_initialization_vector\s*=\s*(.*?);', content, re.DOTALL)
        if not match:
            print("未找到数据")
            exit(1)

        # 获取所有十六进制值
        data_str = match.group(1)
        # 按逗号分割，去除空白和换行
        hex_values = [x.strip() for x in data_str.split(',') if x.strip()]

        binPath = coePath.with_suffix(".bin")
        # 转换为字节（注意：每条是32位指令，需要以小端序写入）
        with open(binPath, 'wb') as out:
            for hex_val in hex_values:
                # 去掉可能的 0x 前缀
                hex_val = hex_val.replace('0x', '').replace('0X', '')
                # 转换为32位整数
                val = int(hex_val, 16)
                # 以小端序写入4个字节
                out.write(val.to_bytes(4, 'little'))

        print(f"{coePath.name}: 成功转换 {len(hex_values)} 条指令")

if __name__ == '__main__':
    sys.exit(main())