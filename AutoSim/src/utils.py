import os
import subprocess
import time


def binToTxt(infile, outfile):
    '''bin转为文本文件'''
    with open(infile, 'rb') as binfile:
        data = binfile.read()
    with open(outfile, 'w') as datafile:
        for b in range(0, len(data), 4):
            chunk = data[b:b + 4]

            # 不足4字节补0
            if len(chunk) < 4:
                chunk += b'\x00' * (4 - len(chunk))
            
            # 小端转换
            datafile.write(chunk[::-1].hex() + '\n')


def removeScreenFlag(flag):
    if os.path.exists(flag):
        os.remove(flag)


def waitForScreen(flag):
    while True:
        time.sleep(0.1)
        if os.path.exists(flag):
            os.remove(flag)
            break
    
    subprocess.run('wt.exe -w -1 --colorScheme "One Half Dark" wsl.exe -- bash -lc "screen /tmp/RV_UART"', shell=True)