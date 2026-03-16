import os
import tkinter as tk
from tkinter import filedialog, messagebox
from PIL import Image

class COEConverterApp:
    def __init__(self, root):
        self.root = root
        self.root.title("🌟 派大星的专属 COE 转换神器 V2.0 🌟")
        self.root.geometry("480x350")
        self.root.resizable(False, False)
        
        # 内部变量，用来存当前选中的文件路径
        self.image_path = ""
        
        # --- UI 界面布局 ---
        # 1. 标题标签
        tk.Label(root, text="FPGA 图像 COE 提取工具", font=("Arial", 16, "bold"), pady=15).pack()
        
        # 2. 选择文件按钮
        tk.Button(root, text="📁 选择 BMP/图片文件", command=self.select_file, 
                  font=("Arial", 12), bg="#87CEEB", width=20, pady=5).pack(pady=10)
        
        # 3. 信息显示区域 (尺寸、格式)
        self.info_frame = tk.LabelFrame(root, text="图片信息检测", padx=10, pady=10)
        self.info_frame.pack(fill="x", padx=30, pady=10)
        
        self.label_path = tk.Label(self.info_frame, text="文件路径: (未选择)", fg="gray", wraplength=380, justify="left")
        self.label_path.pack(anchor="w")
        
        self.label_size = tk.Label(self.info_frame, text="图像尺寸: -- x --", font=("Arial", 10, "bold"))
        self.label_size.pack(anchor="w", pady=2)
        
        self.label_mode = tk.Label(self.info_frame, text="色彩空间: --", font=("Arial", 10, "bold"))
        self.label_mode.pack(anchor="w", pady=2)
        
        # 4. 生成按钮
        self.btn_generate = tk.Button(root, text="🚀 另存为 COE 文件...", command=self.generate_coe, 
                                      font=("Arial", 12, "bold"), bg="#FFB6C1", width=20, pady=5, state=tk.DISABLED)
        self.btn_generate.pack(pady=10)

    def select_file(self):
        # 打开文件选择对话框
        file_path = filedialog.askopenfilename(
            title="选择要转换的图片",
            filetypes=[("Image Files", "*.bmp *.png *.jpg *.jpeg"), ("All Files", "*.*")]
        )
        
        if file_path:
            self.image_path = file_path
            self.label_path.config(text=f"已选文件: {os.path.basename(file_path)}", fg="black")
            
            try:
                # 自动识别尺寸和色彩格式
                with Image.open(file_path) as img:
                    width, height = img.size
                    mode = img.mode
                    
                    self.label_size.config(text=f"图像尺寸: {width} 宽 x {height} 高 (总像素: {width * height})", fg="green")
                    self.label_mode.config(text=f"原始色彩空间: {mode} (生成时将自动强转为 24bit RGB)", fg="green")
                    
                    # 激活生成按钮
                    self.btn_generate.config(state=tk.NORMAL)
            except Exception as e:
                messagebox.showerror("错误", f"无法读取图片信息，请确保它是有效的图像文件！\n\n报错信息: {e}")
                self.btn_generate.config(state=tk.DISABLED)

    def generate_coe(self):
        if not self.image_path:
            return
            
        # 提取原图片的目录和名字，作为默认推荐的保存名字
        file_dir, file_name = os.path.split(self.image_path)
        base_name, _ = os.path.splitext(file_name)
        default_out_name = f"{base_name}_pure.coe"
        
        # ==========================================
        # 💡 新增核心：弹出保存文件对话框
        # ==========================================
        output_coe_path = filedialog.asksaveasfilename(
            title="保存 COE 文件",
            initialdir=file_dir,               # 默认打开的文件夹
            initialfile=default_out_name,      # 默认推荐的文件名
            defaultextension=".coe",           # 默认后缀
            filetypes=[("COE Files", "*.coe"), ("All Files", "*.*")],
            confirmoverwrite=True              # 【灵魂参数】如果选了同名文件，系统自动弹出覆盖警告！
        )
        
        # 如果用户在保存弹窗点了“取消”或者关掉了窗口，就直接返回，不执行生成
        if not output_coe_path:
            return
        
        try:
            # 核心转换逻辑
            img = Image.open(self.image_path).convert('RGB') # 强制转换并剥离所有废料格式！
            width, height = img.size
            
            with open(output_coe_path, 'w') as f:
                f.write("; Copyright (C) Patrick Star's Ultimate COE Converter V2\n")
                f.write("; 拒绝格式对齐坑人，纯净 24bit RGB 像素提取！\n")
                f.write(f"; Source image size: {width} x {height}\n\n")
                f.write("memory_initialization_radix = 16;\n")
                f.write("memory_initialization_vector =\n")
                
                # 逐行读取像素
                for y in range(height):
                    for x in range(width):
                        r, g, b = img.getpixel((x, y))
                        hex_color = f"{r:02x}{g:02x}{b:02x}"
                        
                        if y == height - 1 and x == width - 1:
                            f.write(f"{hex_color}\n;") 
                        else:
                            f.write(f"{hex_color}\n")
                            
            messagebox.showinfo("大功告成！", f"✅ COE 文件已成功保存！\n\n路径:\n{output_coe_path}")
            
        except Exception as e:
            messagebox.showerror("转换失败", f"在生成 COE 时发生了错误：\n\n{e}")

if __name__ == "__main__":
    # 创建主窗口并启动界面循环
    root = tk.Tk()
    app = COEConverterApp(root)
    root.mainloop()