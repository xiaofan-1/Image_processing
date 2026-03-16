from PIL import Image

def convert_coe_to_png(input_file, output_file, width=50, height=50):
    hex_data = []
    
    # 读取你保存的 coe 数据文件
    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    for line in lines:
        # 去除换行符和分号
        line = line.strip().replace(';', '')
        
        # 筛选出长度为 6 的纯十六进制 RGB 数据行
        if len(line) == 6 and all(c in '0123456789abcdefABCDEF' for c in line.lower()):
            hex_data.append(line)

    # 校验数据量是否刚好能铺满 50x50 的画布
    if len(hex_data) != width * height:
        print(f"数据量 ({len(hex_data)}) 与图像尺寸 ({width}x{height}) 不匹配！请检查文件。")
        return

    # 创建一块 RGB 模式的空白画布
    img = Image.new('RGB', (width, height))
    pixels = img.load()

    # 将 16 进制颜色逐个填充到像素坐标中
    idx = 0
    for y in range(height):
        for x in range(width):
            hex_color = hex_data[idx]
            # 把类似 'ff0000' 拆分成 R(ff), G(00), B(00) 并转为十进制整数
            r = int(hex_color[0:2], 16)
            g = int(hex_color[2:4], 16)
            b = int(hex_color[4:6], 16)
            
            pixels[x, y] = (r, g, b)
            idx += 1

    # 导出图像
    img.save(output_file)
    print(f"还原成功！图像已保存为：{output_file}")

if __name__ == "__main__":
    # 假设你把上面那段带十六进制的文本存成了 'red.coe'
    # 脚本运行后会生成一张 'output.png'
    convert_coe_to_png('yellow.coe', 'output.png')