import math


# 定义[Xh | Xm | Xl]    - 16 bits
# Xh: y+1               - 6 bits
# Xm: y+g               - 5 bits
# Xl: y                 - 5 bits
# y = 5, g = 0

# P表: [Xh | Xm]
# N表: [Xh | Xl]

XH_WIDTH = 6
XM_WIDTH = 5
XL_WIDTH = 5

XH_MAX = 2**XH_WIDTH - 1
XM_MAX = 2**XM_WIDTH - 1
XL_MAX = 2**XL_WIDTH - 1

def genx(x): # 1.0 <= x < 2.0
    cut16 = int(math.floor(x * 2**16))
    xh = (cut16 >> (XM_WIDTH + XL_WIDTH)) & XH_MAX
    xm = (cut16 >> (XL_WIDTH)) & XM_MAX
    xl = cut16 & XL_MAX
    return xh, xm, xl

def recipmid(x, i, o, mode='div'):
    if mode == 'div':
        return round(2**(i + o) / (((0b1 << i) | x)) + 0.5)
    elif mode == 'sqrt':
        return round(2**(i + o - 8) / (math.sqrt((0b1 << i) | x)) + 0.5)

def bitsConnect(xh, xm, xl):
    return (xh << (XM_WIDTH + XL_WIDTH)) | (xm << XL_WIDTH) | xl

class PTable:
    inWidth = 16
    outWidth = 16
    mode = 'div'

    def __init__(self, mode):
        print('当前模式: ' + mode)
        self.mode = mode

    def recipmidP(self, x):
        return recipmid(x, self.inWidth, self.outWidth, mode=self.mode)

    def adjust(self, xh, xm):
        firstextend = self.recipmidP(bitsConnect(xh, 0, 0)) - self.recipmidP(bitsConnect(xh, 0, XL_MAX))
        lastextend = self.recipmidP(bitsConnect(xh, XM_MAX, 0)) - self.recipmidP(bitsConnect(xh, XM_MAX, XL_MAX))
        avgextend = (firstextend + lastextend) / 2.0
        extend = self.recipmidP(bitsConnect(xh, xm, 0)) - self.recipmidP(bitsConnect(xh, xm, XL_MAX))
        return (avgextend + extend) / 2.0

    def generate(self):
        TableRes = {}
        for xh in range(0, XH_MAX + 1):
            for xm in range(0, XM_MAX + 1):
                operand = bitsConnect(xh, xm, 0)
                value = self.recipmidP(operand) + self.adjust(xh, xm)
                TableRes[(xh, xm)] = int(math.floor(value))
        
        return TableRes


class NTable:
    inWidth = 16
    outWidth = 5
    mode = 'div'

    def __init__(self, mode):
        print('当前模式: ' + mode)
        self.mode = mode

    def recipmidN(self, x):
        return recipmid(x, self.inWidth, self.outWidth, mode=self.mode)

    def generate(self):
        TableRes = {}
        for xh in range(0, XH_MAX + 1):
            for xl in range(0, XL_MAX + 1):
                value = self.recipmidN(bitsConnect(xh, 0, xl)) - 2
                TableRes[(xh, xl)] = int(math.floor(value))
        
        return TableRes


def Table2Txt(mode):
    P = PTable(mode)
    N = NTable(mode)
    PT = P.generate()
    NT = N.generate()

    with open(f'PLUT_{mode}.txt', 'w+') as PLUT:
        for Xh in range(0, XH_MAX + 1):
            for Xm in range(0, XM_MAX + 1):
                PVal = PT[(Xh, Xm)]             # 如果 [xh|xm] = 0: PT = 17'b10000000000011110
                PVal = PVal & (2**15-1)         # 除上述情况外最高位均为 1 同样斩断
                PLUT.write(f'{PVal:015b}\n')    # 最终拼接: {xhxm_neqz, ~xhxm_neqz, PT[14:0]}  (如果是 sqrt 则为xhxm != 0 | 1)
    
    with open(f'NLUT_{mode}.txt', 'w+') as NLUT:
        for Xh in range(0, XH_MAX + 1):
            for Xl in [0b01111, 0b11111]:
                NVAL = NT[(Xh, Xl)]             # 压缩表项: 只采用[Xh|Xl[high]]
                NLUT.write(f'{NVAL:06b}\n')

    print('finished!')

    
def GoldschmidtIteration(A, B, APPROX, k, quiet=False, mode='div'): # A / B
    if mode == 'div':
        # Iteration -1
        D = B
        F = APPROX
        N = A

        # Iteration Start
        if not quiet:
            print('=' * 10 + 'Iteration Start' + '=' * 10)
        I = 0
        for I in range(0, k):
            D = D * F
            N = N * F
            F = 2 - D
            ULP = int(abs(A / B - N) * (2 ** 26))
            if not quiet:
                print(f"I{I}: D={D:.8f}, F={F:.8f}, N={N:.8f}, ULP={ULP}")
            if (ULP == 0):
                return N, I
        return N, I
    elif mode == 'sqrt':
        # Iteration -1
        F = APPROX
        D = B
        N = B

        # Iteration Start
        if not quiet:
            print('=' * 10 + 'Iteration Start' + '=' * 10)
        I = 0
        for I in range(0, k):
            D = D * F * F
            N = N * F
            F = (3 - D) / 2
            ULP = int(abs(math.sqrt(B) - N) * (2 ** 26))
            if not quiet:
                print(f"I{I}: D={D:.8f}, F={F:.8f}, N={N:.8f}, ULP={ULP}")
            if (ULP == 0):
                return N, I
        return N, I

def getApproxRecipB(B, quiet=False, mode='div'):
    P = PTable(mode)
    N = NTable(mode)
    PT = P.generate()
    NT = N.generate()

    Xh, Xm, Xl = genx(B)
    if not quiet:
        print(f'[{Xh:06b}|{Xm:05b}|{Xl:05b}]')
    PQuery = PT[(Xh, Xm)]
    NQuery = NT[(Xh, Xl)]

    resb = PQuery - NQuery
    res = resb / (2**16)
    if mode == 'div':
        trueData = 1 / B
    elif mode == 'sqrt':
        trueData = 1 / math.sqrt(B)

    delta = abs(trueData - res) / (trueData) * 100
    deltaWithoutN = abs(trueData - PQuery / (2**16)) / (trueData) * 100

    if not quiet:
        print(f"P: {PQuery:016b} ({PQuery})\nN: {NQuery:06b} ({NQuery})\nresb: {resb:014b}\nres: {res}\ndelta: {delta:.8f} %({deltaWithoutN - delta})")

    return res


def testGoldschmidtIteration(A, B, mode):
    APPROX = getApproxRecipB(B, mode=mode)
    IterationResult = GoldschmidtIteration(A, B, APPROX, 100, mode=mode)
    print(f"IterationResult: {IterationResult}")
    return IterationResult


def testWorstIterationRounds(mode='div'):
    P = PTable(mode)
    N = NTable(mode)
    PT = P.generate()
    NT = N.generate()
    WorstRound = {}
    WorstRound['k'] = 0
    WorstRound['A'] = 0.0
    WorstRound['B'] = 0.0
    printCnt = 0
    print('')
    if mode == 'div':
        for BXh in range(0, XH_MAX + 1):
            for BXm in range(0, XM_MAX + 1):
                for BXl in range(0, XL_MAX + 1):
                    # 查询近似值
                    PQuery = PT[(BXh, BXm)]
                    NQuery = NT[(BXh, BXl)]
                    ApproxRecipResult = (PQuery - NQuery) / (2**16)

                    for AXh in range(0, XH_MAX + 1):
                        for AXm in range(0, XM_MAX + 1):
                            for AXl in range(0, XL_MAX + 1):
                                # Goldschmidt算法迭代
                                A = float(bitsConnect(AXh, AXm, AXl)) / (2**16) + 1.0
                                B = float(bitsConnect(BXh, BXm, BXl)) / (2**16) + 1.0
                                IterationResult, IterationRounds = GoldschmidtIteration(A, B, ApproxRecipResult, 100, quiet=True, mode=mode)

                                if IterationRounds > WorstRound['k']:
                                    WorstRound['k'] = IterationRounds
                                    WorstRound['A'] = A
                                    WorstRound['B'] = B

                                # 进程打印
                                if printCnt == 100000:
                                    printCnt = 0
                                    percentage = ((B - 1.0) + (A - 1.0) / (2**16)) * 100
                                    barCnt = int(percentage / 2)
                                    bar = '=' * barCnt + ' ' * (50 - barCnt)
                                    print(f"\r\033[AA={A:.9f}, B={B:.9f}, Rounds={IterationRounds}, WrostRound=[A={WorstRound['A']:.10f}, B={WorstRound['B']:.10f}, k={WorstRound['k']}]")
                                    print(f"[{bar}] {percentage:.6f} %", end='')
                                else:
                                    printCnt += 1
    elif mode == 'sqrt':
        for BXh in range(0, XH_MAX + 1):
            for BXm in range(0, XM_MAX + 1):
                for BXl in range(0, XL_MAX + 1):
                    # 查询近似值
                    PQuery = PT[(BXh, BXm)]
                    NQuery = NT[(BXh, BXl)]
                    ApproxRecipResult = (PQuery - NQuery) / (2**16)

                    # Goldschmidt算法迭代
                    B = float(bitsConnect(BXh, BXm, BXl)) / (2**16) + 1.0
                    IterationResult, IterationRounds = GoldschmidtIteration(0, B, ApproxRecipResult, 100, quiet=True, mode=mode)

                    if IterationRounds > WorstRound['k']:
                        WorstRound['k'] = IterationRounds
                        WorstRound['B'] = B

                    # 进程打印
                    if printCnt == 10:
                        printCnt = 0
                        percentage = (B - 1.0) * 100
                        barCnt = int(percentage / 2)
                        bar = '=' * barCnt + ' ' * (50 - barCnt)
                        print(f"\r\033[AB={B:.9f}, Rounds={IterationRounds}, WrostRound=[B={WorstRound['B']:.10f}, k={WorstRound['k']}]")
                        print(f"[{bar}] {percentage:.6f} %", end='')
                    else:
                        printCnt += 1


def hex2real(hex):
    mant = hex & (2**23 - 1)
    real = 1.0 + float(mant) / (2**23)
    return real

def getResMant2hex(mant):
    cut27 = int(mant * (2**26))
    print(hex(cut27))

def main():
    # testWorstIterationRounds(mode='sqrt')
    a = hex2real(0x40490fdb)
    b = hex2real(0xc61c4000) * 2
    res, k = testGoldschmidtIteration(A=a, B=b, mode='sqrt')
    getResMant2hex(res)
    # my = hex2real(0x3f93eee1)
    # test = hex2real(0x3f93eee0)
    # print(abs(a/b - res) - abs(a/b - test))
    # Table2Txt(mode='sqrt')

if __name__ == '__main__':
    main()