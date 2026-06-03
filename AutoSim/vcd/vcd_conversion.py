import sys
import os
import re
import pandas as pd
from collections import defaultdict
from openpyxl import load_workbook
from openpyxl.utils import get_column_letter
from openpyxl.styles import PatternFill, Border, Side, Font
from copy import copy

# ==================== VCD解析器 ====================

class SimpleVCDParser:
    """轻量级VCD解析器，使用完整层次路径作为唯一标识"""
    
    def __init__(self):
        self.signals = {}           # {signal_id: signal_info} 用于临时存储
        self.signal_data = defaultdict(list)  # {signal_path: [(time, value), ...]}
        self.scope_stack = []
        self.current_time = 0
        self.id_to_path = {}        # ID到完整路径的映射（处理重复ID）
        self.in_simulation = False
        
    def parse(self, filename):
        """解析VCD文件"""
        print(f"正在解析VCD文件: {filename}")
        
        with open(filename, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()
        
        i = 0
        total_lines = len(lines)
        
        # 第一阶段：解析定义部分
        print("解析信号定义...")
        while i < total_lines:
            line = lines[i].strip()
            
            if line.startswith('$scope'):
                i = self._parse_scope(lines, i)
            elif line.startswith('$upscope'):
                if self.scope_stack:
                    self.scope_stack.pop()
                i += 1
            elif line.startswith('$var'):
                i = self._parse_var(lines, i)
            elif line.startswith('$enddefinitions'):
                self.in_simulation = True
                i += 1
                print(f"定义解析完成，共 {len(self.id_to_path)} 个信号")
                break
            else:
                i += 1
        
        # 第二阶段：解析仿真数据
        if self.in_simulation:
            print("解析仿真数据...")
            signal_count = 0
            while i < total_lines:
                line = lines[i].strip()
                
                if line.startswith('#'):
                    # 时间戳
                    try:
                        self.current_time = int(line[1:])
                    except ValueError:
                        pass
                elif line and (line[0] in '01xXzZbr' or line.startswith('b')):
                    self._parse_value_change(line)
                    signal_count += 1
                    if signal_count % 100000 == 0:
                        print(f"  已处理 {signal_count} 个信号变化...")
                i += 1
            
            print(f"仿真数据解析完成，共处理 {signal_count} 个信号变化")
        else:
            print("警告: 未找到 $enddefinitions 标记")
        
        # 统计结果
        signals_with_data = len(self.signal_data)
        print(f"解析完成: {len(self.id_to_path)} 个信号定义, {signals_with_data} 个有波形数据")
    
    def _parse_scope(self, lines, i):
        """解析$scope块"""
        line = lines[i].strip()
        
        # 尝试单行格式: $scope module top $end
        match = re.match(r'\$scope\s+(\w+)\s+(\S+)\s+\$end', line)
        if match:
            self.scope_stack.append(match.group(2))
            return i + 1
        
        # 多行格式
        parts = line.split()
        if len(parts) >= 2:
            scope_name = parts[2] if len(parts) > 2 else parts[1]
            self.scope_stack.append(scope_name)
        
        # 跳过直到$end
        i += 1
        while i < len(lines) and '$end' not in lines[i]:
            i += 1
        return i + 1
    
    def _parse_var(self, lines, i):
        """解析$var定义"""
        line = lines[i].strip()
        
        # 尝试匹配单行格式
        match = re.match(r'\$var\s+(\w+)\s+(\d+)\s+(\S+)\s+(\S+)\s+\$end', line)
        
        if match:
            var_type, width, signal_id, name = match.groups()
            full_path = '.'.join(self.scope_stack + [name]) if self.scope_stack else name
            
            # 处理重复ID：不同信号可能使用相同的ID
            if signal_id not in self.id_to_path:
                self.id_to_path[signal_id] = []
            self.id_to_path[signal_id].append(full_path)
            
            self.signals[signal_id] = {
                'path': full_path,
                'name': name,
                'width': int(width),
                'type': var_type
            }
            return i + 1
        
        # 多行格式，跳过直到$end
        i += 1
        while i < len(lines) and '$end' not in lines[i]:
            i += 1
        return i + 1
    
    def _parse_value_change(self, line):
        """解析值变化行，处理重复ID的情况"""
        # 向量格式: b0110 @$ 或 b0110@$
        if line[0] == 'b':
            # 尝试多种格式
            match = re.match(r'(b[01xXzZ]+)\s*(\S+)', line)
            if not match:
                match = re.match(r'(b[01xXzZ]+)(\S+)', line)
            
            if match:
                value, sig_id = match.groups()
                # 如果这个ID对应多个路径，需要记录到所有路径
                if sig_id in self.id_to_path:
                    for path in self.id_to_path[sig_id]:
                        self.signal_data[path].append((self.current_time, value))
                return
        
        # 标量格式: 0# 或 1@ 或 0! 等
        elif line[0] in '01xXzZ':
            value = line[0]
            sig_id = line[1:]
            if sig_id in self.id_to_path:
                for path in self.id_to_path[sig_id]:
                    self.signal_data[path].append((self.current_time, value))
            return
        
        # 其他格式: r 或 R 开头 (实数)
        elif line[0] in 'rR':
            # 实数格式，暂时忽略
            pass


# ==================== 数据处理函数 ====================

def get_bit_width(signal_path):
    """从信号路径中提取位宽"""
    match = re.search(r'\[(\d+):(\d+)\]$', signal_path)
    if match:
        return int(match.group(1)) - int(match.group(2)) + 1
    return None


def binary_to_hex(value, width=32):
    """二进制字符串转十六进制"""
    if not value or value == '?':
        return ''
    # 去掉b前缀
    if value.startswith('b'):
        value = value[1:]
    # 去除可能的空格
    value = value.strip()
    if not value:
        return ''
    try:
        # 补齐到指定位数
        if len(value) < width:
            value = value.zfill(width)
        return format(int(value, 2), f'0{width//4}x')
    except Exception as e:
        return value


def build_waveform_dataframe(signal_data):
    """构建波形DataFrame"""
    if not signal_data:
        return None
    
    print(f"构建波形DataFrame，共 {len(signal_data)} 个信号...")
    
    # 收集所有时间点
    print("收集时间点...")
    all_times = set()
    for changes in signal_data.values():
        for t, _ in changes:
            all_times.add(t)
    
    all_times = sorted(all_times)
    print(f"时间点数量: {len(all_times)}")
    
    if not all_times:
        print("警告: 没有时间点数据")
        return None
    
    # 构建数据
    print("构建信号数据...")
    data = {'time': all_times}
    
    for idx, (signal_path, changes) in enumerate(signal_data.items()):
        if idx % 100 == 0:
            print(f"  处理信号 {idx+1}/{len(signal_data)}: {signal_path[:50]}...")
        
        values = []
        change_idx = 0
        last_val = '?'
        
        for t in all_times:
            while change_idx < len(changes) and changes[change_idx][0] <= t:
                last_val = changes[change_idx][1]
                change_idx += 1
            values.append(last_val)
        
        # 转换位宽
        bit_width = get_bit_width(signal_path)
        if bit_width == 32:
            values = [binary_to_hex(v, 32) for v in values]
        else:
            values = [str(v) for v in values]
        
        # 清理信号名中的特殊字符
        clean_path = signal_path.replace('$', '').replace('@', '').replace('!', '')
        data[clean_path] = values
    
    print("创建DataFrame...")
    df = pd.DataFrame(data)
    print(f"DataFrame: {len(df.columns)-1} 个信号列, {len(df)} 行")
    
    return df


# ==================== Excel导出函数 ====================

def df_to_transposed(df):
    """转置DataFrame，信号为行，时间为列"""
    print("转置数据格式...")
    transposed = []
    
    time_points = df['time'].tolist()
    
    # 计算最大层次深度
    max_depth = 0
    for col in df.columns:
        if col == 'time':
            continue
        parts = col.split('.')
        max_depth = max(max_depth, len(parts))
    
    print(f"最大层次深度: {max_depth}")
    
    for idx, col in enumerate(df.columns):
        if col == 'time':
            continue
        
        if idx % 100 == 0:
            print(f"  转置信号 {idx}/{len(df.columns)-1}")
        
        parts = col.split('.')
        
        # 使用列表而不是字典，确保顺序
        row = []
        
        # 1. signal_name
        row.append(parts[-1] if parts else col)

        # 2. signal_path
        row.append(col)
        
        # 3. level_0, level_1, ... level_N
        for i in range(max_depth):
            if i < len(parts):
                row.append(parts[i])
            else:
                row.append('')
        
        # 4. 时间列
        for j, t in enumerate(time_points):
            row.append(str(df[col].iloc[j]))
        
        transposed.append(row)
    
    # 构建列名
    columns = ['signal_name', 'signal_path']
    columns += [f'level_{i}' for i in range(max_depth)]
    columns += [f't_{int(t)}' for t in time_points]
    
    # 创建DataFrame并强制指定列顺序
    result_df = pd.DataFrame(transposed, columns=columns)
    
    print(f"转置后: {len(result_df)} 行, {len(result_df.columns)} 列")
    
    return result_df, max_depth


def auto_adjust_width(excel_file):
    """自动调整Excel列宽，并对不同类型列设置不同宽度"""
    try:
        print("调整列宽...")
        wb = load_workbook(excel_file)
        
        for sheet_name in wb.sheetnames:
            ws = wb[sheet_name]
            
            for col_idx, col_letter in enumerate([get_column_letter(i+1) for i in range(ws.max_column)], 1):
                col_name = ws.cell(1, col_idx).value
                
                # 根据列名设置不同的宽度策略
                if col_name:
                    # 自动计算宽度（只检查前500行）
                    max_length = 0
                    for row_idx in range(1, ws.max_row + 1):
                        cell = ws.cell(row_idx, col_idx)
                        if cell.value:
                            try:
                                max_length = max(max_length, len(str(cell.value)))
                            except:
                                pass
                    adjusted_width = max_length + 2
                    if adjusted_width > 3:
                        ws.column_dimensions[col_letter].width = adjusted_width
        
        wb.save(excel_file)
        print("列宽调整完成")
    except Exception as e:
        print(f"调整列宽时出错: {e}")


def save_to_excel(df, output_file):
    """保存DataFrame到Excel，带层次筛选"""
    print(f"保存Excel文件: {output_file}")
    
    if df is None or df.empty:
        print("错误: DataFrame为空")
        return
    
    print(f"数据规模: {len(df.columns)-1} 个信号, {len(df)} 个时间点")
    
    # 转置数据（完整保留所有信号）
    print("开始转置数据...")
    transposed_df, max_depth = df_to_transposed(df)
    
    try:
        print("写入Excel文件...")
        
        with pd.ExcelWriter(output_file, engine='openpyxl') as writer:
            transposed_df.to_excel(writer, sheet_name='signals_by_hierarchy', index=False)
        
        # 添加筛选和冻结窗格
        try:
            print("表格格式化中...")
            wb = load_workbook(output_file)

            # # 修改默认字体
            # font_name = 'Calibri'
            # font_size=11
            # if 'Normal' in wb._named_styles:
            #     wb._named_styles['Normal'].font = Font(name=font_name, size=font_size)
            # else:
            #     # 创建新的默认样式
            #     from openpyxl.styles import NamedStyle
            #     normal_style = NamedStyle('Normal')
            #     normal_style.font = Font(name=font_name, size=font_size)
            #     wb.add_named_style(normal_style)
            
            # 为工作表添加筛选
            ws = wb['signals_by_hierarchy']
            max_row = ws.max_row
            max_col = ws.max_column
            if max_row > 1 and max_col > 0:
                ws.auto_filter.ref = f"A1:{get_column_letter(max_depth + 2)}{max_row}"
            
            # 冻结前两列和首行 (C2表示冻结A、B列和第一行)
            ws.freeze_panes = 'C2'

            # 格式设置
            color_gray = "F5F5F5"
            color_grayer = "E0E0E0"
            gray_fill = PatternFill(start_color=color_gray, end_color=color_gray, fill_type="solid")
            grayer_fill = PatternFill(start_color=color_grayer, end_color=color_grayer, fill_type="solid")
            grid_border = Border(
                left=Side(style='thin', color='D4D4D4'),
                right=Side(style='thin', color='D4D4D4'),
                top=Side(style='thin', color='D4D4D4'),
                bottom=Side(style='thin', color='D4D4D4')
            )
            
            # 斑马纹
            ws.row_dimensions[0].height = 18 # 设置行高
            for row in range(2, max_row + 1):  # 从第2行开始（跳过表头）
                ws.row_dimensions[row].height = 18 # 设置行高
                ws.cell(row, 1).font = Font(bold=True)

                if row % 2 == 0:  # 偶数行填充
                    for col in range(1, max_col + 1):
                        cell = ws.cell(row, col)
                        cell.border = grid_border
                        if col in [1, 2]:
                            cell.fill = grayer_fill
                        else:
                            cell.fill = gray_fill
            
            wb.save(output_file)
            print("表格格式化完成")
        except Exception as e:
            print(f"表格格式化时出错: {e}")
        
        # 调整列宽
        auto_adjust_width(output_file)
        print(f"Excel保存成功: {output_file}")
            
    except Exception as e:
        print(f"保存Excel时出错: {e}")
        import traceback
        traceback.print_exc()
        # 降级保存为CSV
        csv_file = output_file.replace('.xlsx', '.csv')
        print(f"尝试保存为CSV: {csv_file}")
        df.to_csv(csv_file, index=False)
        transposed_df.to_csv(csv_file.replace('.csv', '_transposed.csv'), index=False)
        print(f"CSV保存成功: {csv_file}")


# ==================== 主函数 ====================

def vcd_to_excel(fileName):
    """
    将VCD文件直接转换为Excel文件
    """
    vcd_file = fileName + '.vcd'
    excel_file = fileName + '_waveform.xlsx'
    
    # 1. 解析VCD
    parser = SimpleVCDParser()
    try:
        parser.parse(vcd_file)
    except Exception as e:
        print(f"解析VCD文件失败: {e}")
        import traceback
        traceback.print_exc()
        return None
    
    if not parser.signal_data:
        print("错误: 没有解析到任何信号数据")
        return None
    
    # 打印调试信息
    print(f"\n有波形数据的信号数量: {len(parser.signal_data)}")
    print("示例信号路径:")
    for i, path in enumerate(list(parser.signal_data.keys())[:10]):
        changes = parser.signal_data[path]
        print(f"  {i+1}. {path} ({len(changes)} 个变化)")
    
    # 2. 构建DataFrame
    try:
        df = build_waveform_dataframe(parser.signal_data)
    except Exception as e:
        print(f"构建DataFrame失败: {e}")
        import traceback
        traceback.print_exc()
        return None
    
    if df is None or df.empty:
        print("错误: 无法构建波形数据")
        return None
    
    print(f"\n最终结果: {len(df.columns)-1} 个信号, {len(df)} 个时间点")
    
    # 检查信号统计
    signal_names = [col for col in df.columns if col != 'time']
    print(f"信号统计: 总数={len(signal_names)}")
    
    # 查找clk相关的信号
    clk_signals = [s for s in signal_names if 'clk' in s.lower()]
    if clk_signals:
        print(f"找到 {len(clk_signals)} 个clk相关信号:")
        for clk in clk_signals[:10]:
            print(f"  - {clk}")
    
    # 3. 保存到Excel
    save_to_excel(df, excel_file)
    print(f"\n完成! 输出文件: {excel_file}")
    
    return df


def vcd_to_csv(fileName):
    """仅转换为CSV格式"""
    vcd_file = fileName + '.vcd'
    csv_file = fileName + '.csv'
    
    parser = SimpleVCDParser()
    parser.parse(vcd_file)
    
    if not parser.signal_data:
        print("错误: 没有解析到任何信号数据")
        return None
    
    df = build_waveform_dataframe(parser.signal_data)
    
    if df is not None:
        df.to_csv(csv_file, index=False)
        print(f"CSV已保存: {csv_file}")
        return df
    return None


if __name__ == "__main__":    
    vcd_to_excel(sys.argv[1])

