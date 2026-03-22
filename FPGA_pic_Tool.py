import sys
import os
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from PIL import Image

def resource_path(relative_path):
    """ 获取资源的绝对路径，完美兼容开发环境和 PyInstaller 打包环境 """
    if hasattr(sys, '_MEIPASS'):
        # PyInstaller 打包后的环境，sys._MEIPASS 会自动指向包含数据的正确文件夹（比如 _internal）
        return os.path.join(sys._MEIPASS, relative_path)
    # 正常的 Python 代码运行环境
    return os.path.join(os.path.abspath("."), relative_path)

class FPGAImageToolApp:
    def __init__(self, root):
        self.root = root
        self.root.title("派大星 - FPGA 图像转换工具 V4.1")
        self.root.geometry("720x520")
        self.root.resizable(False, False)
        
        # 尝试加载图标，加入 resource_path 魔法！
        try:
            icon_file = resource_path("star.ico")
            self.root.iconbitmap(icon_file)
        except Exception as e:
            print(f"图标加载失败，原因：{e}")
        
        self.image_path = ""
        self.mem_path = ""
        
        tk.Label(root, text="FPGA 图像转换工具 V4.1", font=("Arial", 16, "bold"), pady=10).pack()
        
        main_frame = tk.Frame(root)
        main_frame.pack(fill="both", expand=True, padx=10, pady=5)
        
        # ==========================================
        # 左侧：功能 1 - 图像转 FPGA 数据
        # ==========================================
        left_frame = tk.LabelFrame(main_frame, text="功能 1: 图像提取为 FPGA 内存数据", padx=10, pady=5)
        left_frame.pack(side="left", fill="both", expand=True, padx=5)
        
        tk.Button(left_frame, text="📁 选择任意图片文件", command=self.select_file, 
                  font=("Arial", 11), bg="#87CEEB", width=22, pady=5).pack(pady=5)
        
        self.info_frame_l = tk.LabelFrame(left_frame, text="图片信息", padx=5, pady=2)
        self.info_frame_l.pack(fill="x", pady=2)
        self.label_path_l = tk.Label(self.info_frame_l, text="未选择", fg="gray", wraplength=280, justify="left")
        self.label_path_l.pack(anchor="w")
        self.label_size_l = tk.Label(self.info_frame_l, text="尺寸: -- x --", font=("Arial", 9, "bold"))
        self.label_size_l.pack(anchor="w")

        fmt_frame_l = tk.LabelFrame(left_frame, text="输出格式设置", padx=5, pady=5)
        fmt_frame_l.pack(fill="x", pady=5)
        
        tk.Label(fmt_frame_l, text="色彩深度:").grid(row=0, column=0, sticky="e", pady=2)
        self.combo_color_out = ttk.Combobox(fmt_frame_l, state="readonly", width=18,
                                            values=["24-bit RGB888", "16-bit RGB565", "8-bit 灰度(Grayscale)", "1-bit 黑白(Monochrome)"])
        self.combo_color_out.current(0)
        self.combo_color_out.grid(row=0, column=1, pady=2, padx=5)

        tk.Label(fmt_frame_l, text="数据进制:").grid(row=1, column=0, sticky="e", pady=2)
        self.combo_radix_out = ttk.Combobox(fmt_frame_l, state="readonly", width=18, values=["HEX (16进制)", "BIN (2进制)"])
        self.combo_radix_out.current(0)
        self.combo_radix_out.grid(row=1, column=1, pady=2, padx=5)

        tk.Label(fmt_frame_l, text="目标文件:").grid(row=2, column=0, sticky="e", pady=2)
        self.combo_file_out = ttk.Combobox(fmt_frame_l, state="readonly", width=18, 
                                           values=["COE (.coe)", "MIF (.mif)", "TXT (.txt)"])
        self.combo_file_out.current(0)
        self.combo_file_out.grid(row=2, column=1, pady=2, padx=5)
        
        self.btn_generate_mem = tk.Button(left_frame, text="🚀 生成 FPGA 内存文件", command=self.generate_mem_file, 
                                      font=("Arial", 11, "bold"), bg="#FFB6C1", width=22, pady=5, state=tk.DISABLED)
        self.btn_generate_mem.pack(side="bottom", pady=10)

        # ==========================================
        # 右侧：功能 2 - FPGA 数据还原图像
        # ==========================================
        right_frame = tk.LabelFrame(main_frame, text="功能 2: 内存数据还原图像", padx=10, pady=5)
        right_frame.pack(side="right", fill="both", expand=True, padx=5)
        
        tk.Button(right_frame, text="📁 选择 COE/MIF/TXT 文件", command=self.select_mem_file, 
                  font=("Arial", 11), bg="#87CEEB", width=22, pady=5).pack(pady=5)
                  
        self.label_path_r = tk.Label(right_frame, text="未选择", fg="gray", wraplength=280, justify="left")
        self.label_path_r.pack(anchor="w", pady=2)
        
        param_frame = tk.LabelFrame(right_frame, text="还原参数设置", padx=5, pady=5)
        param_frame.pack(fill="x", pady=5)
        
        tk.Label(param_frame, text="画布宽度:").grid(row=0, column=0, sticky="e", pady=2)
        self.entry_width = tk.Entry(param_frame, width=15)
        self.entry_width.insert(0, "50")
        self.entry_width.grid(row=0, column=1, pady=2)
        
        tk.Label(param_frame, text="画布高度:").grid(row=1, column=0, sticky="e", pady=2)
        self.entry_height = tk.Entry(param_frame, width=15)
        self.entry_height.insert(0, "50")
        self.entry_height.grid(row=1, column=1, pady=2)

        tk.Label(param_frame, text="输入格式:").grid(row=2, column=0, sticky="e", pady=2)
        self.combo_color_in = ttk.Combobox(param_frame, state="readonly", width=14,
                                            values=["24-bit RGB888", "16-bit RGB565", "8-bit 灰度", "1-bit 黑白"])
        self.combo_color_in.current(0)
        self.combo_color_in.grid(row=2, column=1, pady=2)

        tk.Label(param_frame, text="输入进制:").grid(row=3, column=0, sticky="e", pady=2)
        self.combo_radix_in = ttk.Combobox(param_frame, state="readonly", width=14, values=["HEX (16进制)", "BIN (2进制)"])
        self.combo_radix_in.current(0)
        self.combo_radix_in.grid(row=3, column=1, pady=2)
        
        self.btn_generate_img = tk.Button(right_frame, text="💾 还原为图像文件", command=self.generate_image, 
                                      font=("Arial", 11, "bold"), bg="#FFB6C1", width=22, pady=5, state=tk.DISABLED)
        self.btn_generate_img.pack(side="bottom", pady=10)

    # ---------------- 核心逻辑区 ----------------

    def select_file(self):
        file_path = filedialog.askopenfilename(
            title="选择要转换的图片",
            filetypes=[("Image Files", "*.bmp *.png *.jpg *.jpeg *.gif *.webp *.tiff"), ("All Files", "*.*")]
        )
        if file_path:
            self.image_path = file_path
            self.label_path_l.config(text=f"文件: {os.path.basename(file_path)}", fg="black")
            try:
                with Image.open(file_path) as img:
                    width, height = img.size
                    self.label_size_l.config(text=f"尺寸: {width} x {height}", fg="green")
                    self.btn_generate_mem.config(state=tk.NORMAL)
            except Exception as e:
                messagebox.showerror("错误", f"无法读取图片！\n\n报错: {e}")
                self.btn_generate_mem.config(state=tk.DISABLED)

    def generate_mem_file(self):
        if not self.image_path: return
        
        target_file_type = self.combo_file_out.get()
        if "COE" in target_file_type:
            ext_def, ft_list = ".coe", [("Xilinx COE Files", "*.coe")]
        elif "MIF" in target_file_type:
            ext_def, ft_list = ".mif", [("Altera MIF Files", "*.mif")]
        else:
            ext_def, ft_list = ".txt", [("Verilog Text Files", "*.txt"), ("Data Files", "*.dat")]

        file_dir, file_name = os.path.split(self.image_path)
        base_name, _ = os.path.splitext(file_name)
        
        out_path = filedialog.asksaveasfilename(
            title="保存 FPGA 内存文件", initialdir=file_dir, initialfile=f"{base_name}_fpga{ext_def}",
            defaultextension=ext_def, filetypes=ft_list
        )
        if not out_path: return
        
        color_fmt = self.combo_color_out.get()
        radix_fmt = self.combo_radix_out.get()
        is_hex = "HEX" in radix_fmt
        
        # 确定数据位宽
        if "24-bit" in color_fmt: bit_width = 24
        elif "16-bit" in color_fmt: bit_width = 16
        elif "8-bit" in color_fmt: bit_width = 8
        else: bit_width = 1

        try:
            img = Image.open(self.image_path)
            if "24-bit" in color_fmt or "16-bit" in color_fmt: img = img.convert('RGB')
            elif "8-bit" in color_fmt: img = img.convert('L')
            elif "1-bit" in color_fmt: img = img.convert('1')
                
            width, height = img.size
            depth = width * height
            
            with open(out_path, 'w') as f:
                # 写入不同格式的头文件
                if "COE" in target_file_type:
                    f.write("; Generated by Patrick Star's V4.1\n")
                    f.write(f"memory_initialization_radix = {'16' if is_hex else '2'};\n")
                    f.write("memory_initialization_vector =\n")
                elif "MIF" in target_file_type:
                    f.write("-- Generated by Patrick Star's V4.1\n")
                    f.write(f"DEPTH = {depth};\n")
                    f.write(f"WIDTH = {bit_width};\n")
                    f.write("ADDRESS_RADIX = UNS;\n")
                    f.write(f"DATA_RADIX = {'HEX' if is_hex else 'BIN'};\n")
                    f.write("CONTENT BEGIN\n")
                
                # 写入像素数据
                addr = 0
                for y in range(height):
                    for x in range(width):
                        val_str = ""
                        if "24-bit" in color_fmt:
                            r, g, b = img.getpixel((x, y))
                            val_str = f"{r:02x}{g:02x}{b:02x}" if is_hex else f"{r:08b}{g:08b}{b:08b}"
                        elif "16-bit" in color_fmt:
                            r, g, b = img.getpixel((x, y))
                            rgb565 = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)
                            val_str = f"{rgb565:04x}" if is_hex else f"{rgb565:016b}"
                        elif "8-bit" in color_fmt:
                            gray = img.getpixel((x, y))
                            val_str = f"{gray:02x}" if is_hex else f"{gray:08b}"
                        elif "1-bit" in color_fmt:
                            bw = 1 if img.getpixel((x, y)) else 0
                            val_str = f"{bw:01x}" if is_hex else f"{bw:01b}"
                            
                        # 结尾处理
                        is_last = (addr == depth - 1)
                        if "COE" in target_file_type:
                            f.write(f"{val_str};\n" if is_last else f"{val_str},\n")
                        elif "MIF" in target_file_type:
                            f.write(f"\t{addr} : {val_str};\n")
                        else: # TXT 纯数据
                            f.write(f"{val_str}\n")
                            
                        addr += 1
                        
                if "MIF" in target_file_type:
                    f.write("END;\n")
                    
            messagebox.showinfo("成功", f"✅ FPGA 内存文件生成完毕！\n保存至: {out_path}")
        except Exception as e:
            messagebox.showerror("转换失败", f"发生错误：\n{e}")

    def select_mem_file(self):
        file_path = filedialog.askopenfilename(
            title="选择数据文件", filetypes=[("Memory Files", "*.coe *.mif *.txt *.dat"), ("All Files", "*.*")]
        )
        if file_path:
            self.mem_path = file_path
            self.label_path_r.config(text=f"文件: {os.path.basename(file_path)}", fg="black")
            self.btn_generate_img.config(state=tk.NORMAL)

    def generate_image(self):
        if not self.mem_path: return
        
        try:
            width = int(self.entry_width.get())
            height = int(self.entry_height.get())
        except ValueError:
            messagebox.showerror("错误", "画布宽高必须是整数！")
            return
            
        color_fmt = self.combo_color_in.get()
        radix_fmt = self.combo_radix_in.get()
        is_hex = "HEX" in radix_fmt
        base = 16 if is_hex else 2

        out_path = filedialog.asksaveasfilename(
            title="保存图像", initialfile="restore_image.png", 
            defaultextension=".png", 
            filetypes=[("PNG 图像", "*.png"), ("BMP 无损位图", "*.bmp"), ("JPEG 图像", "*.jpg *.jpeg")]
        )
        if not out_path: return
        
        try:
            raw_data = []
            with open(self.mem_path, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip().upper()
                    # 过滤 COE/MIF 注释和头文件定义
                    if not line or line.startswith(';') or line.startswith('--') or line.startswith('%') or \
                       'RADIX' in line or 'VECTOR' in line or 'WIDTH' in line or 'DEPTH' in line or 'BEGIN' in line or line == 'END;':
                        continue
                        
                    # 针对 MIF 格式提取冒号后面的数据部分 (例如 "10 : A5;")
                    if ':' in line:
                        line = line.split(':')[1]
                        
                    # 剥离所有的分号、逗号、空格
                    line = line.replace(';', '').replace(',', '').strip()
                    
                    if line:
                        raw_data.append(line)

            if len(raw_data) != width * height:
                messagebox.showwarning("警告", f"提取到的有效数据量({len(raw_data)})与画布大小({width*height})不匹配！\n图像可能不完整或错位。")

            if "1-bit" in color_fmt: img = Image.new('1', (width, height))
            elif "8-bit" in color_fmt: img = Image.new('L', (width, height))
            else: img = Image.new('RGB', (width, height))
                
            pixels = img.load()
            idx = 0
            for y in range(height):
                for x in range(width):
                    if idx < len(raw_data):
                        val_str = raw_data[idx]
                        try:
                            val = int(val_str, base)
                            if "24-bit" in color_fmt:
                                pixels[x, y] = ((val >> 16) & 0xFF, (val >> 8) & 0xFF, val & 0xFF)
                            elif "16-bit" in color_fmt:
                                r, g, b = (val >> 11) & 0x1F, (val >> 5) & 0x3F, val & 0x1F
                                pixels[x, y] = ((r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2))
                            elif "8-bit" in color_fmt or "1-bit" in color_fmt:
                                pixels[x, y] = val
                        except ValueError:
                            pass
                        idx += 1
            
            # 兼容 JPG 不支持 Alpha 和部分特殊格式的问题
            ext_lower = out_path.lower()
            if ext_lower.endswith('.jpg') or ext_lower.endswith('.jpeg'):
                img = img.convert('RGB')

            img.save(out_path)
            messagebox.showinfo("成功", f"✅ 图像还原成功！\n保存至: {out_path}")
            
        except Exception as e:
             messagebox.showerror("还原失败", f"处理时发生不可描述的错误：\n{e}")

if __name__ == "__main__":
    root = tk.Tk()
    app = FPGAImageToolApp(root)
    root.mainloop()